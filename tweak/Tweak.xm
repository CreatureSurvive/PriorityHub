#import <UIKit/UIKit.h>
#include <dlfcn.h>
#include <AppList/AppList.h>
#import "substrate.h"
#import "Headers.h"
#import "PHContainerView.h"
#import "PHPullToClearView.h"

#define IN_LS [self isKindOfClass:%c(NCNotificationPriorityListViewController)]
#define ENABLED ((IN_LS && [prefs boolForKey:@"enabled"]) || (!IN_LS && [prefs boolForKey:@"ncEnabled"]))

NSUserDefaults *prefs = nil;
PHContainerView *lsPhContainerView = nil;
PHContainerView *ncPhContainerView = nil;
PHPullToClearView *lsPullToClearView = nil;
PHPullToClearView *ncPullToClearView = nil;

CGSize appViewSize(BOOL lockscreen) {
    if ((lockscreen && ![prefs boolForKey:@"enabled"]) || (!lockscreen && ![prefs boolForKey:@"ncEnabled"]))
        return CGSizeZero;

    CGFloat width = 0;
    NSInteger iconSize = (lockscreen) ? [prefs integerForKey:@"iconSize"] : [prefs integerForKey:@"ncIconSize"];

    switch (iconSize) {
        default:
        case 0:
            width = 40;
            break;
        case 1:
            width = 53;
            break;
        case 2:
            width = 63;
            break;
        case 3:
            width = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) ? 106 : 84;
            break;
    }

    BOOL numberStyleBelow = (lockscreen) ? [prefs boolForKey:@"numberStyle"] : [prefs boolForKey:@"ncNumberStyle"];
    CGFloat height = (numberStyleBelow) ? width * 1.45 : width;
    return CGSizeMake(width, height);
}

UIImage *iconForIdentifier(NSString *identifier) {
    UIImage *icon = [[ALApplicationList sharedApplicationList] iconOfSize:ALApplicationIconSizeLarge forDisplayIdentifier:identifier];

    if (!icon) {
        // somehow get an NCNotificationRequest for this identifier
        // then get NCNotificationContent with request.content
        // then get icon with content.icon (20 x 20 but better than nothing)

        NSLog(@"NIL ICON");
    }

    return icon;

    // Apple 2FA identifier: com.apple.springboard.SBUserNotificationAlert
    // Low power mode identifier (maybe): com.apple.DuetHeuristic-BM

    // return [UIImage _applicationIconImageForBundleIdentifier:identifier format:0 scale:[UIScreen mainScreen].scale];
}

%ctor {
    prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.thomasfinch.priorityhub"];
    [prefs registerDefaults:@{
         // Lockscreen settings
         @"enabled": @YES,
         @"collapseOnLock": @YES,
         @"enablePullToClear": @YES,
         @"privacyMode": @NO,
         @"iconLocation": [NSNumber numberWithInt:0],
         @"iconSize": [NSNumber numberWithInt:1],
         @"numberStyle": [NSNumber numberWithInt:1],
         @"verticalAdjustmentTop": [NSNumber numberWithFloat:0],
         @"verticalAdjustmentBottom": [NSNumber numberWithFloat:0],
         @"verticalAdjustmentTopDirection": [NSNumber numberWithInt:0],
         @"verticalAdjustmentBottomDirection": [NSNumber numberWithInt:0],
         @"showAllWhenNotSelected": [NSNumber numberWithInt:0],

         // Notification center settings
         @"ncEnabled": @YES,
         @"ncIconLocation": [NSNumber numberWithInt:0],
         @"ncIconSize": [NSNumber numberWithInt:1],
         @"ncNumberStyle": [NSNumber numberWithInt:1],
         @"ncEnablePullToClear": @YES,
         @"ncShowAllWhenNotSelected": [NSNumber numberWithInt:0],
         @"ncCollapseOnLock": @YES
     }];
}

//
// ─── SBSearchEtceteraNotificationsLayoutContentView ─────────────────────────────
//


