#import <Cocoa/Cocoa.h>

static NSString *const kSysctlKey = @"debug.lowpri_throttle_enabled";
static NSString *const kSysctlPath = @"/usr/sbin/sysctl";
static NSString *const kLogPath = @"/usr/bin/log";

@interface AppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>

@property (nonatomic, strong) NSWindow *window;
@property (nonatomic, strong) NSSwitch *toggle;
@property (nonatomic, strong) NSTextField *subtitleLabel;
@property (nonatomic, strong) NSTextField *statusLabel;
@property (nonatomic, strong) NSButton *refreshButton;
@property (nonatomic, strong) NSButton *authReadButton;
@property (nonatomic, strong) NSPopUpButton *languagePopup;
@property (nonatomic, strong) NSWindow *logWindow;
@property (nonatomic, strong) NSTextView *logTextView;
@property (nonatomic, strong) NSTextField *logStatusLabel;
@property (nonatomic, strong) NSTask *logTask;
@property (nonatomic, assign) BOOL stateKnown;
@property (nonatomic, assign) BOOL busy;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [self buildMenu];
    [self buildWindow];
    [NSApp activateIgnoringOtherApps:YES];
    [self.window makeKeyAndOrderFront:nil];
    [self refreshState:nil];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    [self stopLogTask];
}

- (void)buildMenu {
    NSMenu *menubar = [[NSMenu alloc] init];

    NSMenuItem *appMenuItem = [[NSMenuItem alloc] init];
    [menubar addItem:appMenuItem];

    NSMenu *appMenu = [[NSMenu alloc] init];
    [appMenu addItemWithTitle:NSLocalizedString(@"menu.about", @"")
                       action:@selector(orderFrontStandardAboutPanel:)
                keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:NSLocalizedString(@"menu.quit", @"")
                       action:@selector(terminate:)
                keyEquivalent:@"q"];
    appMenuItem.submenu = appMenu;

    NSApp.mainMenu = menubar;
}

- (NSTextField *)labelWithString:(NSString *)string
                            font:(NSFont *)font
                           color:(NSColor *)color
                          wrapping:(BOOL)wrapping {
    NSTextField *label = wrapping
        ? [NSTextField wrappingLabelWithString:string]
        : [NSTextField labelWithString:string];
    label.font = font;
    label.textColor = color;
    return label;
}

