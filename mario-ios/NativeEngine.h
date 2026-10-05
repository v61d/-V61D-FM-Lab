// SPDX-License-Identifier: GPL-2.0-or-later
#import <UIKit/UIKit.h>
@interface NativeEngine : NSObject
@property(nonatomic,copy) void (^videoFrame)(CGImageRef image);
@property(nonatomic) BOOL paused;
@property(nonatomic) BOOL autoRun;
@property(nonatomic) float volume;
@property(nonatomic,readonly) double frameRate;
- (BOOL)loadROM:(NSString *)path error:(NSError **)error;
- (void)setButton:(unsigned)button pressed:(BOOL)pressed;
- (NSData *)saveState;
- (BOOL)restoreState:(NSData *)data;
- (void)reset;
@end
