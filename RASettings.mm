#import "RASettings.h"
#import "headers.h"
#import "RABackgrounder.h"
#import "RAThemeManager.h"
#import "RANCViewController.h"

#define BOOL(key, default) ([_settings objectForKey:key] != nil ? [_settings[key] boolValue] : default) 

NSCache *backgrounderSettingsCache = [NSCache new];


@implementation RASettings
+(BOOL) isParagonInstalled
{
	static BOOL installed = NO;
	static dispatch_once_t onceToken = 0;
	dispatch_once(&onceToken, ^{
	    installed = [NSFileManager.defaultManager fileExistsAtPath:@"/Library/MobileSubstrate/DynamicLibraries/ParagonPlus.dylib"];
	});
	return installed;
}

+(BOOL) isActivatorInstalled
{
	static BOOL installed = NO;
	static dispatch_once_t onceToken = 0;
	dispatch_once(&onceToken, ^{
		if ([NSFileManager.defaultManager fileExistsAtPath:@"/Library/MobileSubstrate/DynamicLibraries/libactivator.dylib"])
		{
			installed = YES;
	        dlopen("/Library/MobileSubstrate/DynamicLibraries/libactivator.dylib", RTLD_LAZY);
		}
	});
	return installed;
}

+(BOOL) isLibStatusBarInstalled
{	
	static BOOL installed = NO;
	static dispatch_once_t onceToken = 0;
	dispatch_once(&onceToken, ^{
		if ([NSFileManager.defaultManager fileExistsAtPath:@"/Library/MobileSubstrate/DynamicLibraries/libstatusbar.dylib"])
		{
			installed = YES;
	        dlopen("/Library/MobileSubstrate/DynamicLibraries/libstatusbar.dylib", RTLD_LAZY);
		}
	});
	return installed;
}

+(instancetype) sharedInstance
{
	SHARED_INSTANCE(RASettings);
}

-(id) init
{
	if (self = [super init])
	{
		[self reloadSettings];
	}
	return self;
}

-(void) reloadSettings
{
	@autoreleasepool {
		//NSLog(@"[ReachApp] reloading settings");
		// Prepare specialized setting change cases
		NSString *previousNCAppSetting = self.NCApp;

		// Reload Settings
		if (_settings)
		{
			//CFRelease((__bridge CFDictionaryRef)_settings);
			_settings = nil;
		}
		CFPreferencesAppSynchronize(CFSTR("com.efrederickson.reachapp.settings"));
		CFStringRef appID = CFSTR("com.efrederickson.reachapp.settings");
		CFArrayRef keyList = CFPreferencesCopyKeyList(appID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);

		BOOL failed = NO;

		if (keyList) 
		{
			//_settings = (__bridge NSDictionary *)CFPreferencesCopyMultiple(keyList, appID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
			_settings = (NSDictionary*)CFBridgingRelease(CFPreferencesCopyMultiple(keyList, appID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost));
			CFRelease(keyList);

			if (!_settings) 
			{
				//NSLog(@"[ReachApp] failure loading from CFPreferences");
				failed = YES;
			}
		}
		else 
		{
			//NSLog(@"[ReachApp] failure loading keyList");
			failed = YES;
		}
		CFRelease(appID);

		if (failed)
		{
			_settings = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.efrederickson.reachapp.settings.plist"];
			//NSLog(@"[ReachApp] settings sandbox load: %@", _settings == nil ? @"failed" : @"succeed");
		}

		if (_settings == nil)
		{
			NSLog(@"[ReachApp] could not load settings from CFPreferences or NSDictionary");
		}

		if ([previousNCAppSetting isEqual:self.NCApp] == NO)
			[[objc_getClass("RANCViewController") sharedViewController] forceReloadAppLikelyBecauseTheSettingChanged]; // using objc_getClass allows RASettings to be used in reachappsettings and other places

		if ([self shouldShowStatusBarIcons] == NO && [objc_getClass("SBApplication") respondsToSelector:@selector(RA_clearAllStatusBarIcons)])
			[objc_getClass("SBApplication") performSelector:@selector(RA_clearAllStatusBarIcons)];

		[RAThemeManager.sharedInstance invalidateCurrentThemeAndReload:[self currentThemeIdentifier]];
		[backgrounderSettingsCache removeAllObjects];
	}
}