- (void)buildWindow {
    NSRect contentRect = NSMakeRect(0, 0, 520, 380);
    NSWindowStyleMask style = NSWindowStyleMaskTitled
        | NSWindowStyleMaskClosable
        | NSWindowStyleMaskMiniaturizable;

    self.window = [[NSWindow alloc] initWithContentRect:contentRect
                                              styleMask:style
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    self.window.title = @"Time Machine Boost";
    self.window.releasedWhenClosed = NO;
    self.window.contentMinSize = contentRect.size;
    [self.window center];

    NSView *content = self.window.contentView;

    NSStackView *root = [[NSStackView alloc] init];
    root.translatesAutoresizingMaskIntoConstraints = NO;
    root.orientation = NSUserInterfaceLayoutOrientationVertical;
    root.alignment = NSLayoutAttributeLeading;
    root.spacing = 12;
    [content addSubview:root];

    [NSLayoutConstraint activateConstraints:@[
        [root.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20],
        [root.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20],
        [root.topAnchor constraintEqualToAnchor:content.topAnchor constant:20],
        [root.bottomAnchor constraintLessThanOrEqualToAnchor:content.bottomAnchor constant:-20]
    ]];

    // ---- 标题行：标题 + 弹性空白 + 开关 ----
    NSTextField *titleLabel = [self labelWithString:NSLocalizedString(@"main.title", @"")
                                               font:[NSFont systemFontOfSize:16 weight:NSFontWeightSemibold]
                                              color:[NSColor labelColor]
                                             wrapping:NO];

    NSView *flex = [[NSView alloc] init];
    [flex setContentHuggingPriority:1
                      forOrientation:NSLayoutConstraintOrientationHorizontal];
    [flex setContentCompressionResistancePriority:1
                                    forOrientation:NSLayoutConstraintOrientationHorizontal];

    NSSwitch *toggle = [[NSSwitch alloc] init];
    toggle.target = self;
    toggle.action = @selector(toggleChanged:);
    self.toggle = toggle;

    NSStackView *topRow = [[NSStackView alloc] init];
    topRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    topRow.alignment = NSLayoutAttributeCenterY;
    topRow.spacing = 12;
    topRow.distribution = NSStackViewDistributionFill;
    [topRow addArrangedSubview:titleLabel];
    [topRow addArrangedSubview:flex];
    [topRow addArrangedSubview:toggle];

    // ---- 副标题 ----
    self.subtitleLabel = [self labelWithString:NSLocalizedString(@"main.reading", @"")
                                          font:[NSFont systemFontOfSize:12]
                                         color:[NSColor secondaryLabelColor]
                                        wrapping:YES];

    // ---- 状态行 ----
    self.statusLabel = [self labelWithString:@""
                                        font:[NSFont systemFontOfSize:12]
                                       color:[NSColor secondaryLabelColor]
                                      wrapping:YES];

    NSView *separator = [[NSView alloc] init];
    separator.wantsLayer = YES;
    separator.layer.backgroundColor = [NSColor separatorColor].CGColor;

    // ---- 按钮行 ----
    self.refreshButton = [NSButton buttonWithTitle:NSLocalizedString(@"main.refresh", @"")
                                            target:self
                                            action:@selector(refreshState:)];
    self.authReadButton = [NSButton buttonWithTitle:NSLocalizedString(@"main.privilegedRead", @"")
                                             target:self
                                             action:@selector(privilegedRefreshState:)];
    NSButton *logButton = [NSButton buttonWithTitle:NSLocalizedString(@"main.openLogs", @"")
                                             target:self
                                             action:@selector(openLogWindow:)];

    NSTextField *versionLabel = [self labelWithString:NSLocalizedString(@"main.version", @"")
                                                 font:[NSFont systemFontOfSize:11]
                                                color:[NSColor tertiaryLabelColor]
                                               wrapping:NO];
    NSView *buttonFlex = [[NSView alloc] init];
    [buttonFlex setContentHuggingPriority:1
                             forOrientation:NSLayoutConstraintOrientationHorizontal];
    [buttonFlex setContentCompressionResistancePriority:1
                                          forOrientation:NSLayoutConstraintOrientationHorizontal];

    NSStackView *buttonRow = [[NSStackView alloc] init];
    buttonRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    buttonRow.alignment = NSLayoutAttributeCenterY;
    buttonRow.spacing = 8;
    buttonRow.distribution = NSStackViewDistributionFill;
    [buttonRow addArrangedSubview:self.refreshButton];
    [buttonRow addArrangedSubview:self.authReadButton];
    [buttonRow addArrangedSubview:logButton];
    [buttonRow addArrangedSubview:buttonFlex];
    [buttonRow addArrangedSubview:versionLabel];

    // ---- 语言行 ----
    NSTextField *languageLabel = [self labelWithString:NSLocalizedString(@"language.label", @"")
                                                   font:[NSFont systemFontOfSize:12]
                                                  color:[NSColor secondaryLabelColor]
                                                 wrapping:NO];
    self.languagePopup = [[NSPopUpButton alloc] init];
    [self.languagePopup addItemsWithTitles:@[@"English", @"简体中文", @"Español"]];
    self.languagePopup.target = self;
    self.languagePopup.action = @selector(languageChanged:);
    [self selectLanguagePopupItem];

    NSView *languageFlex = [[NSView alloc] init];
    [languageFlex setContentHuggingPriority:1
                             forOrientation:NSLayoutConstraintOrientationHorizontal];
    [languageFlex setContentCompressionResistancePriority:1
                                           forOrientation:NSLayoutConstraintOrientationHorizontal];

    NSStackView *languageRow = [[NSStackView alloc] init];
    languageRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    languageRow.alignment = NSLayoutAttributeCenterY;
    languageRow.spacing = 8;
    languageRow.distribution = NSStackViewDistributionFill;
    [languageRow addArrangedSubview:languageLabel];
    [languageRow addArrangedSubview:languageFlex];
    [languageRow addArrangedSubview:self.languagePopup];

    // ---- 说明 ----
    NSTextField *note1 = [self labelWithString:NSLocalizedString(@"main.note1", @"")
                                          font:[NSFont systemFontOfSize:11]
                                         color:[NSColor secondaryLabelColor]
                                        wrapping:YES];
    NSTextField *note2 = [self labelWithString:NSLocalizedString(@"main.note2", @"")
                                          font:[NSFont systemFontOfSize:11]
                                         color:[NSColor secondaryLabelColor]
                                        wrapping:YES];

    [root addArrangedSubview:topRow];
    [root addArrangedSubview:self.subtitleLabel];
    [root addArrangedSubview:separator];
    [root addArrangedSubview:self.statusLabel];
    [root addArrangedSubview:buttonRow];
    [root addArrangedSubview:languageRow];
    [root addArrangedSubview:note1];
    [root addArrangedSubview:note2];

    NSArray<NSView *> *fullWidthViews = @[
        topRow, self.subtitleLabel, separator, self.statusLabel, buttonRow,
        languageRow, note1, note2
    ];
    NSMutableArray<NSLayoutConstraint *> *constraints = [NSMutableArray array];
    for (NSView *view in fullWidthViews) {
        [constraints addObject:[view.widthAnchor constraintEqualToAnchor:root.widthAnchor]];
    }
    [constraints addObject:[separator.heightAnchor constraintEqualToConstant:1]];
    [NSLayoutConstraint activateConstraints:constraints];

    for (NSTextField *label in @[self.subtitleLabel, self.statusLabel, note1, note2]) {
        label.preferredMaxLayoutWidth = 460;
    }

    self.stateKnown = NO;
    [self updateControlStates];
}

- (BOOL)windowShouldClose:(NSWindow *)sender {
    if (sender == self.logWindow) {
        // 日志窗口只隐藏不销毁：停止任务后复用，避免在关闭动画中释放窗口导致崩溃。
        [self stopLogTask];
        [self updateStatusLog:NSLocalizedString(@"log.hiddenStatus", @"")];
        [sender orderOut:nil];
        return NO;
    }
    return YES;
}

- (void)updateControlStates {
    self.toggle.enabled = self.stateKnown && !self.busy;
    self.refreshButton.enabled = !self.busy;
    self.authReadButton.enabled = !self.stateKnown && !self.busy;
}

- (NSString *)effectiveLanguageCode {
    NSString *pref = [[NSUserDefaults standardUserDefaults] stringForKey:@"TMBLanguage"];
    if (pref.length > 0) {
        return pref;
    }

    NSString *preferred = [[NSBundle mainBundle] preferredLocalizations].firstObject;
    if ([preferred hasPrefix:@"zh"]) {
        return @"zh-Hans";
    }
    if ([preferred hasPrefix:@"es"]) {
        return @"es";
    }
    return @"en";
}

- (void)selectLanguagePopupItem {
    NSString *lang = [self effectiveLanguageCode];
    NSInteger index = [lang isEqualToString:@"zh-Hans"] ? 1
                    : ([lang isEqualToString:@"es"] ? 2 : 0);
    [self.languagePopup selectItemAtIndex:index];
}

- (IBAction)languageChanged:(id)sender {
    NSInteger index = self.languagePopup.indexOfSelectedItem;
    NSString *lang = index == 1 ? @"zh-Hans" : (index == 2 ? @"es" : @"en");
    NSString *current = [self effectiveLanguageCode];
    if ([lang isEqualToString:current]) {
        return;
    }

    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleInformational;
    alert.messageText = NSLocalizedString(@"language.restartTitle", @"");
    alert.informativeText = NSLocalizedString(@"language.restartMessage", @"");
    [alert addButtonWithTitle:NSLocalizedString(@"language.restartNow", @"")];
    [alert addButtonWithTitle:NSLocalizedString(@"language.later", @"")];

    if ([alert runModal] == NSAlertFirstButtonReturn) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:lang forKey:@"TMBLanguage"];
        [defaults setObject:@[lang] forKey:@"AppleLanguages"];
        [defaults synchronize];
        [self relaunchApp];
    } else {
        [self selectLanguagePopupItem];
    }
}

