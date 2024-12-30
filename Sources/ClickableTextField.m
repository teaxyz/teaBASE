#import "ClickableTextField.h"

@implementation ClickableTextField

- (void)mouseDown:(NSEvent *)event {
    if (self.onClick) {
        self.onClick();
    } else if (self.target && self.action) {
        [self.target performSelector:self.action withObject:self];
    }
}

// update the cursor to be a pointer
- (void)resetCursorRects {
    [super resetCursorRects];
    [self addCursorRect:self.bounds cursor:[NSCursor pointingHandCursor]];
}

@end
