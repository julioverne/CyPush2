#import "CyPush.h"
#import <substrate.h>

static BOOL Enabled;
static BOOL onlyWiFi;
static BOOL intervalRefresh;
static BOOL useBadges;
static BOOL showUpdatesPackages;
static BOOL showAllChanges;
static BOOL showNewPackages;
static BOOL hideSectionTheme;
static BOOL hideSectionTweak;
static BOOL showStatus;
static BOOL useLibbulletin;
static BOOL showIgnoredUpdates;
static BOOL statusIsUpdatingCyPush;
static BOOL isCydiaOpened;
static BOOL reloadDataIsInProgress = YES;
static BOOL isLaunchedInBackground;

static BOOL canSystemSleep;
static float intervalCheck;
static NSTimeInterval launchedCyPushTimeStamp;
static io_connect_t gRootPort = MACH_PORT_NULL;
static io_object_t notifier;
static NSTimeInterval sheduleCreationCyPushTimeStamp;


static __strong NSString* kBudleCydia = @"com.saurik.Cydia";
static __strong NSString* kPkgPrefix1 = @"gsc.";
static __strong NSString* kPkgPrefix2 = @"cy+";
static __strong NSString* kFormatMessage = nil;

static BOOL firstCheck;

#define GetElement(key) [key isKindOfClass:[NSNull class]]||key==nil?@"":key

#define NSLog(...)

@interface NSObject ()
+ (id)shared;
@end

static void updateTimer(int afterSeconds)
{
	@try {
		float updatedInterval;
		@autoreleasepool {
			NSTimeInterval timeStampNow = [[NSDate date] timeIntervalSince1970];
			updatedInterval = (float)((sheduleCreationCyPushTimeStamp-timeStampNow)+afterSeconds);
			NSLog(@"*** updateTimer() timer adjusted to %f", updatedInterval);
		}
		[NSObject cancelPreviousPerformRequestsWithTarget:[%c(CyPushSB) shared] selector:@selector(activator:receiveEvent:) object:nil];
		[[%c(CyPushSB) shared] performSelector:@selector(activator:receiveEvent:) withObject:nil afterDelay:updatedInterval];
	}@catch (NSException * e) {
		updateTimer(afterSeconds);
	}
}
static void sheduleWakeAndCheckAfterSeconds(int afterSeconds)
{
	@try {
		@autoreleasepool {
			NSArray* eventsArray = [(__bridge NSArray*)IOPMCopyScheduledPowerEvents()?:@[] copy];
			for(NSDictionary* shEventNow in eventsArray) {
				if(CFStringRef scheduledbyID = (__bridge CFStringRef)shEventNow[@"scheduledby"]) {
					if([[NSString stringWithFormat:@"%@", scheduledbyID] isEqualToString:@"com.julioverne.cypush"]) {
						IOPMCancelScheduledPowerEvent((__bridge CFDateRef)shEventNow[@"time"], (__bridge CFStringRef)shEventNow[@"scheduledby"], (__bridge CFStringRef)shEventNow[@"eventtype"]);
					}
				}
			}
		}
		NSDate *wakeTime = [[NSDate date] dateByAddingTimeInterval:(afterSeconds - 10)];
		IOPMSchedulePowerEvent((__bridge CFDateRef)wakeTime, CFSTR("com.julioverne.cypush"), CFSTR(kIOPMAutoWake));
		sheduleCreationCyPushTimeStamp = [[NSDate date] timeIntervalSince1970];
		updateTimer(afterSeconds);
	}@catch (NSException * e) {
		sheduleWakeAndCheckAfterSeconds(afterSeconds);
	}
}
static BOOL isPendingSchedule()
{
	BOOL ret = NO;
	@try {
		@autoreleasepool {
			NSArray* eventsArray = [(__bridge NSArray*)IOPMCopyScheduledPowerEvents()?:@[] copy];
			for(NSDictionary* shEventNow in eventsArray) {
				if(CFStringRef scheduledbyID = (__bridge CFStringRef)shEventNow[@"scheduledby"]) {
					if([[NSString stringWithFormat:@"%@", scheduledbyID] isEqualToString:@"com.julioverne.cypush"]) {
						ret = YES;
						break;
					}
				}
			}
		}
	}@catch (NSException * e) {
		return isPendingSchedule();
	}
	return ret;
}


static void exitCyPush()
{
	NSLog(@"*** Killing CyPush...");
	if(notifier) {
		IODeregisterForSystemPower(&notifier);
		notifier = 0;
	}
	notify_post("com.julioverne.cypush/Exit");
}

%group HooksCydia