- (void)relaunchApp {
    NSString *appPath = [[NSBundle mainBundle] bundlePath];
    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/open"];
    task.arguments = @[@"-n", appPath];

    NSError *error = nil;
    if (![task launchAndReturnError:&error]) {
        [self updateStatus:[NSString stringWithFormat:
            NSLocalizedString(@"status.relaunchFailed", @""),
            error.localizedDescription ?: NSLocalizedString(@"error.unknown", @"")]
                     error:YES];
        [self selectLanguagePopupItem];
        return;
    }

    [NSApp terminate:nil];
}

- (void)updateStatus:(NSString *)status error:(BOOL)isError {
    self.statusLabel.stringValue = status;
    self.statusLabel.textColor = isError
        ? [NSColor systemRedColor]
        : [NSColor secondaryLabelColor];
}

- (void)setSubtitleForValue:(NSString *)value {
    if ([value isEqualToString:@"0"]) {
        self.subtitleLabel.stringValue = NSLocalizedString(@"subtitle.accelerated", @"");
    } else {
        self.subtitleLabel.stringValue = NSLocalizedString(@"subtitle.default", @"");
    }
}

// 读取工具进程输出（stdout+stderr 合并）。
- (NSString *)runTool:(NSString *)tool
            arguments:(NSArray<NSString *> *)arguments
               status:(int *)outStatus {
    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:tool];
    task.arguments = arguments;

    NSPipe *pipe = [[NSPipe alloc] init];
    task.standardOutput = pipe;
    task.standardError = pipe;

    NSError *error = nil;
    if (![task launchAndReturnError:&error]) {
        if (outStatus) {
            *outStatus = 1;
        }
        return error.localizedDescription ?: NSLocalizedString(@"error.cannotLaunchProcess", @"");
    }

    [task waitUntilExit];
    NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
    NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
    if (outStatus) {
        *outStatus = task.terminationStatus;
    }
    return [output stringByTrimmingCharactersInSet:
        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSString *)readSysctlValue {
    int status = 0;
    NSString *output = [self runTool:kSysctlPath
                           arguments:@[@"-n", kSysctlKey]
                              status:&status];
    if (status == 0 && ([output isEqualToString:@"0"] || [output isEqualToString:@"1"])) {
        return output;
    }
    return nil;
}

