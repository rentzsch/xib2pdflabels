#import "NSTextField+jr_pdfLabelKey.h"

@implementation NSTextField (jr_pdfLabelKey)

- (NSString*)jr_pdfLabelKey {
    return [@{
             @"string": [self stringValue],
             @"fontName": [[self font] fontName],
             @"pointSize": @([[self font] pointSize]),
             @"size": NSStringFromSize(self.bounds.size),
             @"textColor": [self textColor],
             @"alignment": @([self alignment]),
             } description];
}

@end