@implementation NSString (cypush)
+ (NSString *)encodeBase64WithString:(NSString *)strData
{
    return [self encodeBase64WithData:[strData dataUsingEncoding:NSUTF8StringEncoding]];
}
+ (NSString*)encodeBase64WithData:(NSData*)theData
{
    const uint8_t* input = (const uint8_t*)[theData bytes];
    NSInteger length = [theData length];
    static char table[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";
    NSMutableData* data = [NSMutableData dataWithLength:((length + 2) / 3) * 4];
    uint8_t* output = (uint8_t*)data.mutableBytes;
    NSInteger i;
    for (i=0; i < length; i += 3) {
		NSInteger value = 0;
		NSInteger j;
		for (j = i; j < (i + 3); j++) {
			value <<= 8;
			if (j < length) {
				value |= (0xFF & input[j]);
			}
		}
		NSInteger theIndex = (i / 3) * 4;
		output[theIndex + 0] =			  table[(value >> 18) & 0x3F];
		output[theIndex + 1] =			  table[(value >> 12) & 0x3F];
		output[theIndex + 2] = (i + 1) < length ? table[(value >> 6)  & 0x3F] : '=';
		output[theIndex + 3] = (i + 2) < length ? table[(value >> 0)  & 0x3F] : '=';
    }
    return [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
}
@end

static _finline void UpdateExternalStatus(uint64_t newStatus) {
    int notify_token;
    if (notify_register_check("com.julioverne.cypush.status", &notify_token) == NOTIFY_STATUS_OK) {
        notify_set_state(notify_token, newStatus);
        notify_cancel(notify_token);
    }
    notify_post("com.julioverne.cypush.status");
}

static void actionUpdateNow(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	if([CyPush sharedExist]) {
		[[CyPush shared] RunUpdates];
	}	
}
@implementation CyPush
static __strong CyPush *CyPushC;
- (void)run_this
{
	NSLog(@"------ CyPush RUN -----");
	/*if(intervalRefresh) {
		[NSTimer scheduledTimerWithTimeInterval:intervalCheck target:CyPushC selector:@selector(RunUpdates) userInfo:nil repeats:YES];
	}*/
	return;
}
+ (id) shared
{	
	if (!CyPushC) {
		CyPushC = [[self alloc] init];
		CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, actionUpdateNow, CFSTR("com.julioverne.cypush/UpdateNow"), NULL, CFNotificationSuspensionBehaviorCoalesce);
	}
	return CyPushC;
}
+ (BOOL)sharedExist
{
	if(CyPushC) {
		return YES;
	}
	return NO;
}
- (void)showBanner:(NSDictionary*)userInfo
{
	@try{
	@autoreleasepool {
		if(!userInfo) {
			return;
		}
		if(useLibbulletin) {
			CPDistributedMessagingCenter* messagingCenter = [CPDistributedMessagingCenter centerNamed: @"com.julioverne.cypush"];
			[messagingCenter sendMessageName:@"showBanner:userInfo:" userInfo:userInfo];
		} else {
			NSString*messages = userInfo[@"message"];
			NSString*packageId = userInfo[@"id"]?:@"";
			if(messages && packageId) {
				NSString* encodedMessage = [NSString encodeBase64WithString:messages];
				NSString* encodedPackageId = [NSString encodeBase64WithString:packageId];
				if(encodedMessage && encodedPackageId) {
					[(Cydia*)[[UIApplication sharedApplication] delegate] system:[[NSString stringWithFormat:@"%@ %@", @"/usr/libexec/cydia/cydo", @"/Library/PreferenceBundles/CyPushSettings.bundle/cypushchk"] stringByAppendingString:[NSString stringWithFormat:@" -m \"%@\" \"%@\"", encodedMessage, encodedPackageId]]];
				}
			}
		}
	}
	} @catch (NSException * e) {
	}
}
- (void)updateBadges
{
	if(!useBadges) {
		return;
	}
	@autoreleasepool {
		NSDictionary *PrefsCheck = [[NSDictionary alloc] initWithContentsOfFile:@PLIST_PATH_Settings]?:@{};
		int badger = [PrefsCheck[@"badger"]?:@(0) intValue];
		[UIApplication sharedApplication].applicationIconBadgeNumber = badger;
	}
}
- (void)RunUpdates
{
	NSLog(@"------ CyPush RunUpdates()");
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_RunUpdates) object:nil];
	[self performSelector:@selector(_RunUpdates) withObject:nil afterDelay:0.5f];
}
- (void)_RunUpdates
{
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
		@try{
		@autoreleasepool {
		NSLog(@"------ CyPush RunUpdates ----- %@", @"START");
		if(isRunningRunUpdated) {
			NSLog(@"------ CyPush RunUpdates ----- %@", @"isRunningRunUpdated==TRUE Skip...");
			return;
		}
		if(reloadDataIsInProgress) {
			NSLog(@"------ Cydia> ReloadDataIsInProgress... Skip");
			return;
		}
		if(isCydiaOpened) {
			NSLog(@"------ CyPush RunUpdates ----- %@", @"Cydia Is Opened Skip...");
			UpdateExternalStatus(0);
			return;
		}
		isRunningRunUpdated = YES;
		UpdateExternalStatus(1);
		
		if(NSDictionary *reply = [[CPDistributedMessagingCenter centerNamed: @"com.julioverne.cypush"] sendMessageAndReceiveReplyName:@"connectionStatus:userInfo:" userInfo:nil]) {
			if(id ConType = [reply objectForKey:@"connectionType"]) {
				ConnectionType status = (ConnectionType)[ConType intValue];				
				if( (status==ConnectionTypeUnknown||status==ConnectionTypeNone) || (onlyWiFi&&status!=ConnectionTypeWiFi) ) {
					NSLog(@"------ CyPush RunUpdates ----- %@", @"Connection Type Not Satisfy Skip...");
					isRunningRunUpdated = NO;
					UpdateExternalStatus(0);
					if(!isCydiaOpened) {
						exitCyPush();
					}
					return;
				}
			}
		}
		
		if(showStatus) {
			[self showBanner:@{@"message": [[NSBundle mainBundle] localizedStringForKey:@"UPDATING_SOURCES" value:@"Updating Sources" table:nil]}];
		}
		NSLog(@"------ CyPush RunUpdates ----- %@", @"Request Updated...");		
		[(Database*)[%c(Database) sharedInstance] update];
		NSLog(@"------ CyPush RunUpdates ----- %@", @"Request Updated...DONE");
		
		//if(showStatus) {
		//	[self showBanner:@{@"message": @"Requesting Reload Data..."}];
		//}
		NSLog(@"------ CyPush RunUpdates ----- %@", @"Request Reload Data...");
		[(NSObject*)[[%c(UIApplication) sharedApplication] delegate] performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
		NSLog(@"------ CyPush RunUpdates ----- %@", @"Request Reload Data...DONE");
		
		//if(showStatus) {
		//	[self showBanner:@{@"message": @"Checking Packages..."}];
		//}
		NSLog(@"------ CyPush RunUpdates ----- %@", @"LOOP FOR FIND PKGs...");
		NSArray* packages([(Database*)[%c(Database) sharedInstance] packages]);
		
		time_t now_ = [[NSDate date] timeIntervalSince1970];
		int totalBanner = 0;
		for(size_t offset = 0, count = [packages count]; offset != count; ++offset) {
			@autoreleasepool {
				BOOL showBanner = NO;
				id packageOption = nil;
				
				Package *package = [packages objectAtIndex:offset];
				PackageValue *metadata([package metadata]);
				
				if(showUpdatesPackages&& [package upgradableAndEssential:YES]) {
					packageOption = [[NSBundle mainBundle] localizedStringForKey:@"UPGRADE" value:@"Upgrade" table:nil];
					showBanner = YES;
					showBanner = showIgnoredUpdates?YES:![package ignored];
				} else if(showNewPackages&& ( (metadata->first_ > 0) && ((now_ - metadata->first_) < 18000) ) &&(metadata->first_==metadata->last_) ) {
					packageOption = [[NSBundle mainBundle] localizedStringForKey:@"NEW" value:@"New" table:nil];
					showBanner = YES;
				} else if(showAllChanges&& ( (metadata->last_ > 0) && ((now_ - metadata->last_) < 18000) &&(metadata->last_>metadata->first_) ) ) {
					packageOption = [[NSBundle mainBundle] localizedStringForKey:@"CHANGES" value:@"Changes" table:nil];
					showBanner = YES;
				}
				
				if(showBanner) {
					BOOL showBan = YES;
					[package parse];
					
					NSString* pkg_id = @"";
					@try { pkg_id = [GetElement([package id]) copy]; } @catch (NSException * e) { }
					
					NSString* packageHash = @"";
					@try {
						packageHash = [GetElement([package getField:@"MD5sum"]) copy];
					} @catch (NSException * e) {
						@try {
							packageHash = [GetElement([package getField:@"SHA1"]) copy];
						} @catch (NSException * e) {
							@try {
								packageHash = [GetElement([package getField:@"SHA256"]) copy];
							} @catch (NSException * e) {
								packageHash = @"";
							}
						}
					}
					
					NSString* packageSection = @"";
					@try { packageSection = [GetElement([package longSection]) copy]; } @catch (NSException * e) { }
					if(hideSectionTheme||hideSectionTweak) {
						if(hideSectionTheme) {
							if([[packageSection lowercaseString] rangeOfString:@"theme"].location != NSNotFound) {
								showBan = NO;
							}
						}
						if(hideSectionTweak) {
							if([[packageSection lowercaseString] rangeOfString:@"tweak"].location != NSNotFound) {
								showBan = NO;
							}
						}
					}
					
					NSString* version = @"";
					@try { version = [GetElement([package latest]) copy]; } @catch (NSException * e) { }
					
					NSString* sourceName = @"";
					@try {
						Source* source = [package source];
						if(source && ![source isKindOfClass:[NSNull class]]) {
							sourceName = [GetElement([source name]) copy];
						}
					} @catch (NSException * e) { }
					
					NSString* authorName = @"";
					@try {
						MIMEAddress* author = [package author];
						if(author && ![author isKindOfClass:[NSNull class]]) {
							authorName = [GetElement([author name]) copy];
						}
					} @catch (NSException * e) { }
					
					if(showBan && ![pkg_id hasPrefix:kPkgPrefix1] && ![pkg_id hasPrefix:kPkgPrefix2]) {
						NSMutableDictionary *PrefsCheck = [[NSMutableDictionary alloc] initWithContentsOfFile:@PLIST_PATH_Upgrades]?:[NSMutableDictionary dictionary];
						
						NSString* keyUnique = [NSString stringWithFormat:@"%@-%@-%@", pkg_id, version, packageHash];
						NSLog(@"------ CyPush RunUpdates ----- %@", [NSString stringWithFormat:@"PKG: %@ showBanner: %@", pkg_id, @(showBanner)]);
						
						if([PrefsCheck objectForKey:keyUnique]==nil) {
							[PrefsCheck setObject:@YES forKey:keyUnique];
							[PrefsCheck writeToFile:@PLIST_PATH_Upgrades atomically:YES];
							
							NSString *name,*shortDescription;
							
							@try { name = [GetElement([package name]) copy]; } @catch (NSException * e) { }
							@try { shortDescription = [GetElement([package shortDescription]) copy]; } @catch (NSException * e) { }
							
							BOOL isCommercial = NO;
							@try { isCommercial = [package isCommercial]; } @catch (NSException * e) { }
							
							NSString *massageFormat = [kFormatMessage copy];
							massageFormat = [massageFormat stringByReplacingOccurrencesOfString:@"$#status" withString:[NSString stringWithFormat:@"%@", packageOption]];
							massageFormat = [massageFormat stringByReplacingOccurrencesOfString:@"$#price" withString:[NSString stringWithFormat:@"%@", isCommercial?@"💰":@""]];
							massageFormat = [massageFormat stringByReplacingOccurrencesOfString:@"$#version_name" withString:[NSString stringWithFormat:@"%@", [[NSBundle mainBundle] localizedStringForKey:@"VERSION" value:@"Version" table:nil]]];
							massageFormat = [massageFormat stringByReplacingOccurrencesOfString:@"$#hash" withString:[NSString stringWithFormat:@"%@", packageHash]];
							massageFormat = [massageFormat stringByReplacingOccurrencesOfString:@"$#version" withString:[NSString stringWithFormat:@"%@", version]];
							massageFormat = [massageFormat stringByReplacingOccurrencesOfString:@"$#id" withString:[NSString stringWithFormat:@"%@", pkg_id]];
							massageFormat = [massageFormat stringByReplacingOccurrencesOfString:@"$#section" withString:[NSString stringWithFormat:@"%@", packageSection]];
							massageFormat = [massageFormat stringByReplacingOccurrencesOfString:@"$#source" withString:[NSString stringWithFormat:@"%@", sourceName]];
							massageFormat = [massageFormat stringByReplacingOccurrencesOfString:@"$#author" withString:[NSString stringWithFormat:@"%@", authorName]];
							massageFormat = [massageFormat stringByReplacingOccurrencesOfString:@"$#name" withString:[NSString stringWithFormat:@"%@", name]];
							massageFormat = [massageFormat stringByReplacingOccurrencesOfString:@"$#description" withString:[NSString stringWithFormat:@"%@", shortDescription]];
							
							[self showBanner:@{
								@"id": pkg_id,
								@"message": massageFormat,
								@"iconData": UIImagePNGRepresentation([package icon]),
								@"hash": packageHash,
							}];
							totalBanner++;
						}
					}
				}
			}
		}
		
		NSMutableDictionary *PrefsCheck = [[NSMutableDictionary alloc] initWithContentsOfFile:@PLIST_PATH_Settings]?:[NSMutableDictionary dictionary];
		int badger = [PrefsCheck[@"badger"]?:@(0) intValue];
		badger += totalBanner;
		if(badger!=0) {
			PrefsCheck[@"badger"] = @(badger);
			[PrefsCheck writeToFile:@PLIST_PATH_Settings atomically:YES];
		}
		[self updateBadges];
		
		if(showStatus) {
			[self showBanner:@{@"message": [NSString stringWithFormat:@"%@ %@", [[NSBundle mainBundle] localizedStringForKey:@"DONE" value:@"Done" table:nil], totalBanner>0?[NSString stringWithFormat:@"%@ %@", @(totalBanner), [[NSBundle mainBundle] localizedStringForKey:@"PACKAGES" value:@"Packages" table:nil]]:@"Without News"]}];
		}
		NSLog(@"------ CyPush RunUpdates ----- %@", @"LOOP FOR FIND PKGs...DONE");
		
		NSLog(@"------ CyPush RunUpdates ----- %@", @"END");
		isRunningRunUpdated = NO;
		UpdateExternalStatus(0);
		if(!isCydiaOpened) {
			exitCyPush();
		}
		}
		} @catch (NSException * e) {	
		}
	});
}
@end
%hook Database
- (BOOL) popErrorWithTitle:(NSString *)title
{
	if(title&&Enabled&&!isCydiaOpened) {
		static __strong NSString *titleLoc([[NSBundle mainBundle] localizedStringForKey:@"REFRESHING_DATA" value:nil table:nil]);
		if([title isEqualToString:titleLoc]) {
			return NO;
		}
	}
	BOOL ret(%orig(title));
	return ret;
}
%end
%hook Cydia
- (id)init
{
	id ret = %orig;
	[self system:[NSString stringWithFormat:@"%@ %@", @"/usr/libexec/cydia/cydo", @"/Library/PreferenceBundles/CyPushSettings.bundle/cypushchk"]];
	[[UIApplication sharedApplication] setIdleTimerDisabled:YES];
	UIApplicationState state = [[UIApplication sharedApplication] applicationState];
	if (state==UIApplicationStateBackground || state==UIApplicationStateInactive) {
		isLaunchedInBackground = YES;
		isCydiaOpened = NO;
		if(!firstCheck) {
			if(intervalRefresh) {
				canSystemSleep = NO;
			}
			[[%c(CyPush) shared] run_this];
		}		
	}
	return ret;
}
- (BOOL)isSafeToSuspend
{
	return NO;
}
%new
- (void)exitCyPushLimit
{
	exitCyPush();
}
- (void)applicationDidEnterBackground:(UIApplication *)application
{
	%orig;
	isCydiaOpened = NO;
	[[UIApplication sharedApplication] setIdleTimerDisabled:YES];
	[[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:NULL];
	
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(exitCyPushLimit) object:nil];
	[self performSelector:@selector(exitCyPushLimit) withObject:nil afterDelay:600.0f]; // 10min background limit
}
- (void)reloadDataWithInvocation:(NSInvocation *)invocation
{
	reloadDataIsInProgress = YES;
	%orig;
	reloadDataIsInProgress = NO;
	
	[[%c(CyPush) shared] updateBadges];
	
	UIApplicationState state = [[UIApplication sharedApplication] applicationState];
	if (!firstCheck) {
		firstCheck = YES;
		if(intervalRefresh&&isLaunchedInBackground&&(state==UIApplicationStateBackground || state==UIApplicationStateInactive)) {
			[[%c(CyPush) shared] performSelector:@selector(RunUpdates) withObject:nil afterDelay:0.1f];
		}
	}
}

