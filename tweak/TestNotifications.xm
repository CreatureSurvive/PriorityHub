#import "TestNotifications.h"
#include <dlfcn.h>

BBServer *bbServer = nil;

static const NSUInteger kNotificationCenterDestination = 2;
static const NSUInteger kLockScreenDestination = 4;

static dispatch_queue_t getBBServerQueue() {
    static dispatch_queue_t queue;
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        void *handle = dlopen(NULL, RTLD_GLOBAL);
        if (handle) {
            dispatch_queue_t *pointer = (dispatch_queue_t *)dlsym(handle, "__BBServerQueue");
            if (pointer) {
                queue = *pointer;
            }
            dlclose(handle);
        }
    });
    return queue;
}

static NSUInteger bulletinNum = 0;

// Must be invoked on the BBServerQueue!
static NSString *nextBulletinID() {
    ++bulletinNum;
    return [NSString stringWithFormat:@"com.thomasfinch.priorityhub.notification-id-%@", @(bulletinNum)];
}

// Must be invoked on the BBServerQueue!
static void sendTestNotification(BBServer *server, NSUInteger destinations, BOOL toLS) {
    NSString *bulletinID = nextBulletinID();
    BBBulletinRequest *bulletin = [[[%c(BBBulletinRequest) alloc] init] autorelease];
    bulletin.title = @"Priority Hub";
    bulletin.subtitle = @"This is a test notification!";
    bulletin.sectionID = @"com.apple.MobileSMS";
    bulletin.recordID = bulletinID;
    bulletin.publisherBulletinID = bulletinID;
    bulletin.clearable = YES;
    bulletin.showsMessagePreview = YES;
    NSDate *date = [NSDate date];
    bulletin.date = date;
    bulletin.publicationDate = date;
    bulletin.lastInterruptDate = date;

    NSURL *url = [NSURL URLWithString:@"prefs:root=PriorityHub"];
    bulletin.defaultAction = [%c(BBAction) actionWithLaunchURL:url];

    if ([server respondsToSelector:@selector(publishBulletinRequest:destinations:alwaysToLockScreen:)]) {
        [server publishBulletinRequest:bulletin destinations:destinations alwaysToLockScreen:toLS];
    }
}

static void showTestLockScreenNotification() {
    dispatch_queue_t queue = getBBServerQueue();
    if (!bbServer || !queue) {
        return;
    }

    [[%c(SBLockScreenManager) sharedInstance] lockUIFromSource:1 withOptions:nil];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.7 * NSEC_PER_SEC), queue, ^{
        sendTestNotification(bbServer, kLockScreenDestination, YES);
    });
}

static void showTestNotificationCenterNotification() {
    dispatch_queue_t queue = getBBServerQueue();
    if (!bbServer || !queue) {
        return;
    }

    [[%c(SBNotificationCenterController) sharedInstance] presentAnimated:YES];

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.7 * NSEC_PER_SEC), queue, ^{
        sendTestNotification(bbServer, kNotificationCenterDestination, NO);
    });
}

%hook BBServer

- (id)init {
    bbServer = %orig;
    return bbServer;
}

%end

%ctor {

    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)showTestNotificationCenterNotification, CFSTR("com.thomasfinch.priorityhub-testnotification-nc"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)showTestLockScreenNotification, CFSTR("com.thomasfinch.priorityhub-testnotification-ls"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
}