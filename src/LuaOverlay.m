#import "LuaOverlay.h"
#import "LuaEngine.h"

#pragma mark - Passthrough window

// A window that only swallows touches landing on its own controls, so the
// host app underneath stays usable.
@interface PassthroughWindow : UIWindow @end
@implementation PassthroughWindow
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    for (UIView *v in self.rootViewController.view.subviews) {
        if (!v.hidden && v.alpha > 0.01 &&
            CGRectContainsPoint(v.frame, point)) {
            return YES;
        }
    }
    return NO;
}
@end

#pragma mark - Overlay controller

@interface LuaOverlayVC : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UIButton *fab;         // the floating "W"
@property (nonatomic, strong) UIView *panel;         // editor panel
@property (nonatomic, strong) UITextField *nameField;
@property (nonatomic, strong) UITextView *codeView;
@property (nonatomic, strong) UILabel *status;
@property (nonatomic, strong) UITableView *savedTable;
@property (nonatomic, strong) NSMutableArray<NSString *> *saved; // file names
@end

@implementation LuaOverlayVC

static NSString *ScriptsDir(void) {
    NSString *dir = @"/var/mobile/Library/LuaInject/scripts";
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:dir]) {
        // Fall back to a sandbox-writable dir if the system path is denied.
        NSArray *docs = NSSearchPathForDirectoriesInDomains(
            NSDocumentDirectory, NSUserDomainMask, YES);
        dir = [docs.firstObject stringByAppendingPathComponent:@"LuaInject"];
    }
    [fm createDirectoryAtPath:dir withIntermediateDirectories:YES
                   attributes:nil error:nil];
    return dir;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.saved = [NSMutableArray array];
    [self buildFab];
    [self buildPanel];
    [self reloadSaved];
}

#pragma mark FAB

- (void)buildFab {
    CGFloat s = 56;
    self.fab = [UIButton buttonWithType:UIButtonTypeCustom];
    self.fab.frame = CGRectMake(20, 120, s, s);
    self.fab.backgroundColor = [UIColor colorWithRed:0.36 green:0.20 blue:0.85 alpha:1];
    self.fab.layer.cornerRadius = s / 2;
    self.fab.layer.shadowOpacity = 0.4;
    self.fab.layer.shadowRadius = 6;
    self.fab.layer.shadowOffset = CGSizeMake(0, 3);
    [self.fab setTitle:@"W" forState:UIControlStateNormal];
    self.fab.titleLabel.font = [UIFont boldSystemFontOfSize:24];
    [self.fab addTarget:self action:@selector(togglePanel)
       forControlEvents:UIControlEventTouchUpInside];

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
        initWithTarget:self action:@selector(dragFab:)];
    [self.fab addGestureRecognizer:pan];
    [self.view addSubview:self.fab];
}

- (void)dragFab:(UIPanGestureRecognizer *)g {
    CGPoint t = [g translationInView:self.view];
    self.fab.center = CGPointMake(self.fab.center.x + t.x,
                                  self.fab.center.y + t.y);
    [g setTranslation:CGPointZero inView:self.view];
}

#pragma mark Panel

