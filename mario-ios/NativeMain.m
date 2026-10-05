// SPDX-License-Identifier: GPL-2.0-or-later
#import <UIKit/UIKit.h>
#import <GameController/GameController.h>
#import <AVFoundation/AVFoundation.h>
#import "NativeEngine.h"
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
- (void)showFrame:(CGImageRef)image;
@end
@implementation GameScreen
- (instancetype)init{if((self=[super init])){self.backgroundColor=UIColor.blackColor;self.pixels=[CALayer layer];self.pixels.magnificationFilter=kCAFilterNearest;self.pixels.minificationFilter=kCAFilterNearest;[self.layer addSublayer:self.pixels];}return self;}
- (void)layoutSubviews{[super layoutSubviews];CGFloat w=self.bounds.size.width,h=self.bounds.size.height;CGFloat width=MIN(w,h*256/240),height=width*240/256;[CATransaction begin];[CATransaction setDisableActions:YES];self.pixels.frame=CGRectMake((w-width)/2,(h-height)/2,width,height);[CATransaction commit];}
- (void)showFrame:(CGImageRef)image{[CATransaction begin];[CATransaction setDisableActions:YES];self.pixels.contents=(__bridge id)image;[CATransaction commit];}
@end
@interface GameController:UIViewController
@property(nonatomic,strong)NativeEngine *engine;
@property(nonatomic,strong)GameScreen *screen;
@property(nonatomic,strong)UIView *movement,*actions,*toolbar;
@property(nonatomic,strong)NSArray<UIButton *> *directions,*actionButtons,*tools;
@property(nonatomic,strong)UIButton *playOverlay;
@property(nonatomic,strong)UILabel *notice;
@property(nonatomic,strong)GCController *controller;
@property(nonatomic)BOOL controllerBDown;
- (void)pauseAndSave;
@end
@implementation GameController
- (UIButton *)button:(NSString *)title input:(NSInteger)input parent:(UIView *)parent{UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];[b setTitle:title forState:UIControlStateNormal];[b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];b.titleLabel.font=[UIFont boldSystemFontOfSize:28];b.backgroundColor=[UIColor colorWithRed:0.17 green:0.19 blue:0.145 alpha:1];b.layer.cornerRadius=14;b.layer.borderWidth=1;b.layer.borderColor=[UIColor colorWithWhite:1 alpha:0.12].CGColor;b.tag=input;b.exclusiveTouch=NO;[b addTarget:self action:@selector(press:) forControlEvents:UIControlEventTouchDown|UIControlEventTouchDragEnter];[b addTarget:self action:@selector(release:) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventTouchCancel|UIControlEventTouchDragExit];[parent addSubview:b];return b;}
- (void)viewDidLoad{
 [super viewDidLoad];self.view.backgroundColor=Surface();self.screen=[GameScreen new];[self.view addSubview:self.screen];self.movement=[UIView new];self.actions=[UIView new];self.toolbar=[UIView new];for(UIView *v in @[self.movement,self.actions,self.toolbar])[self.view addSubview:v];
 NSMutableArray *arrows=[NSMutableArray new];NSArray *ids=@[@(RETRO_DEVICE_ID_JOYPAD_UP),@(RETRO_DEVICE_ID_JOYPAD_LEFT),@(RETRO_DEVICE_ID_JOYPAD_RIGHT),@(RETRO_DEVICE_ID_JOYPAD_DOWN)],*angles=@[@0,@(-M_PI_2),@(M_PI_2),@(M_PI)],*labels=@[@"أعلى",@"يسار",@"يمين",@"أسفل"];
 for(int i=0;i<4;i++){ArrowButton *b=[ArrowButton new];b.angle=[angles[i] doubleValue];b.tag=[ids[i] integerValue];b.accessibilityLabel=labels[i];b.backgroundColor=[UIColor colorWithRed:0.17 green:0.19 blue:0.145 alpha:1];b.layer.cornerRadius=14;b.layer.borderWidth=1;b.layer.borderColor=[UIColor colorWithWhite:1 alpha:0.12].CGColor;[b addTarget:self action:@selector(press:) forControlEvents:UIControlEventTouchDown|UIControlEventTouchDragEnter];[b addTarget:self action:@selector(release:) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventTouchCancel|UIControlEventTouchDragExit];[self.movement addSubview:b];[arrows addObject:b];}self.directions=arrows;
 UIButton *b=[self button:@"B" input:RETRO_DEVICE_ID_JOYPAD_B parent:self.actions],*a=[self button:@"A" input:RETRO_DEVICE_ID_JOYPAD_A parent:self.actions];a.backgroundColor=Lime();[a setTitleColor:UIColor.blackColor forState:UIControlStateNormal];UIButton *select=[self button:@"SELECT" input:RETRO_DEVICE_ID_JOYPAD_SELECT parent:self.actions],*start=[self button:@"START" input:RETRO_DEVICE_ID_JOYPAD_START parent:self.actions];self.actionButtons=@[b,a,select,start];
 NSArray *titles=@[@"إيقاف مؤقت",@"حفظ",@"استعادة",@"كتم الصوت",@"الإعدادات",@"الرئيسية"],*symbols=@[@"pause.fill",@"square.and.arrow.down",@"arrow.counterclockwise",@"speaker.wave.2.fill",@"gearshape",@"house"];NSMutableArray *tools=[NSMutableArray new];
 for(int i=0;i<6;i++){UIButton *t=[UIButton buttonWithType:UIButtonTypeSystem];UIButtonConfiguration *c=[UIButtonConfiguration plainButtonConfiguration];c.title=titles[i];c.image=[UIImage systemImageNamed:symbols[i]];c.imagePlacement=NSDirectionalRectEdgeTop;c.imagePadding=6;c.baseForegroundColor=UIColor.whiteColor;c.background.backgroundColor=[UIColor colorWithWhite:1 alpha:0.035];c.background.cornerRadius=12;c.background.strokeWidth=1;c.background.strokeColor=[UIColor colorWithWhite:1 alpha:0.1];c.titleTextAttributesTransformer=^NSDictionary *(NSDictionary *x){NSMutableDictionary *r=[x mutableCopy];r[NSFontAttributeName]=[UIFont systemFontOfSize:13 weight:UIFontWeightMedium];return r;};t.configuration=c;t.tag=i;[t addTarget:self action:@selector(tool:) forControlEvents:UIControlEventTouchUpInside];[self.toolbar addSubview:t];[tools addObject:t];}self.tools=tools;
 self.playOverlay=[UIButton buttonWithType:UIButtonTypeSystem];[self.playOverlay setTitle:@"العب الآن" forState:UIControlStateNormal];[self.playOverlay setTitleColor:UIColor.blackColor forState:UIControlStateNormal];self.playOverlay.backgroundColor=Lime();self.playOverlay.titleLabel.font=[UIFont boldSystemFontOfSize:24];self.playOverlay.layer.cornerRadius=16;[self.playOverlay addTarget:self action:@selector(play) forControlEvents:UIControlEventTouchUpInside];[self.view addSubview:self.playOverlay];
 self.notice=[UILabel new];self.notice.textAlignment=NSTextAlignmentCenter;self.notice.textColor=Lime();self.notice.font=[UIFont systemFontOfSize:14];self.notice.numberOfLines=2;self.notice.hidden=YES;self.notice.backgroundColor=[Surface() colorWithAlphaComponent:0.95];self.notice.layer.cornerRadius=10;self.notice.clipsToBounds=YES;[self.view addSubview:self.notice];
 self.engine=[NativeEngine new];__weak GameController *weakSelf=self;self.engine.videoFrame=^(CGImageRef image){[weakSelf.screen showFrame:image];};NSError *error;
 if(![self.engine loadROM:[NSBundle.mainBundle pathForResource:@"mario" ofType:@"nes"] error:&error]){self.playOverlay.enabled=NO;[self showNotice:error.localizedDescription];}
 NSData *saved=[NSData dataWithContentsOfFile:[[self savesDirectory] stringByAppendingPathComponent:@"latest.state"]];if(saved&&[self.engine restoreState:saved])[self showNotice:@"آخر حفظ جاهز — اضغط متابعة"];
 [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(connectControllers) name:GCControllerDidConnectNotification object:nil];[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(connectControllers) name:GCControllerDidDisconnectNotification object:nil];[NSNotificationCenter.defaultCenter addObserver:self selector:@selector(pauseAndSave) name:AVAudioSessionInterruptionNotification object:nil];[self connectControllers];
}
- (BOOL)prefersStatusBarHidden{return YES;}
- (BOOL)prefersHomeIndicatorAutoHidden{return YES;}
- (UIRectEdge)preferredScreenEdgesDeferringSystemGestures{return UIRectEdgeAll;}
- (void)viewDidLayoutSubviews{
 [super viewDidLayoutSubviews];UIEdgeInsets safe=self.view.safeAreaInsets;CGFloat w=self.view.bounds.size.width-safe.left-safe.right,h=self.view.bounds.size.height-safe.top-safe.bottom,left=safe.left,top=safe.top;BOOL landscape=w>h;CGFloat toolbarHeight=landscape?64:132;self.toolbar.frame=CGRectMake(left,top+h-toolbarHeight,w,toolbarHeight);
 if(landscape){CGFloat side=MIN(210,MAX(126,w*0.2));self.screen.frame=CGRectMake(left+side,top,w-side*2,h-toolbarHeight);self.movement.frame=CGRectMake(left,top,side,h-toolbarHeight);self.actions.frame=CGRectMake(left+w-side,top,side,h-toolbarHeight);}else{CGFloat sh=MIN(w*15/16,MAX(120,h-toolbarHeight-190));self.screen.frame=CGRectMake(left,top,w,sh);self.movement.frame=CGRectMake(left,top+sh,w*0.5,h-sh-toolbarHeight);self.actions.frame=CGRectMake(left+w*0.5,top+sh,w*0.5,h-sh-toolbarHeight);}
 CGFloat mw=self.movement.bounds.size.width,mh=self.movement.bounds.size.height,d=MIN(MIN(mw-16,mh-16),220),cell=(d-8)/3,cx=(mw-d)/2,cy=(mh-d)/2;NSArray *positions=@[[NSValue valueWithCGPoint:CGPointMake(1,0)],[NSValue valueWithCGPoint:CGPointMake(0,1)],[NSValue valueWithCGPoint:CGPointMake(2,1)],[NSValue valueWithCGPoint:CGPointMake(1,2)]];for(int i=0;i<4;i++){CGPoint p=[positions[i] CGPointValue];self.directions[i].frame=CGRectMake(cx+p.x*(cell+4),cy+p.y*(cell+4),cell,cell);}
 CGFloat aw=self.actions.bounds.size.width,ah=self.actions.bounds.size.height,circle=MIN(100,MIN((aw-24)/2,ah-78)),gap=10,ox=(aw-circle*2-gap)/2,oy=(ah-circle-66)/2;self.actionButtons[0].frame=CGRectMake(ox,oy+8,circle,circle);self.actionButtons[1].frame=CGRectMake(ox+circle+gap,oy,circle,circle);for(int i=0;i<2;i++){self.actionButtons[i].layer.cornerRadius=circle/2;self.actionButtons[i].titleLabel.font=[UIFont boldSystemFontOfSize:circle*0.45];}self.actionButtons[2].frame=CGRectMake(8,oy+circle+22,(aw-22)/2,44);self.actionButtons[3].frame=CGRectMake(14+(aw-22)/2,oy+circle+22,(aw-22)/2,44);self.actionButtons[2].titleLabel.font=self.actionButtons[3].titleLabel.font=[UIFont boldSystemFontOfSize:13];
 int columns=landscape?6:3;CGFloat tw=(w-12-(columns-1)*6)/columns;for(int i=0;i<6;i++)self.tools[i].frame=CGRectMake(6+(columns-1-i%columns)*(tw+6),6+(i/columns)*62,tw,56);self.playOverlay.frame=CGRectMake(CGRectGetMidX(self.screen.frame)-110,CGRectGetMidY(self.screen.frame)-30,220,60);self.notice.frame=CGRectMake(left+12,CGRectGetMinY(self.toolbar.frame)-48,w-24,42);
}
- (void)press:(UIButton *)b{[self.engine setButton:(unsigned)b.tag pressed:YES];b.alpha=0.6;}
- (void)release:(UIButton *)b{[self.engine setButton:(unsigned)b.tag pressed:NO];b.alpha=1;}
- (void)play{self.engine.paused=NO;self.playOverlay.hidden=YES;[self updatePause];}
- (void)updatePause{UIButtonConfiguration *c=self.tools[0].configuration;c.title=self.engine.paused?@"متابعة":@"إيقاف مؤقت";c.image=[UIImage systemImageNamed:self.engine.paused?@"play.fill":@"pause.fill"];self.tools[0].configuration=c;self.playOverlay.hidden=!self.engine.paused;if(self.engine.paused){[self.playOverlay setTitle:@"متابعة اللعب" forState:UIControlStateNormal];for(UIButton *b in self.directions)b.alpha=1;for(UIButton *b in self.actionButtons)b.alpha=1;}}
- (void)showNotice:(NSString *)text{self.notice.text=text;self.notice.hidden=NO;[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(hideNotice) object:nil];[self performSelector:@selector(hideNotice) withObject:nil afterDelay:3];}
- (void)hideNotice{self.notice.hidden=YES;}
- (NSString *)savesDirectory{NSString *p=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject stringByAppendingPathComponent:@"NativeSaves"];[NSFileManager.defaultManager createDirectoryAtPath:p withIntermediateDirectories:YES attributes:nil error:nil];return p;}
- (BOOL)saveSnapshot:(BOOL)snapshot{NSData *data=[self.engine saveState];if(!data)return NO;NSString *dir=[self savesDirectory];if(![data writeToFile:[dir stringByAppendingPathComponent:@"latest.state"] options:NSDataWritingAtomic error:nil])return NO;if(snapshot){NSString *name=[NSString stringWithFormat:@"%.0f.state",NSDate.date.timeIntervalSince1970*1000];[data writeToFile:[dir stringByAppendingPathComponent:name] options:NSDataWritingAtomic error:nil];NSMutableArray *names=[[NSFileManager.defaultManager contentsOfDirectoryAtPath:dir error:nil] mutableCopy];[names removeObject:@"latest.state"];[names sortUsingSelector:@selector(compare:)];while(names.count>6){[NSFileManager.defaultManager removeItemAtPath:[dir stringByAppendingPathComponent:names.firstObject] error:nil];[names removeObjectAtIndex:0];}}return YES;}
- (void)pauseAndSave{if(!self.engine)return;[self saveSnapshot:NO];self.engine.paused=YES;[self updatePause];}
- (void)restoreMenu{
 BOOL wasPaused=self.engine.paused;self.engine.paused=YES;[self updatePause];UIAlertController *menu=[UIAlertController alertControllerWithTitle:@"استعادة الحفظ" message:@"حفظات المحاكي الأصلي داخل هذا التطبيق" preferredStyle:UIAlertControllerStyleActionSheet];NSString *dir=[self savesDirectory];NSMutableArray *names=[[NSFileManager.defaultManager contentsOfDirectoryAtPath:dir error:nil] mutableCopy];[names removeObject:@"latest.state"];[names sortUsingComparator:^NSComparisonResult(NSString *a,NSString *b){return [b compare:a];}];if([NSFileManager.defaultManager fileExistsAtPath:[dir stringByAppendingPathComponent:@"latest.state"]])[names insertObject:@"latest.state" atIndex:0];NSDateFormatter *f=[NSDateFormatter new];f.locale=[NSLocale localeWithLocaleIdentifier:@"ar_SA"];f.dateStyle=NSDateFormatterMediumStyle;f.timeStyle=NSDateFormatterShortStyle;
 for(NSString *name in names){NSString *title=[name isEqualToString:@"latest.state"]?@"آخر حفظ":[f stringFromDate:[NSDate dateWithTimeIntervalSince1970:name.doubleValue/1000]];[menu addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *a){BOOL ok=[self.engine restoreState:[NSData dataWithContentsOfFile:[dir stringByAppendingPathComponent:name]]];self.engine.paused=wasPaused;[self updatePause];[self showNotice:ok?@"تمت استعادة الحفظ":@"تعذّرت الاستعادة"];}]];}[menu addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:^(UIAlertAction *a){self.engine.paused=wasPaused;[self updatePause];}]];menu.popoverPresentationController.sourceView=self.tools[2];menu.popoverPresentationController.sourceRect=self.tools[2].bounds;[self presentViewController:menu animated:YES completion:nil];
}
- (void)tool:(UIButton *)b{
 switch(b.tag){case 0:self.engine.paused=!self.engine.paused;[self updatePause];break;case 1:[self showNotice:[self saveSnapshot:YES]?@"تم حفظ تقدمك":@"تعذّر الحفظ"];break;case 2:[self restoreMenu];break;
 case 3:self.engine.volume=self.engine.volume>0?0:0.5;{UIButtonConfiguration *c=b.configuration;c.title=self.engine.volume?@"كتم الصوت":@"تشغيل الصوت";c.image=[UIImage systemImageNamed:self.engine.volume?@"speaker.wave.2.fill":@"speaker.slash.fill"];b.configuration=c;}break;
 case 4:{BOOL paused=self.engine.paused;self.engine.paused=YES;[self updatePause];UIAlertController *a=[UIAlertController alertControllerWithTitle:@"إعدادات المحاكي" message:[NSString stringWithFormat:@"NES أصلي · %.2f إطار/ثانية\nيعمل بدون إنترنت",self.engine.frameRate] preferredStyle:UIAlertControllerStyleAlert];[a addAction:[UIAlertAction actionWithTitle:self.engine.autoRun?@"إيقاف الركض التلقائي":@"تشغيل الركض التلقائي" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){self.engine.autoRun=!self.engine.autoRun;self.engine.paused=paused;[self updatePause];}]];[a addAction:[UIAlertAction actionWithTitle:@"تم" style:UIAlertActionStyleCancel handler:^(UIAlertAction *x){self.engine.paused=paused;[self updatePause];}]];[self presentViewController:a animated:YES completion:nil];break;}
 case 5:{BOOL paused=self.engine.paused;[self saveSnapshot:NO];self.engine.paused=YES;[self updatePause];UIAlertController *a=[UIAlertController alertControllerWithTitle:@"العودة للرئيسية" message:@"تم حفظ تقدمك. تبدأ شاشة اللعبة الأصلية من جديد؟" preferredStyle:UIAlertControllerStyleAlert];[a addAction:[UIAlertAction actionWithTitle:@"بدء جديد" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){[self.engine reset];[self play];}]];[a addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:^(UIAlertAction *x){self.engine.paused=paused;[self updatePause];}]];[self presentViewController:a animated:YES completion:nil];break;}}
}
- (void)connectControllers{
 self.controller.extendedGamepad.valueChangedHandler=nil;for(unsigned i=0;i<16;i++)[self.engine setButton:i pressed:NO];self.controllerBDown=NO;self.controller=GCController.controllers.firstObject;__weak GameController *weakSelf=self;self.controller.handlerQueue=dispatch_get_main_queue();
 self.controller.extendedGamepad.valueChangedHandler=^(GCExtendedGamepad *p,GCControllerElement *e){GameController *s=weakSelf;if(!s)return;[s.engine setButton:RETRO_DEVICE_ID_JOYPAD_UP pressed:p.dpad.up.pressed||p.leftThumbstick.yAxis.value>0.35];[s.engine setButton:RETRO_DEVICE_ID_JOYPAD_DOWN pressed:p.dpad.down.pressed||p.leftThumbstick.yAxis.value < -0.35];[s.engine setButton:RETRO_DEVICE_ID_JOYPAD_LEFT pressed:p.dpad.left.pressed||p.leftThumbstick.xAxis.value < -0.35];[s.engine setButton:RETRO_DEVICE_ID_JOYPAD_RIGHT pressed:p.dpad.right.pressed||p.leftThumbstick.xAxis.value>0.35];[s.engine setButton:RETRO_DEVICE_ID_JOYPAD_A pressed:p.buttonA.pressed];if(s.controllerBDown!=p.buttonB.pressed){s.controllerBDown=p.buttonB.pressed;[s.engine setButton:RETRO_DEVICE_ID_JOYPAD_B pressed:p.buttonB.pressed];}[s.engine setButton:RETRO_DEVICE_ID_JOYPAD_START pressed:p.buttonMenu.pressed];[s.engine setButton:RETRO_DEVICE_ID_JOYPAD_SELECT pressed:p.buttonOptions.pressed];};
}
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