- (void)applicationDidFinishLaunching:(id)application
{
	%orig;	
	if([application respondsToSelector:@selector(registerUserNotificationSettings:)]) {
		[application registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:(UIUserNotificationTypeSound | UIUserNotificationTypeAlert | UIUserNotificationTypeBadge) categories:nil]];
		[application registerForRemoteNotifications];
	} else {
		[application registerForRemoteNotificationTypes:(UIUserNotificationTypeBadge | UIUserNotificationTypeSound | UIUserNotificationTypeAlert)];
	}
	
	notify_post("com.julioverne.cypush/Launched");
}

%new
- (void)applicationDidBecomeActive:(UIApplication *)application
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(exitCyPushLimit) object:nil];
	isCydiaOpened = YES;
	@autoreleasepool {
		NSMutableDictionary *PrefsCheck = [[NSMutableDictionary alloc] initWithContentsOfFile:@PLIST_PATH_Settings]?:[NSMutableDictionary dictionary];
		int badger = [PrefsCheck[@"badger"]?:@(0) intValue];
		if(badger!=0) {
			PrefsCheck[@"badger"] = @(0);
			[PrefsCheck writeToFile:@PLIST_PATH_Settings atomically:YES];
		}
	}
	[[%c(CyPush) shared] updateBadges];
}
- (void)_handleNonLaunchSpecificActions:(NSSet*)arg1 forScene:(id)arg2 withTransitionContext:(id)arg3 completion:(id)arg4
{
	@try{
	if(arg1 && [arg1 isKindOfClass:[NSSet class]]) {
		NSArray* actions = [arg1 allObjects];
		
		for(UIHandleLocalNotificationAction* action in actions) {
			if([action respondsToSelector:@selector(notification)]) {
				if(UILocalNotification* notifi = [action notification]) {
					if([notifi respondsToSelector:@selector(userInfo)]) {
						if(NSDictionary* userIn = [notifi userInfo]) {
							if([userIn respondsToSelector:@selector(objectForKey:)]) {
								if(NSString* packageId = [userIn objectForKey:@"package"]) {
									dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
										NSString* cpPkgID = packageId?[packageId copy]:nil;
										do {
											sleep(1/4);
										} while(reloadDataIsInProgress);
										dispatch_async(dispatch_get_main_queue(), ^(){
										if (cpPkgID&&[(Cydia*)[UIApplication sharedApplication] openCydiaURL:[NSURL URLWithString:[[[@"cydia://" stringByAppendingString:@"package"] stringByAppendingString:@"/"] stringByAppendingString:cpPkgID]] forExternal:YES]) {
											
										}
										});
									});
								}
							}
						}
					}
				}
			} else if([action respondsToSelector:@selector(response)]) {
				if(UNNotificationResponse* notifiResp = [(UINotificationResponseAction*)action response]) {
					if([notifiResp respondsToSelector:@selector(notification)]) {
						if(UNNotification* notifi = [notifiResp notification]) {
							if([notifi respondsToSelector:@selector(request)]) {
								if(UNNotificationRequest* notifiReq = [notifi request]) {
									if([notifiReq respondsToSelector:@selector(content)]) {
										if(UNNotificationContent* notifiCont = [notifiReq content]) {
											if([notifiCont respondsToSelector:@selector(userInfo)]) {
												if(NSDictionary* userIn = [notifiCont userInfo]) {
													if([userIn respondsToSelector:@selector(objectForKey:)]) {
														if(NSString* packageId = [userIn objectForKey:@"package"]) {
															dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
																NSString* cpPkgID = packageId?[packageId copy]:nil;
																do {
																	sleep(1/4);
																} while(reloadDataIsInProgress);
																dispatch_async(dispatch_get_main_queue(), ^(){
																if (cpPkgID&&[(Cydia*)[UIApplication sharedApplication] openCydiaURL:[NSURL URLWithString:[[[@"cydia://" stringByAppendingString:@"package"] stringByAppendingString:@"/"] stringByAppendingString:cpPkgID]] forExternal:YES]) {
																	
																}
																});
															});
														}
													}
												}
											}
										}
									}
								}
							}
						}
					}
				}
			}
			break;
		}
	}
	} @catch (NSException * e) {	
	}
	%orig;
}
%end
%end


