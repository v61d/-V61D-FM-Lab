// SPDX-License-Identifier: GPL-2.0-or-later
#import <UIKit/UIKit.h>
@interface MenuController : UITableViewController
@property(nonatomic,strong) NSArray<NSDictionary *> *groups;
@property(nonatomic,strong) NSMutableDictionary *values;
@property(nonatomic,copy) void (^changed)(NSString *,id);
@property(nonatomic,copy) void (^action)(NSString *);
@property(nonatomic,copy) void (^closed)(void);
+ (NSDictionary *)choice:(NSString *)key label:(NSString *)label values:(NSArray *)values;
+ (NSDictionary *)toggle:(NSString *)key label:(NSString *)label;
+ (NSDictionary *)action:(NSString *)key label:(NSString *)label detail:(NSString *)detail;
@end