%hook SBSearchEtceteraNotificationsLayoutContentView
-(id)initWithFrame: (CGRect)frame {
    if (self == %orig(frame)) {
        PHContainerView * *phContainerView = (IN_LS) ? &lsPhContainerView : &ncPhContainerView;
        if (!(IN_LS) && !*phContainerView) {
            *phContainerView = [[PHContainerView alloc] init:(IN_LS)];
            [self addSubview:*phContainerView];
        }
    }
    return self;
}

%end

//
// ─── NCNotificationListContainerViewController ──────────────────────────────────
//


%hook NCNotificationListContainerViewController

- (void)didMoveToSuperView {
    %orig;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewWillLayoutSubviews) name:@"kPHLayoutNCContainer" object:nil];
}

- (void)dealloc {
    %orig;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillLayoutSubviews {
    %orig;
    if (!(IN_LS)) {
        self.view.bounds = CGRectMake(self.view.bounds.origin.x, -appViewSize(NO).height/2, self.view.bounds.size.width, self.view.frame.size.height - appViewSize(NO).height);
    }
}

%end

//
// ─── NCNotificationListViewController ───────────────────────────────────────────
//

%hook NCNotificationListViewController

// sets the size of hidden notifications to 1x1 inorder to remove spaces for hidden notifications
// setting this to CGSizeZero will result in the collectionView using the layout size which also does not accept 0 size cell
// it seams that even wen seting 1x1 as the size in the layout, it is still ignored, propably because NCNotificationListViewController
// implements this method on its own, so we are forced to do the same
- (CGSize)collectionView: (UICollectionView *)collection layout: (UICollectionViewLayout *)layout sizeForItemAtIndexPath: (NSIndexPath *)indexPath {
    if (![self shouldShowNotificationAtIndexPath:indexPath]) {
        return CGSizeMake(1, 1);
    } else {
        return %orig;
    }
}

%new
- (BOOL)shouldShowNotificationAtIndexPath: (NSIndexPath *)indexPath {
    NSString *identifier = [[self notificationRequestAtIndexPath:indexPath] sectionIdentifier];
    PHContainerView * *phContainerView = (IN_LS) ? &lsPhContainerView : &ncPhContainerView;
    BOOL showAllWhenNotSelected = (IN_LS && [prefs integerForKey:@"showAllWhenNotSelected"] == 1) || (!IN_LS && [prefs integerForKey:@"ncShowAllWhenNotSelected"] == 1);

    if (!(*phContainerView).selectedAppID) {
        if (IN_LS && [prefs boolForKey:@"privacyMode"])
            return NO;
        else
            return showAllWhenNotSelected;
    }
    return [(*phContainerView).selectedAppID isEqualToString:identifier];
}

%new
- (NSArray *)allIndexPaths {
    NSMutableArray *indexPaths = [NSMutableArray new];

    for (NSInteger section = 0; section < [self numberOfSectionsInCollectionView:self.collectionView]; section++) {
        for (NSInteger item = 0; item < [self collectionView:self.collectionView numberOfItemsInSection:section]; item++) {
            [indexPaths addObject:[NSIndexPath indexPathForRow:item inSection:section]];
        }
    }

    return indexPaths;
}

- (void)viewDidLoad {
    %orig;

    // It's a little gross using double pointers but it lets LS & NC use the same code
    PHContainerView * *phContainerView = (IN_LS) ? &lsPhContainerView : &ncPhContainerView;
    PHPullToClearView * *pullToClearView = (IN_LS) ? &lsPullToClearView : &ncPullToClearView;

    // Create the PHContainerView
    if ((IN_LS) && !*phContainerView) {
        *phContainerView = [[PHContainerView alloc] init:(IN_LS)];
        [self.view addSubview:*phContainerView];
    }

    // Create the pull to clear view
    if (!*pullToClearView) {
        *pullToClearView = [PHPullToClearView new];
        [self.collectionView addSubview:*pullToClearView];
    }

    // Set up notification fetching block
    (*phContainerView).getCurrentNotifications = ^NSDictionary *() {
        NSMutableDictionary *notificationsDict = [NSMutableDictionary new];

        // Loop through all sections and rows
        for (NSInteger section = 0; section < [self numberOfSectionsInCollectionView:self.collectionView]; section++) {
            for (NSInteger item = 0; item < [self collectionView:self.collectionView numberOfItemsInSection:section]; item++) {
                NSString *identifier = [[self notificationRequestAtIndexPath:[NSIndexPath indexPathForRow:item inSection:section]] sectionIdentifier];
                unsigned int numNotifications = 1;
                if (notificationsDict[identifier]) {
                    numNotifications = [notificationsDict[identifier] unsignedIntegerValue] + 1;
                }
                [notificationsDict setObject:[NSNumber numberWithUnsignedInteger:numNotifications] forKey:identifier];
            }
        }

        NSLog(@"NOTIFICATIONS: %@", notificationsDict);

        return notificationsDict;
    };

    // Set up table view update block
    (*phContainerView).updateNotificationView = ^void () {
        [self.collectionView.collectionViewLayout invalidateLayout];
        [self.collectionView reloadData];
        [self.collectionView setContentOffset:CGPointZero animated:NO];
        // TODO: update scroll view height

        // Hide pull to clear view if no app is selected
        PHContainerView * *phContainerView = (IN_LS) ? &lsPhContainerView : &ncPhContainerView;
        UIView * *pullToClearView = (IN_LS) ? &lsPullToClearView : &ncPullToClearView;
        (*pullToClearView).hidden = !(*phContainerView).selectedAppID;
    };

    (*pullToClearView).clearBlock = ^void () {
        NSMutableArray *removalRequests = [NSMutableArray new];
        if (IN_LS) {
            @try {
                for (NCNotificationRequest *request in [(NCNotificationPriorityListViewController *)self notificationRequestList].requests) {
                    if ([[request sectionIdentifier] isEqualToString:(*phContainerView).selectedAppID]) {
                        [removalRequests addObject:request];
                    }
                }
            }@catch (NSException *error) {
                CSLog(@"PHub error, %@", error.description);
            }
        } else {
            for (NSInteger section = 0; section < [self numberOfSectionsInCollectionView:self.collectionView]; section++) {
                for (NSInteger item = 0; item < [self collectionView:self.collectionView numberOfItemsInSection:section]; item++) {
                    NCNotificationRequest *request = [self notificationRequestAtIndexPath:[NSIndexPath indexPathForRow:item inSection:section]];
                    if ([[request sectionIdentifier] isEqualToString:(*phContainerView).selectedAppID]) {
                        [removalRequests addObject:request];
                    }
                }
            }
        }
        for (NCNotificationRequest *request in removalRequests) {
            [request.clearAction.actionRunner executeAction:request.clearAction fromOrigin:nil withParameters:nil completion:nil];

            // this does remove the notification, though it does not persist as cleared after a respring
            // [self removeNotificationRequest:request forCoalescedNotification:nil];
        }
    };

}

// pull to clear
- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    %orig;
    PHPullToClearView * *pullToClearView = (PHPullToClearView * *)((IN_LS) ? &lsPullToClearView : &ncPullToClearView);
    [(*pullToClearView) didScroll:scrollView];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    %orig;
    PHPullToClearView * *pullToClearView = (PHPullToClearView * *)((IN_LS) ? &lsPullToClearView : &ncPullToClearView);
    [(*pullToClearView) didEndDragging:scrollView];
}