%group HooksSB

#import <libactivator/libactivator.h>
#import <Flipswitch/Flipswitch.h>
@interface CyPushSB : NSObject <FSSwitchDataSource>
{
	CPDistributedMessagingCenter *_dmc;
}
+ (id)shared;
- (void)run_this;
- (void)RegisterActions;
@end
static void stateChangedSW(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	if(%c(FSSwitchPanel) != nil) {
		[[%c(FSSwitchPanel) sharedPanel] stateDidChangeForSwitchIdentifier:@"com.julioverne.cypushswitch"];
	}	
}
@implementation CyPushSB
- (void)run_this
{
	NSLog(@"------ CyPushSB RUN -----");
	return;
}
+ (ConnectionType)connectionType
{
    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithName(NULL, "8.8.8.8");
    SCNetworkReachabilityFlags flags;
    BOOL success = SCNetworkReachabilityGetFlags(reachability, &flags);
    CFRelease(reachability);
    if (!success) {
		return ConnectionTypeUnknown;
    }
    BOOL isReachable = ((flags & kSCNetworkReachabilityFlagsReachable) != 0);
    BOOL needsConnection = ((flags & kSCNetworkReachabilityFlagsConnectionRequired) != 0);
    BOOL isNetworkReachable = (isReachable && !needsConnection);
    if (!isNetworkReachable) {
		return ConnectionTypeNone;
    } else if ((flags & kSCNetworkReachabilityFlagsIsWWAN) != 0) {
		return ConnectionType3G;
    } else {
		return ConnectionTypeWiFi;
    }
}
+ (id) shared
{
	static __strong CyPushSB *CyPushSB;
	if (!CyPushSB) {
		CyPushSB = [[self alloc] init];
		CyPushSB->_dmc = [CPDistributedMessagingCenter centerNamed: @"com.julioverne.cypush"];
		[CyPushSB->_dmc runServerOnCurrentThread];
		[CyPushSB->_dmc registerForMessageName:@"showBanner:userInfo:" target:CyPushSB selector:@selector(showBanner:userInfo:)];
		[CyPushSB->_dmc registerForMessageName:@"connectionStatus:userInfo:" target:CyPushSB selector:@selector(connectionStatus:userInfo:)];
		CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, stateChangedSW, CFSTR("com.julioverne.cypush.status"), NULL, CFNotificationSuspensionBehaviorCoalesce);
		[CyPushSB RegisterActions];
	}
	return CyPushSB;
}
- (NSDictionary *)connectionStatus:(NSString *)name userInfo:(NSDictionary *)userinfo
{
	@autoreleasepool {
		return @{@"connectionType": @([CyPushSB connectionType])};
	}
}
- (void)showBanner:(NSString*)message userInfo:(NSDictionary*)userInfo
{
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		@try {
			@autoreleasepool {
				NSData*iconData(userInfo[@"iconData"]);
				UIImage*icon(iconData?[UIImage imageWithData:iconData]:nil);
				NSString*messages(userInfo[@"message"]);
				if(messages) {
					[(JBBulletinManager*)[objc_getClass("JBBulletinManager") sharedInstance] showBulletinWithTitle:@"Cydia" message:messages bundleID:nil hasSound:NO soundID:0 vibrateMode:0 soundPath:nil attachmentImage:nil overrideBundleImage:icon];
				}				
			}
		} @catch (NSException * e) {	
		}
	});
}
- (void)RegisterActions
{
    if (access("/usr/lib/libactivator.dylib", F_OK) == 0) {
		dlopen("/usr/lib/libactivator.dylib", RTLD_LAZY);
	    if (Class la = objc_getClass("LAActivator")) {
			[[la sharedInstance] registerListener:(id<LAListener>)self forName:@"com.julioverne.cypush"];
		}
	}
}
- (NSString *)activator:(LAActivator *)activator requiresLocalizedTitleForListenerName:(NSString *)listenerName
{
	return @"CyPush2";
}
- (NSString *)activator:(LAActivator *)activator requiresLocalizedDescriptionForListenerName:(NSString *)listenerName
{
	return @"Make Cydia Refresh Sources";
}
- (UIImage *)activator:(LAActivator *)activator requiresIconForListenerName:(NSString *)listenerName scale:(CGFloat)scale
{
    static __strong UIImage* listenerIcon;
    if (!listenerIcon) {
		listenerIcon = [[UIImage alloc] initWithContentsOfFile:[[NSBundle bundleWithPath:@"/Library/PreferenceBundles/CyPushSettings.bundle"] pathForResource:scale==2.0f?@"icon@2x":@"icon" ofType:@"png"]];
	}
    return listenerIcon;
}
- (UIImage *)activator:(LAActivator *)activator requiresSmallIconForListenerName:(NSString *)listenerName scale:(CGFloat)scale
{
    static __strong UIImage* listenerIcon;
    if (!listenerIcon) {
		listenerIcon = [[UIImage alloc] initWithContentsOfFile:[[NSBundle bundleWithPath:@"/Library/PreferenceBundles/CyPushSettings.bundle"] pathForResource:scale==2.0f?@"icon@2x":@"icon" ofType:@"png"]];
	}
    return listenerIcon;
}
- (void)activator:(LAActivator *)activator receiveEvent:(LAEvent *)event
{
	notify_post("com.julioverne.cypush/Check");
	notify_post("com.julioverne.cypush/UpdateNow");
}
- (FSSwitchState)stateForSwitchIdentifier:(NSString *)switchIdentifier
{
	return statusIsUpdatingCyPush?FSSwitchStateOn:FSSwitchStateIndeterminate;
}
- (void)applyActionForSwitchIdentifier:(NSString *)switchIdentifier
{
	[self activator:nil receiveEvent:nil];
}
- (void)applyAlternateActionForSwitchIdentifier:(NSString *)switchIdentifier
{
	[[%c(FSSwitchPanel) sharedPanel] openURLAsAlternateAction:[NSURL URLWithString:@"prefs:root=CyPush2"]];
}
@end

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application
{
	%orig;
	sheduleWakeAndCheckAfterSeconds(5);
}
%end

