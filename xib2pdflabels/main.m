#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@interface JRPDFLabel : NSTextField
@end

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
        
        NSString *nibPath = @"/Users/wolf/Desktop/JRPDFLabel1.nib";
        NSData *nibData = [NSData dataWithContentsOfFile:nibPath];
        assert(nibData);
        NSNib *nib = [[NSNib alloc] initWithNibData:nibData bundle:nil];
        assert(nib);
        NSLog(@"%@", nib);
        
        NSMutableArray *labels = nil;
        {{
            NSArray *topLevelObjects;
            [nib instantiateWithOwner:nil topLevelObjects:&topLevelObjects];
            
            labels = [NSMutableArray array];
            for (id topLevelObject in topLevelObjects) {
                if ([topLevelObject isKindOfClass:[JRPDFLabel class]]) {
                    [labels addObject:topLevelObject];
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
                    
                    CFMutableDictionaryRef pageDictionary = CFDictionaryCreateMutable(NULL, 0,
                                                                                      &kCFTypeDictionaryKeyCallBacks,
                                                                                      &kCFTypeDictionaryValueCallBacks); // 6
                    {{
                        CGRect pageRect = CGRectMake(0, 0, label.bounds.size.width, label.bounds.size.height);
                        NSLog(@"%@ %@", label.stringValue, NSStringFromRect(label.bounds));
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
            
            //[pdfData writeToFile:@"/tmp/out2.pdf" atomically:NO];
        }}
    }
    return 0;
}

@implementation JRPDFLabel
@end