// - (void)viewWillAppear {
//     %orig;
//     NSLog(@"VIEW WILL APPEAR");
//     // [self.collectionView.collectionViewLayout invalidateLayout];
//     // [self.collectionView reloadData];
//     // [self.collectionView setContentOffset:CGPointZero animated:NO];
// }

- (void)viewWillLayoutSubviews {
    %orig;
    PHContainerView * *phContainerView = (IN_LS) ? &lsPhContainerView : &ncPhContainerView;

    if (!ENABLED) {
        self.collectionView.frame = self.view.bounds;
        (*phContainerView).hidden = YES;
        return;
    }

    (*phContainerView).hidden = NO;

    self.collectionView.clipsToBounds = YES;

    CGRect phContainerViewFrame = CGRectZero;
    CGRect collectionViewFrame = CGRectZero;
    CGRectEdge edge = ((IN_LS && [prefs integerForKey:@"iconLocation"] == 0) || (!IN_LS && [prefs integerForKey:@"ncIconLocation"] == 0)) ? CGRectMinYEdge : CGRectMaxYEdge;
    CGRectDivide(self.view.bounds, &phContainerViewFrame, &collectionViewFrame, appViewSize(IN_LS).height, edge);

    (*phContainerView).frame = phContainerViewFrame;
    if ((IN_LS)) {
        self.collectionView.frame = collectionViewFrame;
    } else {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"kPHLayoutNCContainer" object:nil userInfo:nil];
    }

    // Layout pull to clear view
    UIView * *pullToClearView = (IN_LS) ? &lsPullToClearView : &ncPullToClearView;
    BOOL pullToClearEnabled = (IN_LS) ? [prefs boolForKey:@"enablePullToClear"] : [prefs boolForKey:@"ncEnablePullToClear"];
    (*pullToClearView).frame = CGRectMake(0, -(pullToClearSize + 8), self.collectionView.bounds.size.width, pullToClearSize);
    (*pullToClearView).bounds = CGRectMake(CGRectGetMidX((*pullToClearView).frame) - (pullToClearSize / 2), CGRectGetMidY((*pullToClearView).frame) - (pullToClearSize / 2), pullToClearSize, pullToClearSize);
    (*pullToClearView).hidden = !pullToClearEnabled;
}

