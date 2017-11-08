#include <stdio.h>
#include <stdlib.h>
#import <dlfcn.h>
#import <objc/runtime.h>
#include <sys/sysctl.h>
#import <notify.h>

#import <AppSupport/CPDistributedMessagingCenter.h>
extern const char *__progname;

#define isCydiaOpenedState (!([[UIApplication sharedApplication] applicationState]==UIApplicationStateBackground || [[UIApplication sharedApplication] applicationState]==UIApplicationStateInactive))

#define PLIST_PATH_Settings "/var/mobile/Library/Preferences/com.julioverne.cypush.plist"
#define PLIST_PATH_Upgrades "/var/mobile/Library/Preferences/com.julioverne.cypush.upgrades.plist"

typedef enum {
    ConnectionTypeUnknown,
    ConnectionTypeNone,
    ConnectionType3G,
    ConnectionTypeWiFi
} ConnectionType;

typedef NS_ENUM(NSUInteger, BKSProcessAssertionReason)
{
    kProcessAssertionReasonAudio = 1,
    kProcessAssertionReasonLocation,
    kProcessAssertionReasonExternalAccessory,
    kProcessAssertionReasonFinishTask,
    kProcessAssertionReasonBluetooth,
    kProcessAssertionReasonNetworkAuthentication,
    kProcessAssertionReasonBackgroundUI,
    kProcessAssertionReasonInterAppAudioStreaming,
    kProcessAssertionReasonViewServices
};

typedef NS_OPTIONS(NSUInteger, ProcessAssertionFlags)
{
    ProcessAssertionFlagNone = 0,
    ProcessAssertionFlagPreventSuspend         = 1 << 0,
    ProcessAssertionFlagPreventThrottleDownCPU = 1 << 1,
    ProcessAssertionFlagAllowIdleSleep         = 1 << 2,
    ProcessAssertionFlagWantsForegroundResourcePriority  = 1 << 3
};

@interface BKSProcessAssertion : NSObject

@property(readonly, assign, nonatomic) BOOL valid;

- (id)initWithBundleIdentifier:(NSString *)bundleIdentifier flags:(unsigned)flags reason:(unsigned)reason name:(NSString *)name withHandler:(id)handler;
- (void)invalidate;

@end


@interface UNNotificationContent : NSObject
@property (nonatomic, readonly, copy) NSDictionary *userInfo;
@end
@interface UNNotificationRequest : NSObject
@property (nonatomic, readonly, copy) UNNotificationContent *content;
@end
@interface UNNotification : NSObject
@property (nonatomic, readonly, copy) UNNotificationRequest *request;
@end
@interface UNNotificationResponse : NSObject
@property (nonatomic, readonly, copy) UNNotification *notification;
@end
@interface UINotificationResponseAction : NSObject
@property (nonatomic, readonly, retain) UNNotificationResponse *response;
@end

@interface UIHandleLocalNotificationAction : NSObject
@property (nonatomic, readonly, copy) UILocalNotification *notification;
@end


@interface JBBulletinManager : NSObject
+(id)sharedInstance;
-(id)showBulletinWithTitle:(NSString *)inTitle message:(NSString *)inMessage bundleID:(NSString *)inBundleID hasSound:(BOOL)hasSound soundID:(int)soundID vibrateMode:(int)vibrate soundPath:(NSString *)inSoundPath attachmentImage:(UIImage *)inAttachmentImage overrideBundleImage:(UIImage *)inOverrideBundleImage;
@end

@interface Database : NSObject
+ (id)sharedInstance;
- (void)update;
- (NSArray *)packages;
@end

@interface SBBacklightController : NSObject
+ (id)sharedInstance;
- (void)_resetIdleTimerAndUndim:(BOOL)arg1 source:(int)arg2;

-(void)_undimFromSource:(int)arg1 ;

-(void)turnOnScreenFullyWithBacklightSource:(int)arg1 ;
@end

@interface FBApplicationProcess : NSObject
- (void)killForReason:(long long)arg1 andReport:(BOOL)arg2 withDescription:(id)arg3 completion:(/*^block*/id)arg4 ;
@end

@interface FBSSceneSettings : NSObject
@end

@interface FBSMutableSceneSettings : FBSSceneSettings
@property(nonatomic, getter=isBackgrounded) BOOL backgrounded;
@end

@interface FBScene : NSObject
@property(readonly, retain, nonatomic) FBSMutableSceneSettings *mutableSettings;
@property(readonly, retain, nonatomic) FBSSceneSettings *settings;
- (void)_applyMutableSettings:(id)arg1 withTransitionContext:(id)arg2 completion:(id)arg3;
@end

