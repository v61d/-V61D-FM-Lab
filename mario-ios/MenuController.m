// SPDX-License-Identifier: GPL-2.0-or-later
#import "MenuController.h"
@implementation MenuController
+ (NSDictionary *)choice:(NSString *)key label:(NSString *)label values:(NSArray *)values{return @{@"key":key,@"label":label,@"type":@"choice",@"options":values};}
+ (NSDictionary *)toggle:(NSString *)key label:(NSString *)label{return @{@"key":key,@"label":label,@"type":@"toggle"};}
+ (NSDictionary *)action:(NSString *)key label:(NSString *)label detail:(NSString *)detail{return @{@"key":key,@"label":label,@"type":@"action",@"detail":detail?:@""};}
- (instancetype)init{if((self=[super initWithStyle:UITableViewStyleInsetGrouped]))self.values=[NSMutableDictionary new];return self;}
- (void)viewDidLoad{[super viewDidLoad];self.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;self.view.tintColor=[UIColor colorWithRed:0.8 green:1 blue:0.37 alpha:1];self.tableView.backgroundColor=[UIColor colorWithRed:0.055 green:0.065 blue:0.045 alpha:1];self.navigationItem.rightBarButtonItem=[[UIBarButtonItem alloc]initWithTitle:@"تم" style:UIBarButtonItemStyleDone target:self action:@selector(done)];self.tableView.rowHeight=76;self.tableView.accessibilityIdentifier=@"settings.table";}
- (void)done{[self.navigationController dismissViewControllerAnimated:YES completion:self.closed];}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)t{return self.groups.count;}
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s{return [self.groups[s][@"rows"] count];}
- (NSString *)tableView:(UITableView *)t titleForHeaderInSection:(NSInteger)s{return self.groups[s][@"title"];}
- (NSString *)tableView:(UITableView *)t titleForFooterInSection:(NSInteger)s{return self.groups[s][@"note"];}
- (NSDictionary *)row:(NSIndexPath *)path{return self.groups[path.section][@"rows"][path.row];}
- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)p{
 NSDictionary *r=[self row:p];UITableViewCell *c=[[UITableViewCell alloc]initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:nil];c.textLabel.text=r[@"label"];c.textLabel.font=[UIFont systemFontOfSize:16 weight:UIFontWeightMedium];c.textLabel.numberOfLines=2;c.detailTextLabel.numberOfLines=2;c.detailTextLabel.textColor=[UIColor colorWithWhite:0.65 alpha:1];c.backgroundColor=[UIColor colorWithWhite:0.09 alpha:1];c.accessibilityIdentifier=r[@"key"];if(r[@"image"])c.imageView.image=[UIImage imageWithContentsOfFile:r[@"image"]];NSString *type=r[@"type"],*key=r[@"key"];id value=self.values[key];
 if([type isEqual:@"toggle"]){UISwitch *s=[UISwitch new];s.on=[value boolValue];s.accessibilityIdentifier=key;s.tag=p.section*1000+p.row;s.onTintColor=self.view.tintColor;[s addTarget:self action:@selector(toggled:) forControlEvents:UIControlEventValueChanged];c.accessoryView=s;}
 else if([type isEqual:@"slider"]){UISlider *s=[[UISlider alloc]initWithFrame:CGRectMake(0,0,140,40)];s.minimumValue=0;s.maximumValue=100;s.value=[value floatValue];s.tag=p.section*1000+p.row;[s addTarget:self action:@selector(slid:) forControlEvents:UIControlEventValueChanged];c.accessoryView=s;c.detailTextLabel.text=[NSString stringWithFormat:@"%.0f%%",[value doubleValue]];}
 else if([type isEqual:@"choice"]){for(NSDictionary *v in r[@"options"])if([v[@"value"] isEqual:value])c.detailTextLabel.text=v[@"label"];c.accessoryType=UITableViewCellAccessoryDisclosureIndicator;}
 else{c.detailTextLabel.text=r[@"detail"];c.accessoryType=UITableViewCellAccessoryDisclosureIndicator;}
 return c;
}
- (void)write:(id)value row:(NSDictionary *)r{self.values[r[@"key"]]=value;if(self.changed)self.changed(r[@"key"],value);}
- (void)toggled:(UISwitch *)s{[self write:@(s.on) row:[self row:[NSIndexPath indexPathForRow:s.tag%1000 inSection:s.tag/1000]]];}
- (void)slid:(UISlider *)s{NSIndexPath *p=[NSIndexPath indexPathForRow:s.tag%1000 inSection:s.tag/1000];[self write:@(round(s.value)) row:[self row:p]];[self.tableView cellForRowAtIndexPath:p].detailTextLabel.text=[NSString stringWithFormat:@"%.0f%%",round(s.value)];}
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)p{
 [t deselectRowAtIndexPath:p animated:YES];NSDictionary *r=[self row:p];if([r[@"type"] isEqual:@"action"]){if(self.action)self.action(r[@"key"]);return;}
 if(![r[@"type"] isEqual:@"choice"])return;
 UIAlertController *a=[UIAlertController alertControllerWithTitle:r[@"label"] message:r[@"info"] preferredStyle:UIAlertControllerStyleActionSheet];
 for(NSDictionary *v in r[@"options"]){BOOL selected=[v[@"value"] isEqual:self.values[r[@"key"]]];NSString *label=selected?[v[@"label"] stringByAppendingString:@" ✓"]:v[@"label"];[a addAction:[UIAlertAction actionWithTitle:label style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){[self write:v[@"value"] row:r];[self.tableView reloadData];}]];}
 [a addAction:[UIAlertAction actionWithTitle:@"إلغاء" style:UIAlertActionStyleCancel handler:nil]];a.popoverPresentationController.sourceView=[t cellForRowAtIndexPath:p];a.popoverPresentationController.sourceRect=[t cellForRowAtIndexPath:p].bounds;[self presentViewController:a animated:YES completion:nil];
}
@end
