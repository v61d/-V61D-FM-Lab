// SPDX-License-Identifier: GPL-2.0-or-later
#import <UIKit/UIKit.h>
@interface SaveStore:NSObject
@property(nonatomic,readonly)NSString *directory;
- (BOOL)save:(NSData *)state image:(UIImage *)image slot:(NSInteger)slot snapshot:(BOOL)snapshot;
- (NSArray<NSDictionary *> *)records;
- (NSData *)state:(NSString *)name;
- (void)remove:(NSString *)name;
- (NSURL *)exportRecord:(NSString *)name;
- (BOOL)importURL:(NSURL *)url expectedSize:(NSUInteger)size;
@end
