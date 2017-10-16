
@interface SBSearchEtceteraLayoutContentView : UIView
@end

@interface SBSearchEtceteraNotificationsLayoutContentView : SBSearchEtceteraLayoutContentView
@end

@interface NCNotificationListContainerViewController : UIViewController
@end

@interface NCNotificationListCollectionViewFlowLayout : UICollectionViewFlowLayout
@end

@interface NCNotificationListClearButton : UIControl
@end

@interface SBDashBoardPageControl : UIPageControl
@end

@interface SBDashBoardMainPageView : UIView
@property(retain, nonatomic) UILabel *callToActionLabel;
@end

@interface SBDashBoardClippingLine : UIView
@end

@protocol NCNotificationActionRunner <NSObject>
@required
- (void)executeAction:(id)arg1 fromOrigin:(id)arg2 withParameters:(id)arg3 completion:(id)arg4;
@end

@interface NCNotificationAction : NSObject
@property (nonatomic, readonly) id<NCNotificationActionRunner> actionRunner;
@end

@interface NCNotificationSound : NSObject
@end

@interface NCNotificationRequest : NSObject
@property (nonatomic, copy, readonly) NSSet *requestDestinations;
@property (nonatomic, readonly) NCNotificationSound *sound;
@property (nonatomic, readonly) NCNotificationAction *clearAction;
@property (nonatomic, readonly) NCNotificationAction *closeAction;
@property (nonatomic, readonly) NCNotificationAction *defaultAction;
- (NSString *)sectionIdentifier;
@end

@interface NCNotificationListViewController : UICollectionViewController <UICollectionViewDelegateFlowLayout>
- (long long)collectionView:(id)arg1 numberOfItemsInSection:(long long)arg2;
- (long long)numberOfSectionsInCollectionView:(id)arg1;
- (NSString *)notificationIdentifierAtIndex:(NSUInteger)index;
- (NSUInteger)numNotifications;
- (NCNotificationRequest *)notificationRequestAtIndexPath:(NSIndexPath *)path;
- (BOOL)shouldShowNotificationAtIndexPath:(NSIndexPath *)indexPath;
- (void)removeNotification:(NCNotificationRequest *)request;
- (void)insertOrModifyNotification:(NCNotificationRequest *)request;
- (void)setNeedsReloadData:(BOOL)arg1;
- (bool)collectionView:(id)arg1 canMoveItemAtIndexPath:(id)arg2;
- (void)moveItemAtIndexPath:(NSIndexPath *)path toIndexPath:(NSIndexPath *)toPath;
- (void)removeNotificationRequest:(NCNotificationRequest *)request forCoalescedNotification:(id)notification;
- (NSArray *)allIndexPaths;
@end

@interface NCNotificationPriorityList : NSObject {
    NSMutableOrderedSet *_requests;
}
@property (nonatomic, retain) NSMutableOrderedSet *requests;
- (unsigned long long)count;
- (id)_identifierForNotificationRequest:(id)arg1;
@end

@interface UIImage (Private)
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)identifier format:(int)format;
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)identifier format:(int)format scale:(float)scale;
+ (UIImage *)_applicationIconImageForBundleIdentifier:(NSString *)identifier roleIdentifier:(id)id format:(int)format scale:(float)scale;
@end

@interface NCNotificationPriorityListViewController : NCNotificationListViewController
- (NSOrderedSet *)allNotificationRequests;
- (NCNotificationPriorityList *)notificationRequestList;
- (NCNotificationRequest *)notificationRequestAtIndexPath:(NSIndexPath *)path;
- (void)insertNotificationRequest:(NCNotificationRequest *)request forCoalescedNotification:(id)notification;
- (void)modifyNotificationRequest:(NCNotificationRequest *)request forCoalescedNotification:(id)notification;
- (void)removeNotificationRequest:(NCNotificationRequest *)request forCoalescedNotification:(id)notification;
- (void)_reloadNotificationViewControllerForHintTextAtIndexPaths:(id)arg1;
- (void)_reloadNotificationViewControllerForHintTextAtIndexPath:(id)arg1;
@end

@interface NCNotificationSectionListViewController : NCNotificationListViewController
@end

@interface NCNotificationListCollectionView : UICollectionView
- (NCNotificationPriorityListViewController *)dataSource;
@end

@interface SBDashBoardNotificationListViewController : UIViewController
- (NCNotificationListCollectionView *)notificationListScrollView;
- (NSUInteger)numNotifications;
- (NSString *)notificationIdentifierAtIndex:(NSUInteger)index;
@end

@interface SBApplication : NSObject
@end

@interface SBApplicationController : NSObject
+ (id)sharedInstance;
- (SBApplication *)applicationWithBundleIdentifier:(NSString *)arg1;
@end

@interface NCNotificationViewController : UIViewController
@property (nonatomic, retain) NCNotificationRequest *notificationRequest;
@end

@interface NCNotificationListCell : UICollectionViewCell
@property (nonatomic, retain) NCNotificationViewController *contentViewController;
@end

@interface NCMaterialView : UIView
@property (assign, nonatomic) double grayscaleValue;
+ (id)materialViewWithStyleOptions:(unsigned long long)arg1;

@end