- (void)buildPanel {
    CGRect b = self.view.bounds;
    CGFloat w = MIN(b.size.width - 24, 380);
    CGFloat h = MIN(b.size.height - 120, 520);
    self.panel = [[UIView alloc] initWithFrame:
        CGRectMake((b.size.width - w) / 2, 80, w, h)];
    self.panel.backgroundColor = [UIColor colorWithWhite:0.11 alpha:0.98];
    self.panel.layer.cornerRadius = 14;
    self.panel.hidden = YES;

    CGFloat pad = 12, y = pad;

    self.nameField = [[UITextField alloc] initWithFrame:
        CGRectMake(pad, y, w - 2*pad, 34)];
    self.nameField.placeholder = @"script name";
    self.nameField.textColor = UIColor.whiteColor;
    self.nameField.backgroundColor = [UIColor colorWithWhite:0.18 alpha:1];
    self.nameField.borderStyle = UITextBorderStyleRoundedRect;
    self.nameField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.nameField.autocorrectionType = UITextAutocorrectionTypeNo;
    [self.panel addSubview:self.nameField];
    y += 42;

    self.codeView = [[UITextView alloc] initWithFrame:
        CGRectMake(pad, y, w - 2*pad, 200)];
    self.codeView.font = [UIFont fontWithName:@"Menlo" size:13]
        ?: [UIFont systemFontOfSize:13];
    self.codeView.textColor = UIColor.whiteColor;
    self.codeView.backgroundColor = [UIColor colorWithWhite:0.06 alpha:1];
    self.codeView.layer.cornerRadius = 8;
    self.codeView.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.codeView.autocorrectionType = UITextAutocorrectionTypeNo;
    self.codeView.text = @"print('running inside the game VM')";
    [self.panel addSubview:self.codeView];
    y += 208;

    NSArray *titles = @[@"Run", @"Save & Run", @"Close"];
    NSArray *sels = @[
        NSStringFromSelector(@selector(runTapped)),
        NSStringFromSelector(@selector(saveRunTapped)),
        NSStringFromSelector(@selector(togglePanel)),
    ];
    CGFloat bw = (w - 2*pad - 16) / 3;
    for (int i = 0; i < 3; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.frame = CGRectMake(pad + i*(bw+8), y, bw, 38);
        [btn setTitle:titles[i] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont boldSystemFontOfSize:14];
        [btn setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        btn.backgroundColor = (i == 2)
            ? [UIColor colorWithWhite:0.3 alpha:1]
            : [UIColor colorWithRed:0.36 green:0.20 blue:0.85 alpha:1];
        btn.layer.cornerRadius = 8;
        [btn addTarget:self action:NSSelectorFromString(sels[i])
            forControlEvents:UIControlEventTouchUpInside];
        [self.panel addSubview:btn];
    }
    y += 46;

    self.status = [[UILabel alloc] initWithFrame:
        CGRectMake(pad, y, w - 2*pad, 20)];
    self.status.font = [UIFont systemFontOfSize:11];
    self.status.textColor = [UIColor colorWithWhite:0.7 alpha:1];
    [self.panel addSubview:self.status];
    y += 26;

    UILabel *savedLbl = [[UILabel alloc] initWithFrame:
        CGRectMake(pad, y, w - 2*pad, 16)];
    savedLbl.text = @"Saved scripts (tap to load, swipe to delete)";
    savedLbl.font = [UIFont systemFontOfSize:11];
    savedLbl.textColor = [UIColor colorWithWhite:0.5 alpha:1];
    [self.panel addSubview:savedLbl];
    y += 20;

    self.savedTable = [[UITableView alloc] initWithFrame:
        CGRectMake(pad, y, w - 2*pad, h - y - pad)];
    self.savedTable.backgroundColor = UIColor.clearColor;
    self.savedTable.dataSource = self;
    self.savedTable.delegate = self;
    [self.panel addSubview:self.savedTable];

    [self.view addSubview:self.panel];
}

- (void)togglePanel {
    self.panel.hidden = !self.panel.hidden;
    if (self.panel.hidden) [self.view endEditing:YES];
}

#pragma mark Actions

- (void)showStatus:(NSString *)err {
    if (err) {
        self.status.textColor = [UIColor colorWithRed:1 green:0.5 blue:0.5 alpha:1];
        self.status.text = [@"error: " stringByAppendingString:err];
    } else {
        self.status.textColor = [UIColor colorWithRed:0.5 green:1 blue:0.6 alpha:1];
        self.status.text = @"ran ok";
    }
}

- (void)runTapped {
    NSString *err = [[LuaEngine shared] run:self.codeView.text];
    [self showStatus:err];
}

- (void)saveRunTapped {
    NSString *name = self.nameField.text;
    if (name.length == 0) name = @"untitled";
    NSString *file = [name.lastPathComponent
        stringByAppendingPathExtension:@"lua"];
    NSString *path = [ScriptsDir() stringByAppendingPathComponent:file];
    [self.codeView.text writeToFile:path atomically:YES
        encoding:NSUTF8StringEncoding error:nil];
    [self reloadSaved];
    [self runTapped];
}

#pragma mark Saved list

- (void)reloadSaved {
    NSArray *all = [[NSFileManager defaultManager]
        contentsOfDirectoryAtPath:ScriptsDir() error:nil];
    [self.saved removeAllObjects];
    for (NSString *f in [all sortedArrayUsingSelector:@selector(compare:)])
        if ([f.pathExtension isEqualToString:@"lua"])
            [self.saved addObject:f];
    [self.savedTable reloadData];
}

- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s {
    return self.saved.count;
}

- (UITableViewCell *)tableView:(UITableView *)t
         cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [t dequeueReusableCellWithIdentifier:@"c"];
    if (!c) c = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                       reuseIdentifier:@"c"];
    c.backgroundColor = UIColor.clearColor;
    c.textLabel.textColor = UIColor.whiteColor;
    c.textLabel.font = [UIFont systemFontOfSize:14];
    c.textLabel.text = self.saved[ip.row];
    return c;
}

- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [t deselectRowAtIndexPath:ip animated:YES];
    NSString *file = self.saved[ip.row];
    NSString *path = [ScriptsDir() stringByAppendingPathComponent:file];
    self.nameField.text = file.stringByDeletingPathExtension;
    self.codeView.text = [NSString stringWithContentsOfFile:path
        encoding:NSUTF8StringEncoding error:nil];
}

- (void)tableView:(UITableView *)t
    commitEditingStyle:(UITableViewCellEditingStyle)style
     forRowAtIndexPath:(NSIndexPath *)ip {
    if (style == UITableViewCellEditingStyleDelete) {
        NSString *path = [ScriptsDir()
            stringByAppendingPathComponent:self.saved[ip.row]];
        [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
        [self reloadSaved];
    }
}

@end

#pragma mark - Entry

@implementation LuaOverlay

static PassthroughWindow *gWindow;

+ (void)present {
    if (![NSThread isMainThread]) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self present]; });
        return;
    }
    if (gWindow) return;

    UIWindowScene *scene = nil;
    for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
        if (s.activationState == UISceneActivationStateForegroundActive &&
            [s isKindOfClass:UIWindowScene.class]) {
            scene = (UIWindowScene *)s;
            break;
        }
    }

    gWindow = scene
        ? [[PassthroughWindow alloc] initWithWindowScene:scene]
        : [[PassthroughWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    gWindow.frame = UIScreen.mainScreen.bounds;
    gWindow.windowLevel = UIWindowLevelAlert + 100;
    gWindow.backgroundColor = UIColor.clearColor;
    gWindow.rootViewController = [LuaOverlayVC new];
    gWindow.hidden = NO;
}

@end