// 通过 osascript 触发系统管理员授权。shellCommand 是固定的内部字符串，不掺入用户输入。
- (NSString *)runAdminShellCommand:(NSString *)shellCommand
                            status:(int *)outStatus {
    NSString *script = [NSString stringWithFormat:
        @"do shell script \"%@\" with administrator privileges", shellCommand];
    return [self runTool:@"/usr/bin/osascript"
               arguments:@[@"-e", script]
                  status:outStatus];
}

- (IBAction)refreshState:(id)sender {
    if (self.busy) {
        return;
    }
    self.busy = YES;
    [self updateControlStates];
    [self updateStatus:NSLocalizedString(@"status.reading", @"") error:NO];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSString *value = [self readSysctlValue];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.busy = NO;
            [self updateControlStates];
            if (value) {
                self.stateKnown = YES;
                self.toggle.state = [value isEqualToString:@"0"]
                    ? NSControlStateValueOn
                    : NSControlStateValueOff;
                [self setSubtitleForValue:value];
                [self updateStatus:[NSString stringWithFormat:
                    NSLocalizedString(@"status.current", @""), kSysctlKey, value]
                             error:NO];
            } else {
                self.stateKnown = NO;
                [self updateStatus:NSLocalizedString(@"status.readFailed", @"")
                             error:YES];
                [self updateControlStates];
            }
        });
    });
}