%hook FBApplicationInfo
- (BOOL)supportsBackgroundMode:(id)arg1
{
	BOOL ret = %orig;
	if(self.bundleIdentifier&&[self.bundleIdentifier isEqualToString:kBudleCydia]&&(arg1 &&[arg1 isEqualToString:@"continuous"])) {
		NSLog(@"*** FBApplicationInfo>supportsBackgroundMode: %@", arg1);
		ret = YES;		
	}
	return ret;
}
%end

%end


static void HandlePowerManagerEvent(void *inContext, io_service_t inIOService, natural_t inMessageType, void *inMessageArgument)
{
    if(inMessageType == kIOMessageSystemWillSleep) {
		IOAllowPowerChange(gRootPort, (long)inMessageArgument);
		NSLog(@"*** kIOMessageSystemWillSleep");
	} else if(inMessageType == kIOMessageCanSystemSleep) {
		if(canSystemSleep) {
			IOAllowPowerChange(gRootPort, (long)inMessageArgument);
		} else {
			IOCancelPowerChange(gRootPort, (long)inMessageArgument);
		}
		NSLog(@"*** kIOMessageCanSystemSleep %@", @(canSystemSleep));
	} else if(inMessageType == kIOMessageSystemHasPoweredOn) {
		NSLog(@"*** kIOMessageSystemHasPoweredOn");
		updateTimer(intervalCheck);
		if(!isPendingSchedule()) {
			canSystemSleep = NO;
		}
	}
}
static void preventSystemSleep()
{
	IONotificationPortRef notify;
	gRootPort = IORegisterForSystemPower(NULL, &notify, HandlePowerManagerEvent, &notifier);
    if(gRootPort == MACH_PORT_NULL) {
        NSLog (@"IORegisterForSystemPower failed.");
    } else {
        CFRunLoopAddSource(CFRunLoopGetCurrent(), IONotificationPortGetRunLoopSource(notify), kCFRunLoopDefaultMode);
    }
}


