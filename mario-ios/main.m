#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

static NSString *const GameURL = @"https://mario.v61d.chatgpt.site/";

@interface GameController : UIViewController <WKNavigationDelegate, WKUIDelegate>
@property(nonatomic,strong) WKWebView *webView;
@property(nonatomic,strong) UIActivityIndicatorView *spinner;
@property(nonatomic,strong) UIView *errorPanel;
- (void)loadGame;
- (void)pauseAndSave;
@end

@implementation GameController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:0.02 green:0.025 blue:0.02 alpha:1];
    WKWebViewConfiguration *config = [WKWebViewConfiguration new];
    config.websiteDataStore = WKWebsiteDataStore.defaultDataStore;
    config.allowsInlineMediaPlayback = YES;
    config.mediaTypesRequiringUserActionForPlayback = WKAudiovisualMediaTypeNone;
    self.webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:config];
    self.webView.translatesAutoresizingMaskIntoConstraints = NO;
    self.webView.navigationDelegate = self;
    self.webView.UIDelegate = self;
    self.webView.opaque = NO;
    self.webView.backgroundColor = self.view.backgroundColor;
    self.webView.scrollView.backgroundColor = self.view.backgroundColor;
    self.webView.scrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    self.webView.scrollView.bounces = NO;
    self.webView.scrollView.pinchGestureRecognizer.enabled = NO;
    [self.view addSubview:self.webView];
    [NSLayoutConstraint activateConstraints:@[
        [self.webView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.webView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.webView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.webView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]
    ]];
    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.spinner.color = [UIColor colorWithRed:0.8 green:1 blue:0.37 alpha:1];
    self.spinner.translatesAutoresizingMaskIntoConstraints = NO;
    self.spinner.hidesWhenStopped = YES;
    [self.view addSubview:self.spinner];
    [NSLayoutConstraint activateConstraints:@[
        [self.spinner.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.spinner.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor]
    ]];
    UIStackView *panel = [[UIStackView alloc] init];
    panel.axis = UILayoutConstraintAxisVertical;
    panel.spacing = 20;
    panel.alignment = UIStackViewAlignmentCenter;
    panel.translatesAutoresizingMaskIntoConstraints = NO;
    UILabel *message = [UILabel new];
    message.text = @"تعذّر الاتصال بالموقع.\nتأكد من الإنترنت ثم أعد المحاولة.";
    message.textColor = UIColor.whiteColor;
    message.font = [UIFont systemFontOfSize:18 weight:UIFontWeightMedium];
    message.textAlignment = NSTextAlignmentCenter;
    message.numberOfLines = 0;
    UIButton *retry = [UIButton buttonWithType:UIButtonTypeSystem];
    [retry setTitle:@"إعادة المحاولة" forState:UIControlStateNormal];
    [retry setTitleColor:[UIColor colorWithRed:0.8 green:1 blue:0.37 alpha:1] forState:UIControlStateNormal];
    retry.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    [retry addTarget:self action:@selector(loadGame) forControlEvents:UIControlEventTouchUpInside];
    [panel addArrangedSubview:message];
    [panel addArrangedSubview:retry];
    [self.view addSubview:panel];
    [NSLayoutConstraint activateConstraints:@[
        [panel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [panel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [panel.widthAnchor constraintLessThanOrEqualToAnchor:self.view.widthAnchor constant:-40],
        [retry.heightAnchor constraintGreaterThanOrEqualToConstant:48]
    ]];
    self.errorPanel = panel;
    [self loadGame];
}
- (BOOL)prefersStatusBarHidden { return YES; }
- (BOOL)prefersHomeIndicatorAutoHidden { return YES; }
- (UIRectEdge)preferredScreenEdgesDeferringSystemGestures { return UIRectEdgeAll; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientations { return UIInterfaceOrientationMaskAll; }
- (void)loadGame {
    self.errorPanel.hidden = YES;
    self.webView.hidden = NO;
    [self.spinner startAnimating];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:GameURL]
        cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:30];
    [self.webView loadRequest:request];
}
- (void)pauseAndSave {
    NSString *script = @"(()=>{try{if(typeof saveCurrentState==='function' && typeof phase!=='undefined' && phase==='ready'){saveCurrentState().catch(()=>{});}window.EJS_emulator?.pause?.();if(typeof releaseAutoRun==='function')releaseAutoRun();if(typeof syncControls==='function')syncControls();}catch(e){}})()";
    [self.webView evaluateJavaScript:script completionHandler:nil];
}
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [self.spinner stopAnimating];
    self.errorPanel.hidden = YES;
}
- (void)showError:(NSError *)error {
    if (error.code == NSURLErrorCancelled) return;
    [self.spinner stopAnimating];
    self.webView.hidden = YES;
    self.errorPanel.hidden = NO;
}
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error { [self showError:error]; }
- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error { [self showError:error]; }
- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView { [self loadGame]; }
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)action decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSURL *url = action.request.URL;
    if ([url.scheme.lowercaseString isEqualToString:@"https"] && [url.host.lowercaseString isEqualToString:@"mario.v61d.chatgpt.site"]) {
        decisionHandler(WKNavigationActionPolicyAllow);
    } else {
        decisionHandler(WKNavigationActionPolicyCancel);
        if (action.navigationType == WKNavigationTypeLinkActivated && [url.scheme.lowercaseString isEqualToString:@"https"]) {
            [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
        }
    }
}
- (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)action windowFeatures:(WKWindowFeatures *)windowFeatures {
    if (!action.targetFrame && [action.request.URL.scheme.lowercaseString isEqualToString:@"https"]) {
        [UIApplication.sharedApplication openURL:action.request.URL options:@{} completionHandler:nil];
    }
    return nil;
}
@end

@interface AppDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic,strong) UIWindow *window;
@property(nonatomic,strong) GameController *game;
@end
@implementation AppDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.game = [GameController new];
    self.window.rootViewController = self.game;
    [self.window makeKeyAndVisible];
    return YES;
}
- (void)applicationDidBecomeActive:(UIApplication *)application { application.idleTimerDisabled = YES; }
- (void)applicationWillResignActive:(UIApplication *)application {
    application.idleTimerDisabled = NO;
    [self.game pauseAndSave];
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(AppDelegate.class)); }
}