%new
- (void)insertOrModifyNotification: (NCNotificationRequest *)request {
    if (!ENABLED) return;

    PHContainerView * *phContainerView = (IN_LS) ? &lsPhContainerView : &ncPhContainerView;
    [*phContainerView updateView];

    if (!(IN_LS && [prefs boolForKey:@"privacyMode"]))
        [*phContainerView selectAppID:[request sectionIdentifier] newNotification: YES];
}

%new
- (void)removeNotification: (NCNotificationRequest *)request {
    if (!ENABLED) return;

    (IN_LS) ? [lsPhContainerView updateView] : [ncPhContainerView updateView];
}

%end

//
// ─── NCNotificationPriorityListViewController ───────────────────────────────────
//

// Customized hooks for LS, hooking same methods in super class doesn't work (too early)
%hook NCNotificationPriorityListViewController

- (void)insertNotificationRequest: (NCNotificationRequest *)request forCoalescedNotification: (id)notification {
    if (![prefs boolForKey:@"privacyMode"])
        lsPhContainerView.selectedAppID = [request sectionIdentifier];

    // I dont think this is necessary, it dowsnt seam to make a difference
    // [self.collectionView performBatchUpdates:^{
    //     [UIView setAnimationsEnabled:NO];
    //     [self.collectionView reloadSections:[NSIndexSet indexSetWithIndex:0]];
    // } completion:^(BOOL finished) {
    //     [UIView setAnimationsEnabled:YES];
    %orig;
    [(NCNotificationListViewController *) self insertOrModifyNotification:request];
// }];
}

- (void)modifyNotificationRequest:(NCNotificationRequest *)request forCoalescedNotification:(id)notification {
    %orig;
    [(NCNotificationListViewController *) self insertOrModifyNotification:request];
}

- (void)removeNotificationRequest:(NCNotificationRequest *)request forCoalescedNotification:(id)notification {
    %orig;
    [(NCNotificationListViewController *) self removeNotification:request];
}

%end

//
// ─── NCNotificationSectionListViewController ────────────────────────────────────
//

// Also customized hooks for NC
%hook NCNotificationSectionListViewController

- (void)insertNotificationRequest: (NCNotificationRequest *)request forCoalescedNotification: (id)notification {
    ncPhContainerView.selectedAppID = [request sectionIdentifier];
    %orig;
    [(NCNotificationListViewController *) self insertOrModifyNotification:request];
}

- (void)modifyNotificationRequest:(NCNotificationRequest *)request forCoalescedNotification:(id)notification {
    %orig;
    [(NCNotificationListViewController *) self insertOrModifyNotification:request];
}

- (void)removeNotificationRequest:(NCNotificationRequest *)request forCoalescedNotification:(id)notification {
    %orig;
    [(NCNotificationListViewController *) self removeNotification:request];
}

%end

//
// ─── NCNotificationListCollectionViewFlowLayout ─────────────────────────────────
//

%hook NCNotificationListCollectionViewFlowLayout


