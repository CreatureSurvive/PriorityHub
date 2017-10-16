@interface BBAction : NSObject
+ (id)actionWithLaunchURL:(NSURL *)url;
@end

@interface BBServer : NSObject
- (void)publishBulletin:(id)arg1 destinations:(unsigned long long)arg2 alwaysToLockScreen:(bool)arg3;
- (void)publishBulletinRequest:(id)arg1 destinations:(unsigned long long)arg2 alwaysToLockScreen:(bool)arg3;
@end

@interface BBBulletin
@property(copy, nonatomic) NSString *sectionID; // @dynamic sectionID;
@property(copy, nonatomic) NSString *title; // @dynamic title;
@property(copy, nonatomic) NSString *message; // @dynamic title;
@property(copy, nonatomic) id defaultAction; // @dynamic defaultAction;
@property(retain, nonatomic) NSDate *date;
@property(copy, nonatomic) NSString *bulletinID;
@property(copy, nonatomic) NSString *publisherBulletinID;
@property(retain, nonatomic) NSDate *publicationDate;
@property(retain, nonatomic) NSDate *lastInterruptDate;
@property(nonatomic) BOOL showsMessagePreview;
@property(nonatomic) BOOL clearable;
@property(retain, nonatomic) NSString *subtitle;
@property(retain, nonatomic) NSString *recordID;
@end

@interface BBBulletinRequest : BBBulletin
@end

@interface SBLockScreenManager : NSObject
+ (id)sharedInstance;
- (void)lockUIFromSource:(int)source withOptions:(id)options;
@end

@interface SBNotificationCenterController : NSObject
- (BOOL)isVisible;
- (void)presentAnimated:(BOOL)arg1 completion:(id)arg2;
- (void)presentAnimated:(BOOL)arg1;
@end