@interface SBApplication : NSObject
@property(readonly, nonatomic) int pid;
- (BOOL)isRunning;
- (NSString *)bundleIdentifier;
- (void)clearDeactivationSettings;
- (FBScene *)mainScene;
- (id)mainScreenContextHostManager;
- (id)mainSceneID;
- (void)activate;
- (void)setFlag:(long long)arg1 forActivationSetting:(unsigned int)arg2;
- (void)processDidLaunch:(id)arg1;
- (void)processWillLaunch:(id)arg1;
- (void)resumeForContentAvailable;
- (void)resumeToQuit;
- (void)_sendDidLaunchNotification:(BOOL)arg1;
- (void)notifyResumeActiveForReason:(long long)arg1;
- (void)setApplicationState:(unsigned int)applicationState;
@end


@interface FBApplicationInfo : NSObject
@property(copy, nonatomic) NSString *bundleIdentifier;
@end

@interface SBApplicationController : NSObject
- (SBApplication*)applicationWithBundleIdentifier:(NSString *)identifier;
+ (instancetype)sharedInstance;
@end

@interface UIApplication (Private)
-(BOOL)launchApplicationWithIdentifier:(NSString*)bundleID suspended:(BOOL)suspended;
- (void)resetIdleTimerAndUndim;
@end



@interface LSApplicationProxy : NSObject
@property (nonatomic, readonly) long bundleModTime;
@property (nonatomic, readonly) NSString *applicationIdentifier;
@property (nonatomic, readonly) NSDictionary *entitlements;
@property (nonatomic, readonly) NSString *signerIdentity;
@property (nonatomic, readonly) BOOL profileValidated;
@property (nonatomic, readonly) NSString *shortVersionString;
@property (nonatomic, readonly) NSNumber *staticDiskUsage;
@property (nonatomic, readonly) NSString *teamID;
@property (nonatomic, readonly) NSURL *bundleURL;
+ (id)applicationProxyForIdentifier:(id)arg1;
- (BOOL)isSystemOrInternalApp;
- (id)localizedName;
@end

@interface LSApplicationWorkspace : NSObject
+ (id)defaultWorkspace;
- (id)allInstalledApplications;
- (BOOL)installApplication:(NSURL *)path withOptions:(NSDictionary *)options error:(NSError **)error;
- (BOOL)uninstallApplication:(NSString *)identifier withOptions:(NSDictionary *)options;
@end

#import <IOKit/IOKitLib.h>

extern "C" io_connect_t IORegisterForSystemPower(void * refcon, IONotificationPortRef * thePortRef, IOServiceInterestCallback callback, io_object_t * notifier );
extern "C" IOReturn IOAllowPowerChange( io_connect_t kernelPort, long notificationID );
extern "C" IOReturn IOCancelPowerChange(io_connect_t kernelPort, intptr_t notificationID);
extern "C" IOReturn IOPMSchedulePowerEvent(CFDateRef time_to_wake, CFStringRef my_id, CFStringRef type);
extern "C" IOReturn IOPMCancelScheduledPowerEvent(CFDateRef time_to_wake, CFStringRef my_id, CFStringRef type);
extern "C" IOReturn IODeregisterForSystemPower ( io_object_t * notifier );
extern "C" CFArrayRef IOPMCopyScheduledPowerEvents(void);

typedef uint32_t IOPMAssertionLevel;
typedef uint32_t IOPMAssertionID;
extern "C" IOReturn IOPMAssertionCreateWithName(CFStringRef AssertionType,IOPMAssertionLevel AssertionLevel, CFStringRef AssertionName, IOPMAssertionID *AssertionID);
extern "C" IOReturn IOPMAssertionRelease(IOPMAssertionID AssertionID);
#define iokit_common_msg(message)          (UInt32)(sys_iokit|sub_iokit_common|message)
#define kIOMessageCanSystemPowerOff iokit_common_msg( 0x240)
#define kIOMessageSystemWillPowerOff iokit_common_msg( 0x250) 
#define kIOMessageSystemWillNotPowerOff iokit_common_msg( 0x260)
#define kIOMessageCanSystemSleep iokit_common_msg( 0x270) 
#define kIOMessageSystemWillSleep iokit_common_msg( 0x280) 
#define kIOMessageSystemWillNotSleep iokit_common_msg( 0x290) 
#define kIOMessageSystemHasPoweredOn iokit_common_msg( 0x300) 
#define kIOMessageSystemWillRestart iokit_common_msg( 0x310) 
#define kIOMessageSystemWillPowerOn iokit_common_msg( 0x320)

#define kIOPMAutoPowerOn "poweron" 
#define kIOPMAutoShutdown "shutdown" 
#define kIOPMAutoSleep "sleep"
#define kIOPMAutoWake "wake"
#define kIOPMAutoWakeOrPowerOn "wakepoweron"