- (IBAction)privilegedRefreshState:(id)sender {
    if (self.busy) {
        return;
    }
    self.busy = YES;
    [self updateControlStates];
    [self updateStatus:NSLocalizedString(@"status.readingPrivileged", @"") error:NO];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        int status = 0;
        NSString *shell = [NSString stringWithFormat:@"%@ -n %@", kSysctlPath, kSysctlKey];
        NSString *output = [self runAdminShellCommand:shell status:&status];
        dispatch_async(dispatch_get_main_queue(), ^{
            self.busy = NO;
            [self updateControlStates];
            if (status == 0 && ([output isEqualToString:@"0"] || [output isEqualToString:@"1"])) {
                self.stateKnown = YES;
                self.toggle.state = [output isEqualToString:@"0"]
                    ? NSControlStateValueOn
                    : NSControlStateValueOff;
                [self setSubtitleForValue:output];
                [self updateStatus:[NSString stringWithFormat:
                    NSLocalizedString(@"status.privilegedReadDone", @""), kSysctlKey, output]
                             error:NO];
            } else {
                self.stateKnown = NO;
                BOOL cancelled = [output containsString:@"-128"];
                [self updateStatus:cancelled
                    ? NSLocalizedString(@"auth.cancelledShort", @"")
                    : [NSString stringWithFormat:
                        NSLocalizedString(@"status.privilegedReadFailed", @""), status]
                             error:YES];
                [self updateControlStates];
            }
        });
    });
}

- (void)toggleChanged:(NSSwitch *)sender {
    if (!self.stateKnown || self.busy) {
        return;
    }
    BOOL wantOn = (sender.state == NSControlStateValueOn);
    [self applyAcceleration:wantOn];
}

- (void)applyAcceleration:(BOOL)accelerate {
    NSString *target = accelerate ? @"0" : @"1";
    self.busy = YES;
    [self updateControlStates];
    [self updateStatus:NSLocalizedString(@"status.applying", @"") error:NO];

    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        int status = 0;
        // 同一个授权里完成“设置 + 回读”，避免凭据过期导致误报。
        NSString *shell = [NSString stringWithFormat:
            @"%@ %@=%@ >/dev/null && %@ -n %@",
            kSysctlPath, kSysctlKey, target, kSysctlPath, kSysctlKey];
        NSString *output = [self runAdminShellCommand:shell status:&status];

        dispatch_async(dispatch_get_main_queue(), ^{
            self.busy = NO;
            [self updateControlStates];
            if (status == 0 && [output isEqualToString:target]) {
                self.stateKnown = YES;
                self.toggle.state = accelerate
                    ? NSControlStateValueOn
                    : NSControlStateValueOff;
                [self setSubtitleForValue:output];
                [self updateStatus:[NSString stringWithFormat:NSLocalizedString(
                    accelerate ? @"status.toggleDone.accelerated" : @"status.toggleDone.default",
                    @""), kSysctlKey, output]
                             error:NO];
            } else if (status != 0 && [output containsString:@"-128"]) {
                [self updateStatus:NSLocalizedString(@"auth.cancelled", @"") error:YES];
            } else {
                [self updateStatus:[NSString stringWithFormat:
                    NSLocalizedString(@"status.toggleFailed", @""), status]
                             error:YES];
            }
        });
    });
}