static void notifyCyPushNeedKilled(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	@try{
	@autoreleasepool {
		SBApplicationController* controller = [%c(SBApplicationController) sharedInstance];
		SBApplication* sbapp = [controller applicationWithBundleIdentifier:@"com.saurik.Cydia"];
		BOOL isAppRunning = [sbapp respondsToSelector:@selector(isRunning)]?[sbapp isRunning]:[[controller runningApplications] containsObject:sbapp];
		if(sbapp&&isAppRunning) {
			FBApplicationProcess* SBProc = MSHookIvar<FBApplicationProcess *>(sbapp, "_process");
			[SBProc killForReason:1 andReport:NO withDescription:nil completion:nil];
			
			//void (*BKSTerminateApplicationForReasonAndReportWithDescription)(NSString *, int, bool, NSString *) = (void (*)(NSString *, int, bool, NSString *))(dlsym(RTLD_DEFAULT, "BKSTerminateApplicationForReasonAndReportWithDescription"));
			//BKSTerminateApplicationForReasonAndReportWithDescription(@"com.saurik.Cydia", 5, 1, NULL);
			NSLog(@"*** CyPush Killed...");
			return;
		}
		NSLog(@"*** CyPush No Process to be Killed... //isRunning:%@", @([sbapp isRunning]));
	}
	}@catch (NSException * e) {
	}
}
static void notifyCyPushLaunched(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	@autoreleasepool {
		canSystemSleep = YES;
		launchedCyPushTimeStamp = [[NSDate date] timeIntervalSince1970];
		NSLog(@"*** CyPush Launched...");
	}
}

