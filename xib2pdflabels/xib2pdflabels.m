// xib2pdflabels.m semver:1.0
//   Copyright (c) 2014 Jonathan 'Wolf' Rentzsch: http://rentzsch.com
//   Some rights reserved: http://opensource.org/licenses/mit
//   https://github.com/rentzsch/xib2pdflabels

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@interface NSTextField (jr_pdfLabelKey)
- (NSString*)jr_pdfLabelKey;
@end

// We just need the class to exist since it's referenced in the nib (we use NSTextField's rendering in this tool).
@interface JRPDFLabel : NSTextField
@end

static void walkNSView(NSView *view, NSMutableArray *labels) {
    for (NSView *subview in view.subviews) {
        if ([subview isKindOfClass:[JRPDFLabel class]]) {
            [labels addObject:subview];
        } else {
            walkNSView(subview, labels);
        }
    }
}

int main(int argc, const char * argv[]) {
    if (argc < 3) {
        fprintf(stderr, "Usage: %s JRPDFLabel.pdf MainMenu.xib MyWindow.nib\n", argv[0]);
        exit(EXIT_FAILURE);
    }
    
    @autoreleasepool {
        NSArray *args = [[NSProcessInfo processInfo] arguments];
        NSString *outputFilePath = args[1];
        NSArray *inputFilePaths = [args subarrayWithRange:NSMakeRange(2, [args count]-2)];
        
        //
        // Load every JRPDFLabel of every supplied xib and nib into the labels array.
        //
        
        NSMutableArray *labels = [NSMutableArray array]; // of JRPDFLabel
        NSMutableArray *nibPathsToDelete = [NSMutableArray array];
        for (NSString *inputFilePath in inputFilePaths) {
            NSString *inputNibPath = nil;
            
            NSString *inputFilePathExtension = [inputFilePath pathExtension];
            if ([inputFilePathExtension isEqualToString:@"nib"]) {
                // We can open nibs directly.
                inputNibPath = inputFilePath;
            } else if ([inputFilePathExtension isEqualToString:@"xib"]) {
                // We need to compile xibs to nibs before opening them.
                
                // @"/path/to/file.xib" => @"file.nib".
                NSString *inputNibName = [[[inputFilePath lastPathComponent] stringByDeletingPathExtension] stringByAppendingPathExtension:@"nib"];
                
                inputNibPath = [NSTemporaryDirectory() stringByAppendingPathComponent:inputNibName];
                [nibPathsToDelete addObject:inputNibPath];
                
                NSString *ibtoolIncantation = [NSString stringWithFormat:@""
                                               "/usr/bin/xcrun "
                                               "ibtool "
                                               "--errors "
                                               "--warnings "
                                               "--notices "
                                               "--output-format "
                                               "human-readable-text "
                                               "--compile "
                                               "%@ %@",
                                               inputNibPath,
                                               inputFilePath];
                system([ibtoolIncantation UTF8String]);
            } else {
                fprintf(stderr, "error: expecting .xib or .nib file path arg, got %s", [inputFilePath UTF8String]);
                exit(EXIT_FAILURE);
            }
            
            {{
                NSData *inputNibData = [NSData dataWithContentsOfFile:inputNibPath];
                assert(inputNibData);
                NSNib *inputNib = [[NSNib alloc] initWithNibData:inputNibData bundle:nil];
                assert(inputNib);
                
                {{
                    NSArray *topLevelObjects;
                    [inputNib instantiateWithOwner:nil topLevelObjects:&topLevelObjects];
                    
                    for (id topLevelObject in topLevelObjects) {
                        if ([topLevelObject isKindOfClass:[JRPDFLabel class]]) {
                            [labels addObject:topLevelObject];
                        } else if ([topLevelObject isKindOfClass:[NSView class]]) {
                            walkNSView(topLevelObject, labels);
                        }
                    }
                }}
            }}
        }
        
        //
        // Build an in-memory PDF where each page is a rendered JRPDFLabel.
        //
        
        NSMutableData *pdfData = [NSMutableData data];
        {{
            CGContextRef pdfContext = NULL;
            {{
                CGDataConsumerRef consumer = CGDataConsumerCreateWithCFData((__bridge CFMutableDataRef)pdfData);
                pdfContext = CGPDFContextCreate(consumer, NULL, NULL);
                NSCAssert(pdfContext, @"could not create PDF context");
                CGDataConsumerRelease(consumer);
            }}
            
            for (JRPDFLabel *label in labels) {
                NSGraphicsContext *gc = [NSGraphicsContext graphicsContextWithGraphicsPort:pdfContext flipped:NO];
                [NSGraphicsContext saveGraphicsState]; {
                    [NSGraphicsContext setCurrentContext:gc];
                    
                    CFMutableDictionaryRef pageDictionary = CFDictionaryCreateMutable(NULL,
                                                                                      0,
                                                                                      &kCFTypeDictionaryKeyCallBacks,
                                                                                      &kCFTypeDictionaryValueCallBacks);
                    {{
                        CGRect pageRect = CGRectMake(0, 0, label.bounds.size.width, label.bounds.size.height);
                        CFDataRef boxData = CFDataCreate(NULL, (const UInt8*) &pageRect, sizeof(CGRect));
                        CFDictionarySetValue(pageDictionary, kCGPDFContextMediaBox, boxData);
                    }}
                    CGPDFContextBeginPage(pdfContext, pageDictionary);
                    CFRelease(pageDictionary);
                    
                    [label drawRect:label.bounds];
                    
                    CGPDFContextEndPage(pdfContext);
                } [NSGraphicsContext restoreGraphicsState];
            }
            
            CGPDFContextClose(pdfContext);
            CGContextRelease(pdfContext);
        }}
        
        //
        // Build a lookup dictionary mapping each label's key (ASCII plist of its string, size, color, etc attributes) to its page index.
        //
        
        NSMutableDictionary *pageIndexByLabelKey = [NSMutableDictionary new];
        {{
            NSUInteger labelIndex = 0;
            for (JRPDFLabel *label in labels) {
                [pageIndexByLabelKey setObject:@(labelIndex++)
                                        forKey:[label jr_pdfLabelKey]];
            }
        }}
        
        //
        //  Append the lookup dictionary in binary plist format to the end of the PDF data stream. Hacky.
        //
        
        {{
            NSError *error = nil;
            NSData *bplist = [NSPropertyListSerialization dataWithPropertyList:@{@"v1":pageIndexByLabelKey}
                                                                        format:NSPropertyListBinaryFormat_v1_0
                                                                       options:0
                                                                         error:&error];
            assert(bplist);
            NSCAssert1(!error, @"%@", error);
            uint32_t bplistLengthNative = (uint32_t)[bplist length];
            uint32_t bplistLengthBigEndian = CFSwapInt32HostToBig(bplistLengthNative);
            const char magicNumber[] = "pdflabels_magic_number";
            
            // [pdf][bplist][uint32_t (big endian)]["pdflabels_magic_number"]
            [pdfData appendData:bplist];
            [pdfData appendBytes:&bplistLengthBigEndian length:sizeof(bplistLengthBigEndian)];
            [pdfData appendBytes:magicNumber length:strlen(magicNumber)];
        }}
        
        //
        // Write out the PDF data.
        //
        
        [pdfData writeToFile:outputFilePath atomically:YES];
        
        //
        // Delete any nibs we had to compile from xibs ourself.
        //
        
        for (NSString *nibPathToDelete in nibPathsToDelete) {
            [[NSFileManager defaultManager] removeItemAtPath:nibPathToDelete error:NULL];
        }
    }
    return 0;
}

@implementation JRPDFLabel
// This implementation intentionally empty.
@end

//
// NSTextField+jr_pdfLabelKey semver:1.0 (must be kept in sync with JRPDFLabel.m).
//

@implementation NSTextField (jr_pdfLabelKey)

- (NSString*)jr_pdfLabelKey {
    NSString *result = [@{
                          @"string": [self stringValue],
                          //@"fontName": [[self font] fontName], // Nope: becomes .Lucida when font is missing.
                          @"pointSize": @([[self font] pointSize]),
                          @"size": NSStringFromSize(self.bounds.size),
                          @"textColor": [self textColor],
                          @"alignment": @([self alignment]),
                          } description];
    //NSLog(@"jr_pdfLabelKey: %@ %@ %@", self, self.stringValue, result);
    return result;
}

@end