#import "LittleDia.h"

@interface DPLittleTarget : NSObject
@end

@implementation DPLittleTarget
- (void)moveToDia:(NSButton *)sender { DPMoveToDia(sender.window); }
@end

void DPAddMoveButton(NSWindow *window) {
    static DPLittleTarget *target;
    target = target ?: [DPLittleTarget new];
    NSButton *button = [NSButton buttonWithTitle:@"Open in Dia" image:[NSImage imageWithSystemSymbolName:@"arrow.up.forward.app" accessibilityDescription:nil]
                                          target:target action:@selector(moveToDia:)];
    button.bezelStyle = NSBezelStyleInline;
    button.imagePosition = NSImageLeading;
    button.controlSize = NSControlSizeSmall;
    button.toolTip = @"Open in Dia (⌘O)";
    NSVisualEffectView *pill = [NSVisualEffectView new];
    pill.material = NSVisualEffectMaterialHUDWindow;
    pill.state = NSVisualEffectStateActive;
    pill.wantsLayer = YES;
    pill.layer.cornerRadius = 12;
    pill.layer.cornerCurve = kCACornerCurveContinuous;
    pill.layer.masksToBounds = YES;
    [pill addSubview:button];
    NSView *content = window.contentView;
    [content addSubview:pill];
    for (NSView *v in @[pill, button]) v.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [button.leadingAnchor constraintEqualToAnchor:pill.leadingAnchor constant:4],
        [button.trailingAnchor constraintEqualToAnchor:pill.trailingAnchor constant:-4],
        [button.topAnchor constraintEqualToAnchor:pill.topAnchor constant:2],
        [button.bottomAnchor constraintEqualToAnchor:pill.bottomAnchor constant:-2],
        [pill.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-12],
        [pill.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-12],
    ]];
}