extern "C" int SBSLaunchApplicationWithIdentifier(CFStringRef identifier, Boolean suspended);

static void cyPushCheckRun(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	@try{
	@autoreleasepool {
		sheduleWakeAndCheckAfterSeconds(intervalCheck);
		if(!Enabled || !intervalRefresh) {
			canSystemSleep = YES;
		} else {
			NSLog(@"*** CyPush Execution...");
			SBApplicationController* controller = [%c(SBApplicationController) sharedInstance];
			SBApplication* sbapp = [controller applicationWithBundleIdentifier:@"com.saurik.Cydia"];
			BOOL isAppRunning = [sbapp respondsToSelector:@selector(isRunning)]?[sbapp isRunning]:[[controller runningApplications] containsObject:sbapp];
			if(sbapp&&isAppRunning) {
				NSLog(@"*** PASS> CyPush is Running...");
				canSystemSleep = YES;
			} else {
				//[[UIApplication sharedApplication] launchApplicationWithIdentifier:@"com.saurik.Cydia" suspended:YES];
				dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
					SBSLaunchApplicationWithIdentifier(CFSTR("com.saurik.Cydia"), YES);
				});
			}
		}
	}
	}@catch (NSException * e) {
	}
}



static void settingsChangedCyPush(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	@autoreleasepool {
		NSDictionary *CyPushPrefs = [[[NSDictionary alloc] initWithContentsOfFile:@PLIST_PATH_Settings]?:@{} copy];
		Enabled = (BOOL)([CyPushPrefs[@"Enabled"]?:@YES boolValue]);
		onlyWiFi = (BOOL)([CyPushPrefs[@"onlyWiFi"]?:@YES boolValue]);
		intervalRefresh = (BOOL)([CyPushPrefs[@"intervalRefresh"]?:@YES boolValue]);
		float newIntervalCheck = (float)([CyPushPrefs[@"pulseTimer"]?:@(60.0) floatValue]*60.0f);
		if(strcmp(__progname, "Cydia") != 0) {
			if(intervalCheck!=0 && intervalCheck!=newIntervalCheck) {
				intervalCheck = newIntervalCheck;
				sheduleWakeAndCheckAfterSeconds(intervalCheck);
			}
		}
		intervalCheck = newIntervalCheck;
		showUpdatesPackages = (BOOL)([CyPushPrefs[@"showUpdatesPackages"]?:@YES boolValue]);
		showIgnoredUpdates = (BOOL)([CyPushPrefs[@"showIgnoredUpdates"]?:@YES boolValue]);
		showAllChanges = (BOOL)([CyPushPrefs[@"showAllChanges"]?:@NO boolValue]);
		showNewPackages = (BOOL)([CyPushPrefs[@"showNewPackages"]?:@NO boolValue]);
		useBadges = (BOOL)([CyPushPrefs[@"useBadges"]?:@YES boolValue]);
		kFormatMessage = (NSString*)([CyPushPrefs[@"FormatMessage"]?:@"$#status: $#name $#version $#price – $#section ($#source)" copy]);
		hideSectionTheme = (BOOL)([CyPushPrefs[@"hideSectionTheme"]?:@NO boolValue]);
		hideSectionTweak = (BOOL)([CyPushPrefs[@"hideSectionTweak"]?:@NO boolValue]);
		showStatus = (BOOL)([CyPushPrefs[@"showStatus"]?:@NO boolValue]);
		useLibbulletin = (BOOL)([CyPushPrefs[@"useLibbulletin"]?:@NO boolValue]);
	}
}
static void statusChangedCyPush(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	@autoreleasepool {
		uint64_t status = 0;
		int notify_token;
		if (notify_register_check("com.julioverne.cypush.status", &notify_token) == NOTIFY_STATUS_OK) {
			notify_get_state(notify_token, &status);
			notify_cancel(notify_token);
		}
		statusIsUpdatingCyPush = status!=0?YES:NO;
		canSystemSleep = !statusIsUpdatingCyPush;
	}
}