- (void)openLogWindow:(id)sender {
    if (self.logWindow) {
        [self.logWindow makeKeyAndOrderFront:nil];
        [self startLogStream];
        return;
    }

    NSRect contentRect = NSMakeRect(0, 0, 760, 500);
    NSWindowStyleMask style = NSWindowStyleMaskTitled
        | NSWindowStyleMaskClosable
        | NSWindowStyleMaskMiniaturizable
        | NSWindowStyleMaskResizable;
    NSWindow *window = [[NSWindow alloc] initWithContentRect:contentRect
                                                   styleMask:style
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    window.title = NSLocalizedString(@"log.windowTitle", @"");
    window.delegate = self;
    window.releasedWhenClosed = NO;
    window.contentMinSize = NSMakeSize(480, 320);
    [window center];
    self.logWindow = window;

    NSView *content = window.contentView;

    NSStackView *root = [[NSStackView alloc] init];
    root.translatesAutoresizingMaskIntoConstraints = NO;
    root.orientation = NSUserInterfaceLayoutOrientationVertical;
    root.alignment = NSLayoutAttributeLeading;
    root.spacing = 10;
    [content addSubview:root];

    [NSLayoutConstraint activateConstraints:@[
        [root.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:12],
        [root.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-12],
        [root.topAnchor constraintEqualToAnchor:content.topAnchor constant:12],
        [root.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-12]
    ]];

    self.logStatusLabel = [self labelWithString:NSLocalizedString(@"log.preparing", @"")
                                           font:[NSFont systemFontOfSize:12]
                                          color:[NSColor secondaryLabelColor]
                                         wrapping:YES];

    NSTextView *textView = [[NSTextView alloc] init];
    textView.editable = NO;
    textView.font = [NSFont userFixedPitchFontOfSize:11];
    textView.backgroundColor = [NSColor textBackgroundColor];
    textView.textColor = [NSColor labelColor];
    textView.autoresizingMask = NSViewWidthSizable;
    textView.minSize = NSMakeSize(0, 0);
    textView.maxSize = NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX);
    textView.verticallyResizable = YES;
    textView.horizontallyResizable = NO;

    NSScrollView *scrollView = [[NSScrollView alloc] init];
    scrollView.hasVerticalScroller = YES;
    scrollView.hasHorizontalScroller = NO;
    scrollView.borderType = NSBezelBorder;
    scrollView.documentView = textView;
    self.logTextView = textView;

    NSButton *clearButton = [NSButton buttonWithTitle:NSLocalizedString(@"log.clear", @"")
                                               target:self
                                               action:@selector(clearLog:)];
    NSButton *closeButton = [NSButton buttonWithTitle:NSLocalizedString(@"log.stopAndHide", @"")
                                               target:self
                                               action:@selector(closeLogWindow:)];

    NSView *buttonFlex = [[NSView alloc] init];
    [buttonFlex setContentHuggingPriority:1
                             forOrientation:NSLayoutConstraintOrientationHorizontal];
    [buttonFlex setContentCompressionResistancePriority:1
                                          forOrientation:NSLayoutConstraintOrientationHorizontal];

    NSStackView *buttonRow = [[NSStackView alloc] init];
    buttonRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    buttonRow.alignment = NSLayoutAttributeCenterY;
    buttonRow.spacing = 8;
    buttonRow.distribution = NSStackViewDistributionFill;
    [buttonRow addArrangedSubview:clearButton];
    [buttonRow addArrangedSubview:buttonFlex];
    [buttonRow addArrangedSubview:closeButton];

    [root addArrangedSubview:self.logStatusLabel];
    [root addArrangedSubview:scrollView];
    [root addArrangedSubview:buttonRow];

    [NSLayoutConstraint activateConstraints:@[
        [self.logStatusLabel.widthAnchor constraintEqualToAnchor:root.widthAnchor],
        [scrollView.widthAnchor constraintEqualToAnchor:root.widthAnchor],
        [scrollView.heightAnchor constraintGreaterThanOrEqualToConstant:300],
        [buttonRow.widthAnchor constraintEqualToAnchor:root.widthAnchor]
    ]];
    self.logStatusLabel.preferredMaxLayoutWidth = 730;

    [window makeKeyAndOrderFront:nil];
    [self startLogStream];
}

