//
//  MMAppSwitcher.m
//  PunchCard
//
//  Created by Vinh Phuc Dinh on 23.11.13.
//  Copyright (c) 2013 Mocava Mobile. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "MMAppSwitcher.h"

@interface MMAppSwitcher()

@property (nonatomic, weak) id<MMAppSwitcherDataSource> datasource;
@property (nonatomic, strong) UIView *view;
@property (nonatomic, strong) UIWindow *window;
@property (nonatomic, strong) UIWindow *originalWindow;

@end

static MMAppSwitcher *_sharedInstance;

static UIImageView *rasterizedView(UIView *view);

@implementation MMAppSwitcher

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [MMAppSwitcher new];
        _sharedInstance.originalWindow = [[UIApplication sharedApplication] keyWindow];
        UIScreen *screen = [UIScreen mainScreen];
        if ([screen respondsToSelector:@selector(nativeBounds)]) { // iOS 8+
            CGRect frame = CGRectMake(0.0f, 0.0f,
                                      screen.nativeBounds.size.width/screen.nativeScale,
                                      screen.nativeBounds.size.height/screen.nativeScale);
            _sharedInstance.window = [[UIWindow alloc] initWithFrame:frame];
        } else {
            _sharedInstance.window = [[UIWindow alloc] initWithFrame:[screen bounds]];
        }
        _sharedInstance.window.backgroundColor = [UIColor blackColor];
        _sharedInstance.window.windowLevel = UIWindowLevelStatusBar;
    });
    return _sharedInstance;
}

- (void)setDataSource:(id<MMAppSwitcherDataSource>)dataSource {
    if (_datasource && !dataSource) {
        [self disableNotifications];
    } else if (!_datasource && dataSource) {
        [self enableNotifications];
    }
    _datasource = dataSource;
}

- (void)enableNotifications {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appWillEnterForeground)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appWillEnterBackground)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
}

- (void)disableNotifications {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)loadCard {
    if ([self.datasource respondsToSelector:@selector(appSwitcher:viewForCardWithSize:)]) {
        UIView *view = [self.datasource appSwitcher:self viewForCardWithSize:[self cardSizeForCurrentOrientation]];
        [self.view removeFromSuperview];
        if (view) {
            self.view = rasterizedView(view);
            self.view.frame = (CGRect){0, 0, self.window.bounds.size};
            self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [self.window addSubview:self.view];
        } else {
            self.view = nil;
            self.window.hidden = YES;
        }
    }
}

- (void)setNeedsUpdate {
    [self loadCard];
}

#pragma mark - Helper methods

- (BOOL)viewControllerBasedStatusBarAppearanceEnabled {
    CFBooleanRef viewControllerBasedStatusBarAppearance = CFBundleGetValueForInfoDictionaryKey(CFBundleGetMainBundle(), (CFStringRef)@"UIViewControllerBasedStatusBarAppearance");
    return (viewControllerBasedStatusBarAppearance==kCFBooleanTrue);
}

- (CGSize)cardSizeForCurrentOrientation {
    CGRect screenBounds = [UIScreen mainScreen].bounds;
    CGSize cardSize;
    if ([[UIDevice currentDevice] userInterfaceIdiom]==UIUserInterfaceIdiomPhone) {
        cardSize = CGSizeMake(ceilf(0.475*screenBounds.size.width), ceilf(0.475*screenBounds.size.height));
    } else {
        cardSize = CGSizeMake(ceilf(0.5*screenBounds.size.width), ceilf(0.5*screenBounds.size.height));
    }
    return cardSize;
}


#pragma mark - Notifications

- (void)appWillEnterForeground {
    [self.view removeFromSuperview];
    self.view = nil;
    self.window.hidden = YES;
}

- (void)appWillEnterBackground {
    [self loadCard];
    if (self.view)
        self.window.hidden = NO;
}

@end


#pragma mark - Helper function

static UIImageView *rasterizedView(UIView *view)
{
    view.layer.magnificationFilter = kCAFilterNearest;
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, view.opaque, 0.0);
    [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [[UIImageView alloc] initWithImage:img];
}

