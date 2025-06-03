@import UIKit;

#import <HBLog.h>

@interface SBRingerControl : NSObject
- (BOOL)isRingerMuted;
- (BOOL)_accessibilityIsRingerMuted;
@end

static BOOL IsRingerMuted(SBRingerControl *ringerControl) {
    if ([ringerControl respondsToSelector:@selector(isRingerMuted)]) {
        return [ringerControl isRingerMuted];
    }
    if ([ringerControl respondsToSelector:@selector(_accessibilityIsRingerMuted)]) {
        return [ringerControl _accessibilityIsRingerMuted];
    }
    return NO;
}

@interface _UIStatusBarDataQuietModeEntry : NSObject
@property(nonatomic, copy) NSString *focusName;
@end

@interface _UIStatusBarData : NSObject
@property(nonatomic, copy) _UIStatusBarDataQuietModeEntry *quietModeEntry;
@end

@interface _UIStatusBarItemUpdate : NSObject
@property(nonatomic, strong) _UIStatusBarData *data;
@end

@interface UIStatusBarServer : NSObject
+ (const unsigned char *)getStatusBarData;
@end

@interface UIStatusBar_Base : UIView
@property(nonatomic, strong) UIStatusBarServer *statusBarServer;
- (void)reloadSingleMute;
- (void)forceUpdateData:(BOOL)arg1;
- (void)statusBarServer:(id)arg1 didReceiveStatusBarData:(const unsigned char *)arg2 withActions:(int)arg3;
@end

@interface UIStatusBar_Modern : UIStatusBar_Base
@end

@interface SMWeakContainer : NSObject
@property(nonatomic, weak) id object;
@end

@implementation SMWeakContainer
@end

static BOOL kIsEnabled = YES;
static BOOL kUseLowPriorityLocation = NO;

static void ReloadPrefs() {
    static NSUserDefaults *prefs = nil;
    if (!prefs) {
        prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.82flex.singlemuteprefs"];
    }

    NSDictionary *settings = [prefs dictionaryRepresentation];

    kIsEnabled = settings[@"IsEnabled"] ? [settings[@"IsEnabled"] boolValue] : YES;
    kUseLowPriorityLocation = settings[@"LowerPriorityForLocationIcon"] ? [settings[@"LowerPriorityForLocationIcon"] boolValue] : NO;
}

static SBRingerControl *_ringerControl = nil;
static NSMutableSet<SMWeakContainer *> *_weakContainers = nil;

// this is enough for the status bar legacy data
static unsigned char *_sharedData = NULL;

%group SingleMuteQuietMode

%hook _UIStatusBarIndicatorQuietModeItem

- (id)systemImageNameForUpdate:(_UIStatusBarItemUpdate *)update {
    BOOL isRingerMuted = IsRingerMuted(_ringerControl);
    BOOL isQuietModeEnabled = ![update.data.quietModeEntry.focusName isEqualToString:@"!Mute"];
    if (isRingerMuted && !isQuietModeEnabled) {
        return @"bell.slash.fill";
    }
    return %orig;
}

%end

%hook _UIStatusBarDataQuietModeEntry

- (id)initFromData:(unsigned char *)data type:(int)arg2 focusName:(const char *)arg3 maxFocusLength:(int)arg4 imageName:(const char*)arg5 maxImageLength:(int)arg6 boolValue:(BOOL)arg7 {
    BOOL isQuietMode = data[2];
    if (!isQuietMode) {
        _sharedData[2] = IsRingerMuted(_ringerControl);
        return %orig(_sharedData, arg2, "!Mute", arg4, arg5, arg6, arg7);
    }
    return %orig;
}

%end

%hook SBRingerControl

// iOS 15
- (id)initWithHUDController:(id)arg1 soundController:(id)arg2 {
	_ringerControl = %orig;
	return _ringerControl;
}

// iOS 16+
- (id)initWithBannerManager:(id)arg1 soundController:(id)arg2 {
	_ringerControl = %orig;
	return _ringerControl;
}

- (void)setRingerMuted:(BOOL)arg1 {
    %orig;
    for (SMWeakContainer *container in _weakContainers) {
        UIStatusBar_Base *statusBar = (UIStatusBar_Base *)container.object;
        [statusBar reloadSingleMute];
    }
}

// iOS 17
- (void)setRingerMuted:(BOOL)arg1 withFeedback:(BOOL)arg2 reason:(id)arg3 clientType:(unsigned)arg4 {
    %orig;
    for (SMWeakContainer *container in _weakContainers) {
        UIStatusBar_Base *statusBar = (UIStatusBar_Base *)container.object;
        [statusBar reloadSingleMute];
    }
}

%end

%hook UIStatusBar_Base

- (instancetype)_initWithFrame:(CGRect)frame showForegroundView:(BOOL)showForegroundView wantsServer:(BOOL)wantsServer inProcessStateProvider:(id)inProcessStateProvider {
    SMWeakContainer *container = [SMWeakContainer new];
    container.object = self;
    [_weakContainers addObject:container];
    return %orig;
}

%new
- (void)reloadSingleMute {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        const unsigned char *data = [UIStatusBarServer getStatusBarData];
        [self statusBarServer:self.statusBarServer didReceiveStatusBarData:data withActions:0];
    });
}

%end

%end // SingleMuteQuietMode

%group SingleMuteLocation

%hook _UIStatusBarDataLocationEntry

- (id)initFromData:(unsigned char *)arg1 type:(int)arg2 {
    BOOL isRingerMuted = IsRingerMuted(_ringerControl);
    if (isRingerMuted) {
        _sharedData[21] = 0;
        return %orig(_sharedData, arg2);
    }
    return %orig;
}

%end

%end // SingleMuteLocation

%ctor {
    ReloadPrefs();
    if (!kIsEnabled) {
        return;
    }

    _weakContainers = [NSMutableSet set];
    _sharedData = (unsigned char *)calloc(32768, sizeof(unsigned char));

    %init(SingleMuteQuietMode);
    if (kUseLowPriorityLocation) {
        %init(SingleMuteLocation);
    }
}