- (NSArray *)layoutAttributesForElementsInRect: (CGRect)rect {
    NCNotificationListViewController *controller = (NCNotificationListViewController *)self.collectionView.delegate;
    BOOL inLS = [controller isKindOfClass:%c(NCNotificationPriorityListViewController)];

    NSArray *attributes = %orig;

    if (!((inLS && [prefs boolForKey:@"enabled"]) || (!inLS && [prefs boolForKey:@"ncEnabled"])))
        return attributes;

    BOOL previousHidden = NO;
    BOOL firstItem = YES;

    for (UICollectionViewLayoutAttributes *attribute in attributes) {

        if (attribute.representedElementCategory != UICollectionElementCategoryCell)
            continue;

        if (![controller shouldShowNotificationAtIndexPath:attribute.indexPath]) {
            attribute.hidden = YES;
            attribute.size = CGSizeZero;// does not seam to work with zero or 1 as size, this setting is ignored?
            attribute.frame = CGRectZero;// does not seam to work with zero or 1 as size, this setting is ignored?
            previousHidden = YES;
        } else {
            attribute.center = CGPointMake(controller.collectionView.center.x, attribute.center.y);
            previousHidden = NO;
            firstItem = NO;
        }
    }
    for (NSString *string in attributes) {
        CSLog(@"PHub attributes %@", string);
    }

    return attributes;
}

%end

//
// ─── NCNotificationSectionListViewController ────────────────────────────────────
//

// Hide section headers in notification center
// Posible solution to weird spacing. edit the section list when its set and place all notifications in one section
// this shoud force all notifications into one section causing there to only be one header added to the list
// then i can adjust the spcing for the first cell only
%hook NCNotificationSectionListViewController

-(CGSize)collectionView: (id)arg1 layout: (id)arg2 referenceSizeForHeaderInSection: (long long)arg3 {
    return ([prefs boolForKey:@"ncEnabled"]) ? CGSizeZero : %orig;
}

%end

//
// ─── SBDashBoardClippingLine ────────────────────────────────────────────────────
//

// Hide line that shows when scrolling up on lock screen
%hook SBDashBoardClippingLine

- (void)layoutSubviews {
    %orig;
    self.hidden = YES;
}

%end

//
// ─── SBDashBoardMainPageView ────────────────────────────────────────────────────
//

// Hide "Press home to unlock" label on lock screen if PH is at the bottom
%hook SBDashBoardMainPageView

- (void)_layoutCallToActionLabel {
    %orig;
    self.callToActionLabel.hidden = ([prefs boolForKey:@"enabled"] && [prefs integerForKey:@"iconLocation"] == 1);
}

%end

//
// ─── SBDashBoardPageControl ─────────────────────────────────────────────────────
//

// Hide lock screen page indicators if PH is at the bottom
%hook SBDashBoardPageControl

- (void)layoutSubviews {
    %orig;
    self.hidden = ([prefs boolForKey:@"enabled"] && [prefs integerForKey:@"iconLocation"] == 1);
}

%end

//
// ─── SBLockScreenViewControllerBase ─────────────────────────────────────────────
//

// For the deselect on lock feature on lock screen
%hook SBLockScreenViewControllerBase

- (void)setInScreenOffMode: (BOOL)locked {
    %orig;
    if (locked && [prefs boolForKey:@"enabled"] && [prefs boolForKey:@"collapseOnLock"] && lsPhContainerView) {
        [lsPhContainerView selectAppID:lsPhContainerView.selectedAppID newNotification:NO];
    }
}

%end

//
// ─── SBNotificationCenterController ─────────────────────────────────────────────
//

// For the deselect on close feature in notification center
%hook SBNotificationCenterController

- (void)transitionDidBegin: (id)animated {
    %orig;
    [ncPhContainerView updateView];
    [ncPhContainerView selectAppID:ncPhContainerView.selectedAppID newNotification:NO];
    ncPhContainerView.updateNotificationView();
}

- (void)transitionDidFinish:(id)animated {
    %orig;
    if (![self isVisible] && [prefs boolForKey:@"ncEnabled"] && [prefs boolForKey:@"ncCollapseOnLock"] && ncPhContainerView) {
        [ncPhContainerView selectAppID:ncPhContainerView.selectedAppID newNotification:NO];
    }
}

%end