@interface UNUserNotificationCenter : NSObject
@property (nonatomic, assign) id delegate;
- (void)addObserver:(id)arg1;
@end

// Firmware >= 9.0 & 10.0
@interface UNSNotificationScheduler : NSObject
@property (nonatomic, assign) id delegate;
@property (nonatomic, retain) UNUserNotificationCenter *userNotificationCenter;
- (id)initWithBundleIdentifier:(id)bundleIdentifier;
- (void)_addScheduledLocalNotifications:(NSArray *)notifications withCompletion:(id)completion;
- (void)cancelAllScheduledLocalNotifications;
@end

@interface Ext3nderManager : NSObject
+ (id) shared;
- (void)requestCheck;
@end

@interface NSUserDefaults ()
- (id)objectForKey:(NSString *)key inDomain:(NSString *)domain;
@end


namespace Cytore {
	
static const uint32_t Magic = 'cynd';

struct Header {
    uint32_t magic_;
    uint32_t version_;
    uint32_t size_;
    uint32_t reserved_;
};

template <typename Target_>
class Offset {
  private:
    uint32_t offset_;

  public:
    Offset() :
        offset_(0)
    {
    }

    Offset(uint32_t offset) :
        offset_(offset)
    {
    }

    Offset &operator =(uint32_t offset) {
        offset_ = offset;
        return *this;
    }

    uint32_t GetOffset() const {
        return offset_;
    }

    bool IsNull() const {
        return offset_ == 0;
    }
};

struct Block {
     Cytore::Offset<void> reserved_;
 };
}
struct PackageValue :
     Cytore::Block
 {
     Cytore::Offset<PackageValue> next_;
 
     uint32_t index_ : 23;
     uint32_t subscribed_ : 1;
     uint32_t : 8;
 
     int32_t first_;
     int32_t last_;
 
     uint16_t vhash_;
     uint16_t nhash_;
 
     char version_[8];
     char name_[];
 };

@interface MIMEAddress : NSObject
- (NSString *) name;
- (NSString *) address;
@end

@interface Cydia : NSObject
- (BOOL)openCydiaURL:(id)fp8 forExternal:(BOOL)fp12;
- (void)system:(id)arg1;
@end

@interface Source : NSObject
- (NSString *) depictionForPackage:(NSString *)package;
- (NSString *) supportForPackage:(NSString *)package;

- (NSDictionary *) record;
- (BOOL) trusted;

- (NSString *) rooturi;
- (NSString *) distribution;
- (NSString *) type;

- (NSString *) key;
- (NSString *) host;

- (NSString *) name;
- (NSString *) shortDescription;
- (NSString *) label;
- (NSString *) origin;
- (NSString *) version;

- (NSString *) defaultIcon;
- (NSURL *) iconURL;
@end

@interface Package : NSObject
- (BOOL)isCommercial;
- (id)purposes;
- (id)primaryPurpose;
- (BOOL)hasTag:(id)fp8;
- (id)tags;
- (BOOL)matches:(id)fp8;
- (unsigned int)rank;
- (unsigned int)recent;
- (long)upgraded;
- (Source *)source;
- (PackageValue *) metadata;
- (id)warnings;
- (id)selection;
- (id)state;
- (id)files;
- (id)support;
- (MIMEAddress *) author;
- (id)downgrades;
- (id)depiction;
- (id)homepage;
- (UIImage *)icon;
- (id)name;
- (id)id;
- (id)mode;
- (BOOL)hasMode;
- (BOOL)halfInstalled;
- (BOOL)halfConfigured;
- (BOOL)half;
- (BOOL)visible;
- (BOOL)unfiltered;
- (BOOL)broken;
- (BOOL)essential;
- (BOOL)upgradableAndEssential:(BOOL)fp8;
- (BOOL)valid;
- (BOOL)uninstalled;
- (id)installed;
- (id)latest;
- (BOOL)ignored;
- (BOOL)setSubscribed:(BOOL)fp8;
- (BOOL)subscribed;
- (long)seen;
- (unsigned short)index;
- (id)shortDescription;
- (id)longDescription;
- (unsigned long)size;
- (id)md5sum;
- (id)maintainer;
- (id)uri;
- (id)shortSection;
- (id)longSection;
- (id)simpleSection;
- (id)section;
- (void)parse;
- (id)getRecord;
- (id)getField:(id)fp8;
- (id)architecture;
- (id)relations;
- (id)description;
@end

@interface CyPush : NSObject
{
	BOOL isRunningRunUpdated;
}
+ (id)shared;
+ (BOOL)sharedExist;
- (void)run_this;
- (void)RunUpdates;
- (void)updateBadges;
@end


