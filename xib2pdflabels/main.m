#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "NSTextField+jr_pdfLabelKey.h"

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
    @autoreleasepool {
        // xib2pdflabels JRPDFLabel.pdf MainMenu.xib MyWindow.xib MyView.nib
        
        // TODO: xib => nib
        // TODO: collect every nib
        // TODO: collect every JRPDFLabel from every nib
        // build lookup table
        // render each view to a pdf page
        // append bplist to pdf data
        // append bplist size to pdf data
        // burp pdf data
        
        NSString *nibPath = @"/Users/wolf/_current/JRPDFLabel/JRPDFLabel1.nib";
        NSData *nibData = [NSData dataWithContentsOfFile:nibPath];
        assert(nibData);
        NSNib *nib = [[NSNib alloc] initWithNibData:nibData bundle:nil];
        assert(nib);
        
        NSMutableArray *labels = nil;
        {{
            NSArray *topLevelObjects;
            [nib instantiateWithOwner:nil topLevelObjects:&topLevelObjects];
            
            labels = [NSMutableArray array];
            for (id topLevelObject in topLevelObjects) {
                if ([topLevelObject isKindOfClass:[JRPDFLabel class]]) {
                    [labels addObject:topLevelObject];
                } else if ([topLevelObject isKindOfClass:[NSView class]]) {
                    walkNSView(topLevelObject, labels);
                }
            }
        }}
        
        NSMutableData *pdfData = nil;
        {{
            pdfData = [NSMutableData data];
            CGDataConsumerRef consumer = CGDataConsumerCreateWithCFData((CFMutableDataRef)pdfData);
            CGContextRef pdfContext = CGPDFContextCreate(consumer, NULL, NULL);
            CGDataConsumerRelease(consumer);
            
            NSCAssert(pdfContext != NULL, @"could not create PDF context");
            
            for (JRPDFLabel *label in labels) {
                NSGraphicsContext* newGC = [NSGraphicsContext graphicsContextWithGraphicsPort:pdfContext flipped:NO];
                [NSGraphicsContext saveGraphicsState]; {
                    [NSGraphicsContext setCurrentContext:newGC];
                    
                    CFMutableDictionaryRef pageDictionary = CFDictionaryCreateMutable(NULL,
                                                                                      0,
                                                                                      &kCFTypeDictionaryKeyCallBacks,
                                                                                      &kCFTypeDictionaryValueCallBacks);
                    {{
                        CGRect pageRect = CGRectMake(0, 0, label.bounds.size.width, label.bounds.size.height);
                        CFDataRef boxData = CFDataCreate(NULL,(const UInt8*)&pageRect, sizeof (CGRect));
                        CFDictionarySetValue(pageDictionary, kCGPDFContextMediaBox, boxData);
                    }}
                    CGPDFContextBeginPage( pdfContext, pageDictionary );
                    CFRelease(pageDictionary);
                    
                    //CGContextTranslateCTM( pdfContext, 0.0, size.height );
                    //CGContextScaleCTM( pdfContext, 1.0, -1.0 );
                    
                    [label drawRect:label.bounds];
                    
                    CGPDFContextEndPage( pdfContext );
                } [NSGraphicsContext restoreGraphicsState];
            }
            
            CGPDFContextClose( pdfContext );
            CGContextRelease( pdfContext );
        }}
        
        NSMutableDictionary *pageIndexByLabelKey = [NSMutableDictionary new];
        {{
            NSUInteger labelIndex = 0;
            for (JRPDFLabel *label in labels) {
                [pageIndexByLabelKey setObject:@(labelIndex++)
                                        forKey:[label jr_pdfLabelKey]];
            }
        }}
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
        
        [pdfData writeToFile:@"/Users/wolf/_current/JRPDFLabel/JRPDFLabelUsingApp/JRPDFLabelUsingApp/JRPDFLabel.pdf" atomically:NO];
    }
    return 0;
}

@implementation JRPDFLabel
@end