-(void) resetSettings
{
	IF_NOT_SPRINGBOARD {
		@throw [NSException exceptionWithName:@"NotSpringBoardException" reason:@"Cannot reset settings outside of SpringBoard" userInfo:nil];
	}
	CFPreferencesAppSynchronize(CFSTR("com.efrederickson.reachapp.settings"));
	CFStringRef appID = CFSTR("com.efrederickson.reachapp.settings");
	CFArrayRef keyList = CFPreferencesCopyKeyList(appID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);

	if (keyList) 
	{
		CFPreferencesSetMultiple(NULL, keyList, appID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
		CFRelease(keyList);
	}
	else
	{
		NSLog(@"[ReachApp] unable to get keyList to reset settings");
	}
	CFPreferencesAppSynchronize(appID);
	CFRelease(appID);

    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.efrederickson.reachapp.respring"), nil, nil, YES);
}

-(BOOL) enabled
{
	return BOOL(@"enabled", YES);
}

#if DEBUG
-(BOOL) debug_showIPCMessages { return BOOL(@"debug_showIPCMessages", YES); }
#endif

-(BOOL) reachabilityEnabled { return [self enabled] && BOOL(@"reachabilityEnabled", YES); }

-(BOOL) disableAutoDismiss
{
	return BOOL(@"disableAutoDismiss", YES);
}

-(BOOL) enableRotation
{
	return BOOL(@"enableRotation", YES);
}

-(BOOL) showNCInstead
{
	return BOOL(@"showNCInstead", NO);
}

-(BOOL) homeButtonClosesReachability
{
	return BOOL(@"homeButtonClosesReachability", YES);
}

-(BOOL) showBottomGrabber
{
	return BOOL(@"showBottomGrabber", NO);
}

-(BOOL) showWidgetSelector
{
	return BOOL(@"showAppSelector", YES);
}

-(BOOL) scalingRotationMode
{
	return BOOL(@"rotationMode", NO);
}

-(BOOL) autoSizeWidgetSelector
{
	return BOOL(@"autoSizeAppChooser", YES);
}

-(BOOL) showAllAppsInWidgetSelector
{
	return BOOL(@"showAllAppsInAppChooser", YES);
}

-(BOOL) showRecentAppsInWidgetSelector
{
	return BOOL(@"showRecents", YES);
}

-(BOOL) pagingEnabled
{
	return BOOL(@"pagingEnabled", YES);
}

-(BOOL) NCAppEnabled
{
	return [self enabled] && BOOL(@"ncAppEnabled", YES);
}

-(BOOL) shouldShowStatusBarNativeIcons { return BOOL(@"shouldShowStatusBarNativeIcons", NO); }

-(NSMutableArray*) favoriteApps
{
	NSMutableArray *favorites = [[NSMutableArray alloc] init];
	for (NSString *key in _settings.allKeys)
	{
		if ([key hasPrefix:@"Favorites-"])
		{
			NSString *ident = [key substringFromIndex:10];
			if ([_settings[key] boolValue])
				[favorites addObject:ident];
		}
	}
	return favorites;
}

-(BOOL) unifyStatusBar
{
	return BOOL(@"unifyStatusBar", YES);
}

-(BOOL) flipTopAndBottom
{
	return BOOL(@"flipTopAndBottom", NO);
}

-(NSString*) NCApp
{
	return [_settings objectForKey:@"NCApp"] == nil ? @"com.apple.Preferences" : _settings[@"NCApp"];
}

-(BOOL) alwaysEnableGestures
{
	return BOOL(@"alwaysEnableGestures", YES);
}

-(BOOL) snapWindows
{
	return BOOL(@"snapWindows", YES);
}

-(BOOL) launchIntoWindows
{
	return BOOL(@"launchIntoWindows", NO);
}

-(BOOL) openLinksInWindows { return BOOL(@"openLinksInWindows", NO); }

-(BOOL) backgrounderEnabled
{
	return [self enabled] && BOOL(@"backgrounderEnabled", YES);
}

-(BOOL) shouldShowIconIndicatorsGlobally
{
	return BOOL(@"showIconIndicators", YES);
}

-(BOOL) showNativeStateIconIndicators
{
	return BOOL(@"showNativeStateIconIndicators", NO);
}

-(BOOL) missionControlEnabled
{
	return [self enabled] && BOOL(@"missionControlEnabled", YES);
}

-(BOOL) replaceAppSwitcherWithMC
{
	return BOOL(@"replaceAppSwitcherWithMC", NO);
}

-(BOOL) missionControlKillApps { return BOOL(@"mcKillApps", YES); }

-(BOOL) snapRotation
{
	return BOOL(@"snapRotation", YES);
}

-(NSInteger) globalBackgroundMode
{
	return [_settings objectForKey:@"globalBackgroundMode"] == nil ? RABackgroundModeNative : [_settings[@"globalBackgroundMode"] intValue];
}

-(NSInteger) windowRotationLockMode
{
	return [_settings objectForKey:@"windowRotationLockMode"] == nil ? 0 : [_settings[@"windowRotationLockMode"] intValue];
}

-(BOOL) shouldShowStatusBarIcons { return BOOL(@"shouldShowStatusBarIcons", YES); }

-(NSDictionary*) _createAndCacheBackgrounderSettingsForIdentifier:(NSString*)identifier
{
	NSMutableDictionary *ret = [NSMutableDictionary dictionary];

	ret[@"enabled"] = _settings[[NSString stringWithFormat:@"backgrounder-%@-enabled",identifier]] ?: @NO;
	ret[@"backgroundMode"] = _settings[[NSString stringWithFormat:@"backgrounder-%@-backgroundMode",identifier]] ?: @1;
	ret[@"autoLaunch"] = _settings[[NSString stringWithFormat:@"backgrounder-%@-autoLaunch",identifier]] ?: @NO;
	ret[@"autoRelaunch"] = _settings[[NSString stringWithFormat:@"backgrounder-%@-autoRelaunch",identifier]] ?: @NO;
	ret[@"showIndicatorOnIcon"] = _settings[[NSString stringWithFormat:@"backgrounder-%@-showIndicatorOnIcon",identifier]] ?: @YES;
	ret[@"preventDeath"] = _settings[[NSString stringWithFormat:@"backgrounder-%@-preventDeath",identifier]] ?: @NO;
	ret[@"unlimitedBackgrounding"] = _settings[[NSString stringWithFormat:@"backgrounder-%@-unlimitedBackgrounding",identifier]] ?: @NO;
	ret[@"removeFromSwitcher"] = _settings[[NSString stringWithFormat:@"backgrounder-%@-removeFromSwitcher",identifier]] ?: @NO;
	ret[@"showStatusBarIcon"] = _settings[[NSString stringWithFormat:@"backgrounder-%@-showStatusBarIcon",identifier]] ?: @YES;

	ret[@"backgroundModes"] = [NSMutableDictionary dictionary];
	ret[@"backgroundModes"][kBGModeUnboundedTaskCompletion] = _settings[[NSString stringWithFormat:@"backgrounder-%@-backgroundmodes-%@",identifier,kBGModeUnboundedTaskCompletion]] ?: @NO;
	ret[@"backgroundModes"][kBGModeContinuous] = _settings[[NSString stringWithFormat:@"backgrounder-%@-backgroundmodes-%@",identifier,kBGModeContinuous]] ?: @NO;
	ret[@"backgroundModes"][kBGModeFetch] = _settings[[NSString stringWithFormat:@"backgrounder-%@-backgroundmodes-%@",identifier,kBGModeFetch]] ?: @NO;
	ret[@"backgroundModes"][kBGModeRemoteNotification] = _settings[[NSString stringWithFormat:@"backgrounder-%@-backgroundmodes-%@",identifier,kBGModeRemoteNotification]] ?: @NO;
	ret[@"backgroundModes"][kBGModeExternalAccessory] = _settings[[NSString stringWithFormat:@"backgrounder-%@-backgroundmodes-%@",identifier,kBGModeExternalAccessory]] ?: @NO;
	ret[@"backgroundModes"][kBGModeVoIP] = _settings[[NSString stringWithFormat:@"backgrounder-%@-backgroundmodes-%@",identifier,kBGModeVoIP]] ?: @NO;
	ret[@"backgroundModes"][kBGModeLocation] = _settings[[NSString stringWithFormat:@"backgrounder-%@-backgroundmodes-%@",identifier,kBGModeLocation]] ?: @NO;
	ret[@"backgroundModes"][kBGModeAudio] = _settings[[NSString stringWithFormat:@"backgrounder-%@-backgroundmodes-%@",identifier,kBGModeAudio]] ?: @NO;
	ret[@"backgroundModes"][kBGModeBluetoothCentral] = _settings[[NSString stringWithFormat:@"backgrounder-%@-backgroundmodes-%@",identifier,kBGModeBluetoothCentral]] ?: @NO;
	ret[@"backgroundModes"][kBGModeBluetoothPeripheral] = _settings[[NSString stringWithFormat:@"backgrounder-%@-backgroundmodes-%@",identifier,kBGModeBluetoothPeripheral]] ?: @NO;

	[backgrounderSettingsCache setObject:ret forKey:identifier];

	return ret;
}

-(NSDictionary*) rawCompiledBackgrounderSettingsForIdentifier:(NSString*)identifier
{
	return [backgrounderSettingsCache objectForKey:identifier] ?: [self _createAndCacheBackgrounderSettingsForIdentifier:identifier];
}

-(BOOL) isFirstRun
{
	NSLog(@"[ReachApp] %d", BOOL(@"isFirstRun", YES));
	return BOOL(@"isFirstRun", YES);  
}

-(void) setFirstRun:(BOOL)value
{
	CFPreferencesSetAppValue(CFSTR("isFirstRun"), value ? kCFBooleanTrue : kCFBooleanFalse, CFSTR("com.efrederickson.reachapp.settings"));
	CFPreferencesAppSynchronize(CFSTR("com.efrederickson.reachapp.settings"));
	[self reloadSettings];
}

-(BOOL) alwaysShowSOGrabber { return BOOL(@"alwaysShowSOGrabber", NO); }

-(BOOL) swipeOverEnabled { return [self enabled] && BOOL(@"swipeOverEnabled", YES); }
-(BOOL) windowedMultitaskingEnabled { return [self enabled] && BOOL(@"windowedMultitaskingEnabled", YES); }
-(BOOL) exitAppAfterUsingActivatorAction { return BOOL(@"exitAppAfterUsingActivatorAction", YES); }
-(BOOL) windowedMultitaskingCompleteAnimations { return BOOL(@"windowedMultitaskingCompleteAnimations", NO); }
-(NSString*) currentThemeIdentifier { return _settings[@"currentThemeIdentifier"] ?: @"com.eljahandandrew.multiplexer.themes.default"; }
-(NSInteger) missionControlDesktopStyle { return [_settings[@"missionControlDesktopStyle"] ?: @1 intValue]; }
-(BOOL) missionControlPagingEnabled { return BOOL(@"missionControlPagingEnabled", NO); }
-(BOOL) showFavorites { return BOOL(@"showFavorites", YES); }
-(BOOL) onlyShowWindowBarIconsOnOverlay { return BOOL(@"onlyShowWindowBarIconsOnOverlay", NO); }
-(BOOL) quickAccessUseGenericTabLabel { return BOOL(@"quickAccessUseGenericTabLabel", NO); }
-(BOOL) ncAppHideOnLS { return BOOL(@"ncAppHideOnLS", NO); }
-(BOOL) showSnapHelper { return BOOL(@"showSnapHelper", NO); }

-(RAGrabArea) windowedMultitaskingGrabArea
{
	return [_settings objectForKey:@"windowedMultitaskingGrabArea"] == nil ? RAGrabAreaBottomLeftThird : (RAGrabArea)[_settings[@"windowedMultitaskingGrabArea"] intValue];
}

-(RAGrabArea) swipeOverGrabArea
{
	return [_settings objectForKey:@"swipeOverGrabArea"] == nil ? RAGrabAreaSideAnywhere : (RAGrabArea)[_settings[@"swipeOverGrabArea"] intValue];
}
@end