static void HandlePowerManagerEventCyPush(void *inContext, io_service_t inIOService, natural_t inMessageType, void *inMessageArgument)
{
    if(inMessageType == kIOMessageSystemWillSleep) {
		IOAllowPowerChange(gRootPort, (long)inMessageArgument);
		NSLog(@"*** kIOMessageSystemWillSleep");
	} else if(inMessageType == kIOMessageCanSystemSleep) {
		if(canSystemSleep) {
			IOAllowPowerChange(gRootPort, (long)inMessageArgument);
		} else {
			IOCancelPowerChange(gRootPort, (long)inMessageArgument);
		}
		NSLog(@"*** kIOMessageCanSystemSleep %@", @(canSystemSleep));
	}
}
static void preventCyPushSleep()
{
	IONotificationPortRef notify;
	gRootPort = IORegisterForSystemPower(NULL, &notify, HandlePowerManagerEventCyPush, &notifier);
    if(gRootPort == MACH_PORT_NULL) {
        NSLog (@"IORegisterForSystemPower failed.");
    } else {
        CFRunLoopAddSource(CFRunLoopGetCurrent(), IONotificationPortGetRunLoopSource(notify), kCFRunLoopDefaultMode);
    }
}

%ctor
{	
	@autoreleasepool {
		CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, settingsChangedCyPush, CFSTR("com.julioverne.cypush/SettingsChanged"), NULL, CFNotificationSuspensionBehaviorCoalesce);
		CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, statusChangedCyPush, CFSTR("com.julioverne.cypush.status"), NULL, CFNotificationSuspensionBehaviorCoalesce);
		settingsChangedCyPush(NULL, NULL, NULL, NULL, NULL);
		if(Enabled) {
			canSystemSleep = YES;
			if(strcmp(__progname, "Cydia") == 0) {
				preventCyPushSleep();
				%init(HooksCydia);
			} else {
				preventSystemSleep();
				CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, notifyCyPushNeedKilled, CFSTR("com.julioverne.cypush/Exit"), NULL, CFNotificationSuspensionBehaviorCoalesce);
				CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, cyPushCheckRun, CFSTR("com.julioverne.cypush/Check"), NULL, CFNotificationSuspensionBehaviorCoalesce);
				CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, notifyCyPushLaunched, CFSTR("com.julioverne.cypush/Launched"), NULL, CFNotificationSuspensionBehaviorCoalesce);
				
				if(useLibbulletin) {
					if(access("/Library/MobileSubstrate/DynamicLibraries/libbulletin.dylib", F_OK) == 0) {
						dlopen("/Library/MobileSubstrate/DynamicLibraries/libbulletin.dylib", RTLD_GLOBAL);
					} else {
						useLibbulletin = NO;
					}
				}		
				%init(HooksSB);
			}
		}
	}	
}
