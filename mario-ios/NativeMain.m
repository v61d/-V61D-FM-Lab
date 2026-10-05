// SPDX-License-Identifier: GPL-2.0-or-later
#import <UIKit/UIKit.h>
#import <GameController/GameController.h>
#import <AVFoundation/AVFoundation.h>
#import "NativeEngine.h"
#import "MenuController.h"
#import "SaveStore.h"
#import <ReplayKit/ReplayKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#include "libretro.h"
static UIColor *Lime(void){return [UIColor colorWithRed:0.8 green:1 blue:0.37 alpha:1];}
static UIColor *Surface(void){return [UIColor colorWithRed:0.09 green:0.105 blue:0.075 alpha:1];}

@interface ArrowButton:UIButton
@property(nonatomic)CGFloat angle;
@property(nonatomic,strong)CAShapeLayer *arrow;
@end
@implementation ArrowButton
- (void)layoutSubviews{[super layoutSubviews];if(!self.arrow){self.arrow=[CAShapeLayer layer];[self.layer addSublayer:self.arrow];}CGFloat s=MIN(self.bounds.size.width,self.bounds.size.height)*0.4;self.arrow.frame=CGRectMake((self.bounds.size.width-s)/2,(self.bounds.size.height-s)/2,s,s);UIBezierPath *p=[UIBezierPath bezierPath];[p moveToPoint:CGPointMake(s/2,0)];[p addLineToPoint:CGPointMake(s,s)];[p addLineToPoint:CGPointMake(0,s)];[p closePath];self.arrow.path=p.CGPath;self.arrow.fillColor=UIColor.whiteColor.CGColor;self.arrow.affineTransform=CGAffineTransformMakeRotation(self.angle);}
@end
@interface GameScreen:UIView
@property(nonatomic,strong)CALayer *pixels;
@property(nonatomic,strong)CAShapeLayer *lines;
@property(nonatomic)BOOL scanlines;
@property(nonatomic)NSInteger rotation;
- (void)showFrame:(CGImageRef)image;
@end
@implementation GameScreen
- (instancetype)init{if((self=[super init])){self.backgroundColor=UIColor.blackColor;self.pixels=[CALayer layer];self.pixels.magnificationFilter=kCAFilterNearest;self.pixels.minificationFilter=kCAFilterNearest;[self.layer addSublayer:self.pixels];self.lines=[CAShapeLayer layer];self.lines.strokeColor=[UIColor colorWithWhite:0 alpha:0.2].CGColor;self.lines.lineWidth=1;[self.layer addSublayer:self.lines];}return self;}
- (void)layoutSubviews{
 [super layoutSubviews];CGFloat w=self.bounds.size.width,h=self.bounds.size.height;BOOL rotated=self.rotation%2;CGFloat ratio=rotated?240.0/256.0:256.0/240.0,width=MIN(w,h*ratio),height=width/ratio;
 [CATransaction begin];[CATransaction setDisableActions:YES];self.pixels.affineTransform=CGAffineTransformIdentity;self.pixels.bounds=CGRectMake(0,0,rotated?height:width,rotated?width:height);self.pixels.position=CGPointMake(w/2,h/2);self.pixels.affineTransform=CGAffineTransformMakeRotation(self.rotation*M_PI_2);
 self.lines.frame=self.pixels.frame;self.lines.hidden=!self.scanlines;UIBezierPath *path=[UIBezierPath bezierPath];for(CGFloat y=0;y<height;y+=MAX(2,height/120)){[path moveToPoint:CGPointMake(0,y)];[path addLineToPoint:CGPointMake(width,y)];}self.lines.path=path.CGPath;[CATransaction commit];
}
- (void)showFrame:(CGImageRef)image{[CATransaction begin];[CATransaction setDisableActions:YES];self.pixels.contents=(__bridge id)image;[CATransaction commit];}
@end
@interface GameController:UIViewController<UIDocumentPickerDelegate,RPPreviewViewControllerDelegate>
@property(nonatomic,strong)NativeEngine *engine;
@property(nonatomic,strong)GameScreen *screen;
@property(nonatomic,strong)UIView *movement,*actions,*toolbar;
@property(nonatomic,strong)NSArray<UIButton *> *directions,*actionButtons,*tools;
@property(nonatomic,strong)UIButton *playOverlay;
@property(nonatomic,strong)UILabel *notice;
@property(nonatomic,strong)GCController *controller;
@property(nonatomic)BOOL controllerBDown;
@property(nonatomic,strong)NSMutableDictionary *prefs;
@property(nonatomic,strong)SaveStore *store;
@property(nonatomic,strong)UILabel *fpsLabel,*brandLabel;
@property(nonatomic,strong)UIImageView *brandLogo;
@property(nonatomic,strong)UIButton *rewindButton,*newButton,*fullscreenExit;
@property(nonatomic,strong)UISegmentedControl *inputPicker;
@property(nonatomic,strong)NSTimer *statusTimer;
@property(nonatomic,strong)MenuController *saveMenu;
@property(nonatomic,strong)NSMutableArray<NSDictionary *> *cheats;
@property(nonatomic)double lastAutoSave;
@property(nonatomic)BOOL fullscreen,recording,modalWasPaused;
- (void)applyPreferences;
- (void)showSettings;
- (void)showHome;
- (void)showSaves;
- (void)startNew;
- (void)toggleFullscreen;
- (void)inputChanged;
- (void)pauseAndSave;
@end
@implementation GameController
- (UIButton *)button:(NSString *)title input:(NSInteger)input parent:(UIView *)parent{UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];[b setTitle:title forState:UIControlStateNormal];[b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];b.titleLabel.font=[UIFont boldSystemFontOfSize:28];b.backgroundColor=[UIColor colorWithRed:0.17 green:0.19 blue:0.145 alpha:1];b.layer.cornerRadius=14;b.layer.borderWidth=1;b.layer.borderColor=[UIColor colorWithWhite:1 alpha:0.12].CGColor;b.tag=input;b.exclusiveTouch=NO;[b addTarget:self action:@selector(press:) forControlEvents:UIControlEventTouchDown|UIControlEventTouchDragEnter];[b addTarget:self action:@selector(release:) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventTouchCancel|UIControlEventTouchDragExit];[parent addSubview:b];return b;}
- (void)viewDidLoad{
 [super viewDidLoad];self.view.backgroundColor=Surface();self.screen=[GameScreen new];[self.view addSubview:self.screen];self.movement=[UIView new];self.actions=[UIView new];self.toolbar=[UIView new];for(UIView *v in @[self.movement,self.actions,self.toolbar])[self.view addSubview:v];
 NSMutableArray *arrows=[NSMutableArray new];NSArray *ids=@[@(RETRO_DEVICE_ID_JOYPAD_UP),@(RETRO_DEVICE_ID_JOYPAD_LEFT),@(RETRO_DEVICE_ID_JOYPAD_RIGHT),@(RETRO_DEVICE_ID_JOYPAD_DOWN)],*angles=@[@0,@(-M_PI_2),@(M_PI_2),@(M_PI)],*labels=@[@"أعلى",@"يسار",@"يمين",@"أسفل"];
 for(int i=0;i<4;i++){ArrowButton *b=[ArrowButton new];b.angle=[angles[i] doubleValue];b.tag=[ids[i] integerValue];b.accessibilityLabel=labels[i];b.backgroundColor=[UIColor colorWithRed:0.17 green:0.19 blue:0.145 alpha:1];b.layer.cornerRadius=14;b.layer.borderWidth=1;b.layer.borderColor=[UIColor colorWithWhite:1 alpha:0.12].CGColor;[b addTarget:self action:@selector(press:) forControlEvents:UIControlEventTouchDown|UIControlEventTouchDragEnter];[b addTarget:self action:@selector(release:) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventTouchCancel|UIControlEventTouchDragExit];[self.movement addSubview:b];[arrows addObject:b];}self.directions=arrows;
 UIButton *b=[self button:@"B" input:RETRO_DEVICE_ID_JOYPAD_B parent:self.actions],*a=[self button:@"A" input:RETRO_DEVICE_ID_JOYPAD_A parent:self.actions];a.backgroundColor=Lime();[a setTitleColor:UIColor.blackColor forState:UIControlStateNormal];UIButton *select=[self button:@"SELECT" input:RETRO_DEVICE_ID_JOYPAD_SELECT parent:self.actions],*start=[self button:@"START" input:RETRO_DEVICE_ID_JOYPAD_START parent:self.actions];self.actionButtons=@[b,a,select,start];
 NSArray *titles=@[@"إيقاف مؤقت",@"حفظ",@"استعادة",@"كتم الصوت",@"الإعدادات",@"الرئيسية",@"ملء الشاشة",@"بدء اللعب"],*symbols=@[@"pause.fill",@"square.and.arrow.down",@"arrow.counterclockwise",@"speaker.wave.2.fill",@"gearshape",@"house",@"arrow.up.left.and.arrow.down.right",@"play.rectangle"];NSMutableArray *tools=[NSMutableArray new];
 for(int i=0;i<8;i++){UIButton *t=[UIButton buttonWithType:UIButtonTypeSystem];UIButtonConfiguration *c=[UIButtonConfiguration plainButtonConfiguration];c.title=titles[i];c.image=[UIImage systemImageNamed:symbols[i]];c.imagePlacement=NSDirectionalRectEdgeTop;c.imagePadding=6;c.baseForegroundColor=UIColor.whiteColor;c.background.backgroundColor=[UIColor colorWithWhite:1 alpha:0.035];c.background.cornerRadius=12;c.background.strokeWidth=1;c.background.strokeColor=[UIColor colorWithWhite:1 alpha:0.1];c.titleTextAttributesTransformer=^NSDictionary *(NSDictionary *x){NSMutableDictionary *r=[x mutableCopy];r[NSFontAttributeName]=[UIFont systemFontOfSize:13 weight:UIFontWeightMedium];return r;};t.configuration=c;t.tag=i;[t addTarget:self action:@selector(tool:) forControlEvents:UIControlEventTouchUpInside];[self.toolbar addSubview:t];[tools addObject:t];}self.tools=tools;
 self.playOverlay=[UIButton buttonWithType:UIButtonTypeSystem];[self.playOverlay setTitle:@"العب الآن" forState:UIControlStateNormal];[self.playOverlay setTitleColor:UIColor.blackColor forState:UIControlStateNormal];self.playOverlay.backgroundColor=Lime();self.playOverlay.titleLabel.font=[UIFont boldSystemFontOfSize:24];self.playOverlay.layer.cornerRadius=16;[self.playOverlay addTarget:self action:@selector(play) forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:self.playOverlay];
 self.notice=[UILabel new];self.notice.textAlignment=NSTextAlignmentCenter;self.notice.textColor=Lime();self.notice.font=[UIFont systemFontOfSize:14];self.notice.numberOfLines=2;self.notice.hidden=YES;self.notice.backgroundColor=[Surface() colorWithAlphaComponent:0.95];self.notice.layer.cornerRadius=10;self.notice.clipsToBounds=YES;[self.view addSubview:self.notice];
 self.prefs=[[NSUserDefaults.standardUserDefaults dictionaryForKey:@"native.settings"] mutableCopy]?:[NSMutableDictionary new];
 NSDictionary *defaults=@{@"volume":@50,@"quality":@"sharp",@"scanlines":@NO,@"rotation":@"0",@"fps":@NO,@"performance":@"stable",@"fast":@NO,@"slow":@NO,@"ffratio":@"3",@"smratio":@"3",@"rewind":@NO,@"autorun":@YES,@"input":@"touch",@"slot":@"1",@"autosave":@"0",@"saveLocation":@"app",@"shotFormat":@"png",@"shotScale":@"1",@"shotSource":@"game",@"deadzone":@"0.35",@"controlSize":@"1",@"showTouch":@YES,@"swapAB":@NO};
 for(NSString *key in defaults)if(!self.prefs[key])self.prefs[key]=defaults[key];self.store=[SaveStore new];self.cheats=[[NSUserDefaults.standardUserDefaults arrayForKey:@"native.cheats"] mutableCopy]?:[NSMutableArray new];
 self.fpsLabel=[UILabel new];self.fpsLabel.font=[UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightMedium];self.fpsLabel.textColor=Lime();self.fpsLabel.backgroundColor=[UIColor colorWithWhite:0 alpha:0.7];self.fpsLabel.numberOfLines=2;[self.view addSubview:self.fpsLabel];
 self.brandLogo=[[UIImageView alloc]initWithImage:[UIImage imageNamed:@"v61d-logo.png"]];self.brandLogo.contentMode=UIViewContentModeScaleAspectFit;[self.view addSubview:self.brandLogo];self.brandLabel=[UILabel new];self.brandLabel.text=@"SUPER MARIO.\nTHE ORIGINAL · 1985";self.brandLabel.textColor=UIColor.whiteColor;self.brandLabel.numberOfLines=2;self.brandLabel.font=[UIFont boldSystemFontOfSize:22];self.brandLabel.textAlignment=NSTextAlignmentCenter;[self.view addSubview:self.brandLabel];
 self.inputPicker=[[UISegmentedControl alloc]initWithItems:@[@"لمس",@"يد تحكم",@"كيبورد"]];self.inputPicker.selectedSegmentIndex=[@[@"touch",@"controller",@"keyboard"] indexOfObject:self.prefs[@"input"]];[self.inputPicker addTarget:self action:@selector(inputChanged) forControlEvents:UIControlEventValueChanged];[self.view addSubview:self.inputPicker];
 self.newButton=[UIButton buttonWithType:UIButtonTypeSystem];[self.newButton setTitle:@"بدء جديد" forState:UIControlStateNormal];[self.newButton setTitleColor:Lime() forState:UIControlStateNormal];[self.newButton addTarget:self action:@selector(startNew) forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:self.newButton];
 self.fullscreenExit=[UIButton buttonWithType:UIButtonTypeSystem];[self.fullscreenExit setImage:[UIImage systemImageNamed:@"arrow.down.right.and.arrow.up.left"] forState:UIControlStateNormal];self.fullscreenExit.tintColor=Lime();self.fullscreenExit.backgroundColor=[UIColor colorWithWhite:0 alpha:0.65];self.fullscreenExit.hidden=YES;self.fullscreenExit.accessibilityLabel=@"إغلاق ملء الشاشة";[self.fullscreenExit addTarget:self action:@selector(toggleFullscreen) forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:self.fullscreenExit];
 self.rewindButton=[UIButton buttonWithType:UIButtonTypeSystem];[self.rewindButton setImage:[UIImage systemImageNamed:@"backward.fill"] forState:UIControlStateNormal];self.rewindButton.backgroundColor=[UIColor colorWithWhite:0 alpha:0.7];self.rewindButton.tintColor=Lime();self.rewindButton.accessibilityLabel=@"اضغط مطولًا للإرجاع";[self.rewindButton addTarget:self action:@selector(beginRewind) forControlEvents:UIControlEventTouchDown];[self.rewindButton addTarget:self action:@selector(endRewind) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventTouchCancel];[self.view addSubview:self.rewindButton];
 self.engine=[NativeEngine new];__weak GameController *weakSelf=self;self.engine.videoFrame=^(CGImageRef image){[weakSelf.screen showFrame:image];};NSError *error;
 if(![self.engine loadROM:[NSBundle.mainBundle pathForResource:@"mario" ofType:@"nes"] error:&error]){self.playOverlay.enabled=NO;[self showNotice:error.localizedDescription];}
 NSData *saved=[NSData dataWithContentsOfFile:[[self savesDirectory] stringByAppendingPathComponent:@"latest.state"]];if(saved&&[self.engine restoreState:saved])[self showNotice:@"آخر حفظ جاهز — اضغط متابعة"];
 [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(connectControllers) name:GCControllerDidConnectNotification object:nil];[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(connectControllers) name:GCControllerDidDisconnectNotification object:nil];[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(pauseAndSave) name:AVAudioSessionInterruptionNotification object:nil];[self connectControllers];[self applyPreferences];[self.engine setCheats:self.cheats];
 self.statusTimer=[NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(statusTick) userInfo:nil repeats:YES];
 [self showHome];[self becomeFirstResponder];
 if([NSProcessInfo.processInfo.arguments containsObject:@"--ui-smoke"])[self performSelector:@selector(uiSmoke) withObject:nil afterDelay:2];
}
- (BOOL)prefersStatusBarHidden{return YES;}
- (BOOL)prefersHomeIndicatorAutoHidden{return YES;}
- (UIRectEdge)preferredScreenEdgesDeferringSystemGestures{return UIRectEdgeAll;}
- (void)viewDidLayoutSubviews{
 [super viewDidLayoutSubviews];UIEdgeInsets safe=self.view.safeAreaInsets;CGFloat w=self.view.bounds.size.width-safe.left-safe.right,h=self.view.bounds.size.height-safe.top-safe.bottom,left=safe.left,top=safe.top;BOOL landscape=w>h;CGFloat toolbarHeight=self.fullscreen?0:(landscape?64:148);self.toolbar.frame=CGRectMake(left,top+h-toolbarHeight,w,toolbarHeight);
 if(landscape){CGFloat side=MIN(210,MAX(126,w*0.2));self.screen.frame=CGRectMake(left+side,top,w-side*2,h-toolbarHeight);self.movement.frame=CGRectMake(left,top,side,h-toolbarHeight);self.actions.frame=CGRectMake(left+w-side,top,side,h-toolbarHeight);}else{CGFloat sh=MIN(w*15/16,MAX(120,h-toolbarHeight-190));self.screen.frame=CGRectMake(left,top,w,sh);self.movement.frame=CGRectMake(left,top+sh,w*0.5,h-sh-toolbarHeight);self.actions.frame=CGRectMake(left+w*0.5,top+sh,w*0.5,h-sh-toolbarHeight);}
 CGFloat mw=self.movement.bounds.size.width,mh=self.movement.bounds.size.height,d=MIN(MIN(mw-16,mh-16),220*[self.prefs[@"controlSize"] doubleValue]),cell=(d-8)/3,cx=(mw-d)/2,cy=(mh-d)/2;NSArray *positions=@[[NSValue valueWithCGPoint:CGPointMake(1,0)],[NSValue valueWithCGPoint:CGPointMake(0,1)],[NSValue valueWithCGPoint:CGPointMake(2,1)],[NSValue valueWithCGPoint:CGPointMake(1,2)]];for(int i=0;i<4;i++){CGPoint p=[positions[i] CGPointValue];self.directions[i].frame=CGRectMake(cx+p.x*(cell+4),cy+p.y*(cell+4),cell,cell);}
 CGFloat aw=self.actions.bounds.size.width,ah=self.actions.bounds.size.height,circle=MIN(110*[self.prefs[@"controlSize"] doubleValue],MIN((aw-24)/2,ah-78)),gap=10,ox=(aw-circle*2-gap)/2,oy=(ah-circle-66)/2;self.actionButtons[0].frame=CGRectMake(ox,oy+8,circle,circle);self.actionButtons[1].frame=CGRectMake(ox+circle+gap,oy,circle,circle);for(int i=0;i<2;i++){self.actionButtons[i].layer.cornerRadius=circle/2;self.actionButtons[i].titleLabel.font=[UIFont boldSystemFontOfSize:circle*0.45];}self.actionButtons[2].frame=CGRectMake(8,oy+circle+22,(aw-22)/2,44);self.actionButtons[3].frame=CGRectMake(14+(aw-22)/2,oy+circle+22,(aw-22)/2,44);self.actionButtons[2].titleLabel.font=self.actionButtons[3].titleLabel.font=[UIFont boldSystemFontOfSize:13];
 int columns=landscape?8:4;CGFloat tw=(w-12-(columns-1)*6)/columns;for(int i=0;i<8;i++)self.tools[i].frame=CGRectMake(6+(columns-1-i%columns)*(tw+6),6+(i/columns)*68,tw,62);self.playOverlay.frame=CGRectMake(CGRectGetMidX(self.screen.frame)-110,CGRectGetMidY(self.screen.frame)+20,220,60);
 self.brandLogo.frame=CGRectMake(CGRectGetMidX(self.screen.frame)-60,CGRectGetMidY(self.screen.frame)-145,120,60);self.brandLabel.frame=CGRectMake(self.screen.frame.origin.x,CGRectGetMidY(self.screen.frame)-85,self.screen.frame.size.width,66);self.inputPicker.frame=CGRectMake(CGRectGetMidX(self.screen.frame)-140,CGRectGetMidY(self.screen.frame)-10,280,32);self.newButton.frame=CGRectMake(CGRectGetMidX(self.screen.frame)-70,CGRectGetMidY(self.screen.frame)+84,140,40);self.fullscreenExit.frame=CGRectMake(left+8,top+8,40,40);self.fpsLabel.frame=CGRectMake(left+(self.fullscreen?54:8),top+6,245,38);self.rewindButton.frame=CGRectMake(left+w-58,top+8,48,40);self.toolbar.hidden=self.fullscreen;self.notice.frame=CGRectMake(left+12,CGRectGetMinY(self.toolbar.frame)-48,w-24,42);
}
- (void)press:(UIButton *)b{[self.engine setButton:[self mappedTouch:(unsigned)b.tag] pressed:YES];b.alpha=0.6;}
- (void)release:(UIButton *)b{[self.engine setButton:[self mappedTouch:(unsigned)b.tag] pressed:NO];b.alpha=1;}
- (void)play{if(!self.brandLogo.hidden){NSData *latest=[self.store state:@"latest.state"];if(latest)[self.engine restoreState:latest];}self.screen.pixels.opacity=1;self.lastAutoSave=NSDate.date.timeIntervalSince1970;self.brandLogo.hidden=self.brandLabel.hidden=self.inputPicker.hidden=self.newButton.hidden=YES;self.engine.paused=NO;self.playOverlay.hidden=YES;[self updatePause];}
- (void)updatePause{UIButtonConfiguration *c=self.tools[0].configuration;c.title=self.engine.paused?@"متابعة":@"إيقاف مؤقت";c.image=[UIImage systemImageNamed:self.engine.paused?@"play.fill":@"pause.fill"];self.tools[0].configuration=c;self.playOverlay.hidden=!self.engine.paused;if(self.engine.paused){[self.playOverlay setTitle:@"متابعة اللعب" forState:UIControlStateNormal];for(UIButton *b in self.directions)b.alpha=1;for(UIButton *b in self.actionButtons)b.alpha=1;}}
- (void)showNotice:(NSString *)text{self.notice.text=text;self.notice.hidden=NO;[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideNotice) object:nil];[self performSelector:@selector(hideNotice) withObject:nil afterDelay:3];}
- (void)hideNotice{self.notice.hidden=YES;}
- (NSString *)savesDirectory{return self.store.directory;}
- (BOOL)saveSnapshot:(BOOL)snapshot{return [self.store save:[self.engine saveState] image:self.engine.lastFrame slot:[self.prefs[@"slot"] integerValue] snapshot:snapshot];}
- (void)pauseAndSave{if(!self.engine)return;[self saveSnapshot:NO];self.engine.paused=YES;[self updatePause];}
- (void)tool:(UIButton *)b{
 switch(b.tag){case 0:self.engine.paused=!self.engine.paused;[self updatePause];break;
 case 1:if([self saveSnapshot:YES]){[self showNotice:@"تم حفظ تقدمك"];if([self.prefs[@"saveLocation"] isEqual:@"files"])[self share:@[[self.store exportRecord:@"latest.state"]]];}else [self showNotice:@"تعذّر الحفظ"];break;
 case 2:[self showSaves];break;case 3: self.prefs[@"muted"]=@(![self.prefs[@"muted"] boolValue]);[self applyPreferences];break;
 case 4:[self showSettings];break;case 5:[self pauseAndSave];[self showHome];break;case 6:[self toggleFullscreen];break;
 case 7:[self.engine setButton:RETRO_DEVICE_ID_JOYPAD_START pressed:YES source:2];dispatch_after(dispatch_time(DISPATCH_TIME_NOW,80*NSEC_PER_MSEC),dispatch_get_main_queue(),^{[self.engine setButton:RETRO_DEVICE_ID_JOYPAD_START pressed:NO source:2];});break;}
}
- (void)connectControllers{
 self.controller.extendedGamepad.valueChangedHandler=nil;[self.engine releaseInputs];self.controllerBDown=NO;self.controller=GCController.controllers.firstObject;self.controller.handlerQueue=dispatch_get_main_queue();__weak GameController *weakSelf=self;
 self.controller.extendedGamepad.valueChangedHandler=^(GCExtendedGamepad *p,GCControllerElement *e){[weakSelf updateController:p];};
}
#include "NativePanels.inc"

@end
@interface AppDelegate:UIResponder<UIApplicationDelegate>
@property(nonatomic,strong)UIWindow *window;
@property(nonatomic,strong)GameController *game;
@end
@implementation AppDelegate
- (BOOL)application:(UIApplication *)a didFinishLaunchingWithOptions:(NSDictionary *)o{self.window=[[UIWindow alloc]initWithFrame:UIScreen.mainScreen.bounds];self.game=[GameController new];self.window.rootViewController=self.game;[self.window makeKeyAndVisible];return YES;}
- (void)applicationDidBecomeActive:(UIApplication *)a{a.idleTimerDisabled=YES;}
- (void)applicationWillResignActive:(UIApplication *)a{a.idleTimerDisabled=NO;[self.game pauseAndSave];}
@end
int main(int argc,char *argv[]){@autoreleasepool{return UIApplicationMain(argc,argv,nil,NSStringFromClass(AppDelegate.class));}}