- (void)startLogStream {
    [self stopLogTask];

    [self clearLog:nil];
    [self appendLogText:[NSString stringWithFormat:@"%@\n",
        NSLocalizedString(@"log.streamStarted", @"")]];
    [self updateStatusLog:NSLocalizedString(@"log.streamingStatus", @"")];

    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:kLogPath];
    task.arguments = @[
        @"stream",
        @"--predicate",
        @"subsystem == \"com.apple.TimeMachine\"",
        @"--style",
        @"compact"
    ];

    NSPipe *pipe = [[NSPipe alloc] init];
    task.standardOutput = pipe;
    task.standardError = pipe;

    __weak AppDelegate *weakSelf = self;
    NSFileHandle *readHandle = pipe.fileHandleForReading;
    readHandle.readabilityHandler = ^(NSFileHandle *handle) {
        NSData *data = [handle availableData];
        if (data.length == 0) {
            handle.readabilityHandler = nil;
            return;
        }
        NSString *chunk = [[NSString alloc] initWithData:data
                                                encoding:NSUTF8StringEncoding];
        if (chunk.length > 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf appendLogText:chunk];
            });
        }
    };

    NSError *error = nil;
    if (![task launchAndReturnError:&error]) {
        [self appendLogText:[NSString stringWithFormat:
            @"\n%@\n",
            [NSString stringWithFormat:NSLocalizedString(@"log.startFailedLine", @""),
                error.localizedDescription ?: NSLocalizedString(@"error.unknown", @"")]]];
        [self updateStatusLog:NSLocalizedString(@"log.startFailedStatus", @"")];
        return;
    }

    self.logTask = task;
    task.terminationHandler = ^(NSTask *endedTask) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (weakSelf.logTask == endedTask) {
                weakSelf.logTask = nil;
                [weakSelf appendLogText:[NSString stringWithFormat:@"\n%@\n",
                    NSLocalizedString(@"log.streamEnded", @"")]];
                [weakSelf updateStatusLog:NSLocalizedString(@"log.streamEndedStatus", @"")];
            }
        });
    };
}

- (void)updateStatusLog:(NSString *)text {
    self.logStatusLabel.stringValue = text;
    self.logStatusLabel.textColor = [NSColor secondaryLabelColor];
}

- (void)appendLogText:(NSString *)text {
    if (!self.logTextView || !self.logWindow) {
        return;
    }

    NSTextStorage *storage = self.logTextView.textStorage;
    [storage beginEditing];
    if (storage.length > 600000) {
        [storage deleteCharactersInRange:NSMakeRange(0, storage.length - 400000)];
    }
    [storage appendAttributedString:[[NSAttributedString alloc] initWithString:text
                                                                   attributes:@{
        NSFontAttributeName: [NSFont userFixedPitchFontOfSize:11],
        NSForegroundColorAttributeName: [NSColor labelColor]
    }]];
    [storage endEditing];
    [self.logTextView scrollToEndOfDocument:nil];
}

- (void)stopLogTask {
    NSTask *task = self.logTask;
    if (!task) {
        return;
    }
    task.terminationHandler = nil;
    if (task.isRunning) {
        [task terminate];
    }
    self.logTask = nil;
}

- (IBAction)clearLog:(id)sender {
    [self.logTextView.textStorage deleteCharactersInRange:
        NSMakeRange(0, self.logTextView.textStorage.length)];
}

- (IBAction)closeLogWindow:(id)sender {
    [self.logWindow performClose:nil];
}

@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        AppDelegate *delegate = [[AppDelegate alloc] init];
        app.delegate = delegate;
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        [app run];
    }
    return 0;
}
