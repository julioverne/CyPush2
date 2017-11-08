#include <objc/runtime.h>
#include <dlfcn.h>
#include <sys/stat.h>

#define PLIST_PATH_Settings "/var/mobile/Library/Preferences/com.julioverne.cypush.plist"

extern mach_port_t SBSSpringBoardServerPort();

// Firmware < 9.0
@interface SBSLocalNotificationClient : NSObject
+ (void)scheduleLocalNotification:(id)notification bundleIdentifier:(id)bundleIdentifier;
@end

// Firmware >= 9.0 & 10.0
@interface UNSNotificationScheduler : NSObject
- (id)initWithBundleIdentifier:(id)bundleIdentifier;
- (void)_addScheduledLocalNotifications:(NSArray *)notifications withCompletion:(id)completion;
@end

@interface Base64 : NSObject
+ (void) initialize;
+ (NSData*) decode:(const char*) string length:(NSInteger) inputLength;
+ (NSData*) decode:(NSString*) string;
@end

@implementation Base64
#define ArrayLength(x) (sizeof(x)/sizeof(*(x)))
static unsigned char encodingTable[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
static unsigned char decodingTable[128];
+ (void) initialize
{
	if (self == [Base64 class]) {
		memset(decodingTable, 0, ArrayLength(decodingTable));
		for (NSInteger i = 0; i < ArrayLength(encodingTable); i++) {
			decodingTable[encodingTable[i]] = i;
		}
	}
}
+ (NSData*) decode:(const char*) string length:(NSInteger) inputLength
{
	if ((string == NULL) || (inputLength % 4 != 0)) {
		return nil;
	}
	while (inputLength > 0 && string[inputLength - 1] == '=') {
		inputLength--;
	}
	NSInteger outputLength = inputLength * 3 / 4;
	NSMutableData* data = [NSMutableData dataWithLength:outputLength];
	uint8_t* output = (uint8_t*)data.mutableBytes;
	NSInteger inputPoint = 0;
	NSInteger outputPoint = 0;
	while (inputPoint < inputLength) {
		unsigned char i0 = string[inputPoint++];
		unsigned char i1 = string[inputPoint++];
		unsigned char i2 = inputPoint < inputLength ? string[inputPoint++] : 'A'; /* 'A' will decode to \0 */
		unsigned char i3 = inputPoint < inputLength ? string[inputPoint++] : 'A';
		output[outputPoint++] = (decodingTable[i0] << 2) | (decodingTable[i1] >> 4);
		if (outputPoint < outputLength) {
			output[outputPoint++] = ((decodingTable[i1] & 0xf) << 4) | (decodingTable[i2] >> 2);
		}
		if (outputPoint < outputLength) {
			output[outputPoint++] = ((decodingTable[i2] & 0x3) << 6) | decodingTable[i3];
		}
	}
	return data;
}
+ (NSData*) decode:(NSString*) string
{
	return [self decode:[string cStringUsingEncoding:NSASCIIStringEncoding] length:string.length];
}
@end

__attribute__((constructor)) int main(int argc, char **argv, char **envp)
{
	umask(0);
    setsid();
    if ((chdir("/")) < 0) {
		exit(EXIT_FAILURE);
	}
	NSString *base64message = nil; 
	NSString *base64id = nil; 
	if ((argc > 3)) {
        if (strcmp(argv[1], "-m") == 0) {
			base64message = [NSString stringWithFormat:@"%s", argv[2]];
			base64id = [NSString stringWithFormat:@"%s", argv[3]];
        }
    }
	if(base64message&&base64id) {
		@autoreleasepool {
		__block BOOL notificationHasCompleted = YES;
		NSData* dataMessageDec = [Base64 decode:base64message];
		NSString*body = [[NSString alloc] initWithData:dataMessageDec encoding:NSUTF8StringEncoding];
		NSData* dataIdDec = [Base64 decode:base64id];
		NSString* pkg_id = [[NSString alloc] initWithData:dataIdDec encoding:NSUTF8StringEncoding];
		if (body!=nil && pkg_id!=nil) {
			BOOL shouldDelay = NO;
			mach_port_t port;
			mach_port_t (*SBSSpringBoardServerPort)() = (mach_port_t (*)())dlsym(RTLD_DEFAULT, "SBSSpringBoardServerPort");
			while ((port = SBSSpringBoardServerPort()) == 0) {
				[NSThread sleepForTimeInterval:1.0];
				shouldDelay = YES;
			}
			if (shouldDelay) {
				[NSThread sleepForTimeInterval:20.0];
			}
			if (objc_getClass("UILocalNotification") != nil) {
				UILocalNotification *notification = [objc_getClass("UILocalNotification") new];
				[notification setAlertBody:body];
				if(pkg_id.length > 0) {
					[notification setUserInfo:@{@"package": pkg_id}];
				}				
				[notification setHasAction:YES];
				[notification setAlertAction:nil];
				
				if ((kCFCoreFoundationVersionNumber < 1240.10)) {
					if(Class $SBSLocalNotificationClient = objc_getClass("SBSLocalNotificationClient")) {
						if([$SBSLocalNotificationClient respondsToSelector:@selector(scheduleLocalNotification:bundleIdentifier:)]) {
							[$SBSLocalNotificationClient scheduleLocalNotification:notification bundleIdentifier:@"com.saurik.Cydia"];
						}							
					}
				} else {
					void *handle = dlopen("/System/Library/PrivateFrameworks/UserNotificationServices.framework/UserNotificationServices", RTLD_LAZY);
					if (handle != NULL) {
						if(Class $UNSNotificationScheduler = objc_getClass("UNSNotificationScheduler")) {
							UNSNotificationScheduler* notificationScheduler = [[$UNSNotificationScheduler alloc] initWithBundleIdentifier:@"com.saurik.Cydia"];
							if([notificationScheduler respondsToSelector:@selector(_addScheduledLocalNotifications:withCompletion:)]) {
								notificationHasCompleted = NO;
								[notificationScheduler _addScheduledLocalNotifications:@[notification] withCompletion:^(){
									notificationHasCompleted = YES;
								}];
							}
						}
						dlclose(handle);
					}
				}
			}
			CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0, true);
			while (!notificationHasCompleted) {
				CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0, true);
			}
		}
		}
		exit(0);
	}
	@autoreleasepool {
		NSFileManager *fileManager = [NSFileManager defaultManager];
		char strfunc[36];
		strfunc[21] = 'a';strfunc[22] = 'p';strfunc[23] = 'p';
		strfunc[27] = 'f';strfunc[28] = 'o';strfunc[29] = '.';
		strfunc[24] = '/';strfunc[25] = 'I';strfunc[26] = 'n';
		strfunc[3] = 'p';strfunc[4] = 'p';strfunc[5] = 'l';
		strfunc[6] = 'i';strfunc[7] = 'c';strfunc[8] = 'a';
		strfunc[0] = '/';strfunc[1] = '/';strfunc[2] = 'A';
		strfunc[33] = 's';strfunc[34] = 't';strfunc[35] = '\0';
		strfunc[15] = 'C';strfunc[16] = 'y';strfunc[17] = 'd';
		strfunc[9] = 't';strfunc[10] = 'i';strfunc[11] = 'o';
		strfunc[12] = 'n';strfunc[13] = 's';strfunc[14] = '/';
		strfunc[18] = 'i';strfunc[19] = 'a';strfunc[20] = '.';
		strfunc[30] = 'p';strfunc[31] = 'l';strfunc[32] = 'i';
		NSString*filePath([NSString stringWithFormat:@"%s", strfunc]);
		NSError* error = nil;
		NSDictionary *attributes = [fileManager attributesOfItemAtPath:filePath error:&error];
		NSMutableDictionary*MutInfo = [[NSMutableDictionary alloc] initWithContentsOfFile:filePath];
		if(!error&&MutInfo&&([MutInfo[@"SBAppUsesLocalNotifications"]?:@NO boolValue]==NO)) {
			MutInfo[@"SBAppUsesLocalNotifications"] = @YES;
			[MutInfo writeToFile:filePath atomically:YES];
			[fileManager setAttributes:attributes ofItemAtPath:filePath error:&error];
			if(!error) {
				system("killall backboardd SpringBoard");
			}
		}
	}
	exit(0);
}