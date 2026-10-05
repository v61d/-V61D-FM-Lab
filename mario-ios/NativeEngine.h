// SPDX-License-Identifier: GPL-2.0-or-later
#import <UIKit/UIKit.h>
@interface NativeEngine : NSObject
@property(nonatomic,copy) void (^videoFrame)(CGImageRef image);
@property(nonatomic) BOOL paused, autoRun, rewindEnabled, rewinding;
@property(nonatomic) float volume;
@property(nonatomic) double speed;
@property(nonatomic) NSInteger performanceMode;
@property(nonatomic,readonly) double frameRate, aspectRatio, renderedFPS, emulatedFPS, frameMilliseconds;
@property(nonatomic,readonly) UIImage *lastFrame;
@property(nonatomic,readonly) NSArray<NSDictionary *> *coreOptions;
- (BOOL)loadROM:(NSString *)path error:(NSError **)error;
- (void)setButton:(unsigned)button pressed:(BOOL)pressed;
- (void)setButton:(unsigned)button pressed:(BOOL)pressed source:(unsigned)source;
- (void)releaseInputs;
- (NSString *)coreValue:(NSString *)key;
- (void)setCoreValue:(NSString *)value key:(NSString *)key;
- (void)resetCoreOptions;
- (NSData *)saveState;
- (BOOL)restoreState:(NSData *)data;
- (void)setCheats:(NSArray<NSDictionary *> *)cheats;
- (void)reset;
@end
