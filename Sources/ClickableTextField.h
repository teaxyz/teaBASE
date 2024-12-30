#import <Cocoa/Cocoa.h>

@interface ClickableTextField : NSTextField

@property (nonatomic, copy) void (^onClick)(void);

@end
