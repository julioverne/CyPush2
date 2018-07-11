#import <notify.h>
#import <Social/Social.h>
#import <prefs.h>

#define PLIST_PATH_Settings "/var/mobile/Library/Preferences/com.julioverne.cypush.plist"
#define PLIST_PATH_Upgrades "/var/mobile/Library/Preferences/com.julioverne.cypush.upgrades.plist"

@interface CyPushSettingsController : PSListController
{
	UILabel* _label;
	UILabel* underLabel;
}
- (void)HeaderCell;
@end

@interface CyPushBannerSettingsController : PSListController
{
	
}
@end


@implementation CyPushSettingsController
- (id)specifiers {
	if (!_specifiers) {
		NSMutableArray* specifiers = [NSMutableArray array];
		PSSpecifier* spec;
		
		spec = [PSSpecifier preferenceSpecifierNamed:@"Enabled"
						  target:self
												 set:@selector(setPreferenceValue:specifier:)
												 get:@selector(readPreferenceValue:)
						  detail:Nil
												cell:PSSwitchCell
												edit:Nil];
		[spec setProperty:@"Enabled" forKey:@"key"];
		[spec setProperty:@YES forKey:@"PromptRespring"];
		[spec setProperty:@YES forKey:@"default"];
	[specifiers addObject:spec];
		
		spec = [PSSpecifier emptyGroupSpecifier];
	[specifiers addObject:spec];
		
		spec = [PSSpecifier preferenceSpecifierNamed:@"Only In WiFi"
					      target:self
											  set:@selector(setPreferenceValue:specifier:)
											  get:@selector(readPreferenceValue:)
					      detail:Nil
											  cell:PSSwitchCell
											  edit:Nil];
		[spec setProperty:@"onlyWiFi" forKey:@"key"];
		[spec setProperty:@YES forKey:@"default"];
	[specifiers addObject:spec];
	
		
		spec = [PSSpecifier preferenceSpecifierNamed:@"Notification Options"
					      target:self
											  set:@selector(setPreferenceValue:specifier:)
											  get:@selector(readPreferenceValue:)
					      detail:CyPushBannerSettingsController.class
											  cell:PSLinkCell
											  edit:Nil];
		[specifiers addObject:spec];
		
		spec = [PSSpecifier preferenceSpecifierNamed:@"Interval Auto Refresh (Minutes)"
						      target:self
											  set:Nil
											  get:Nil
					      detail:Nil
											  cell:PSGroupCell
											  edit:Nil];
		[spec setProperty:@"Interval Auto Refresh (Minutes)" forKey:@"label"];
		[spec setProperty:@"Short Interval Refresh may drain your battery." forKey:@"footerText"];
	[specifiers addObject:spec];
		spec = [PSSpecifier preferenceSpecifierNamed:@"Enabled"
						  target:self
												 set:@selector(setPreferenceValue:specifier:)
												 get:@selector(readPreferenceValue:)
						  detail:Nil
												cell:PSSwitchCell
												edit:Nil];
		[spec setProperty:@"intervalRefresh" forKey:@"key"];
		[spec setProperty:@YES forKey:@"PromptRespring"];
		[spec setProperty:@YES forKey:@"default"];
	[specifiers addObject:spec];
		spec = [PSSpecifier preferenceSpecifierNamed:@"Interval Auto Refresh (Minutes)"
					      target:self
											  set:@selector(setPreferenceValue:specifier:)
											  get:@selector(readPreferenceValue:)
					      detail:Nil
											  cell:PSSliderCell
											  edit:Nil];
		[spec setProperty:@"pulseTimer" forKey:@"key"];
		[spec setProperty:@(60.0) forKey:@"default"];
		[spec setProperty:@(0.5) forKey:@"min"];
		[spec setProperty:@(180.0) forKey:@"max"];
		[spec setProperty:@NO forKey:@"isContinuous"];
		[spec setProperty:@YES forKey:@"showValue"];
	[specifiers addObject:spec];
		
		spec = [PSSpecifier preferenceSpecifierNamed:@"Activator"
						      target:self
											  set:Nil
											  get:Nil
					      detail:Nil
											  cell:PSGroupCell
											  edit:Nil];
		[spec setProperty:@"Activator" forKey:@"label"];
		[spec setProperty:@"Action For Refresh Sources In Cydia." forKey:@"footerText"];
	[specifiers addObject:spec];
		spec = [PSSpecifier preferenceSpecifierNamed:@"Activation Method"
					      target:self
						 set:NULL
						 get:NULL
					      detail:Nil
						cell:PSLinkCell
						edit:Nil];
		if (access("/usr/lib/libactivator.dylib", F_OK) == 0) {
			[spec setProperty:@YES forKey:@"isContoller"];
			[spec setProperty:@"com.julioverne.cypush" forKey:@"activatorListener"];
			[spec setProperty:@"/System/Library/PreferenceBundles/LibActivator.bundle" forKey:@"lazy-bundle"];
			spec->action = @selector(lazyLoadBundle:);
		}
	[specifiers addObject:spec];
		
		spec = [PSSpecifier emptyGroupSpecifier];
	[specifiers addObject:spec];
		spec = [PSSpecifier preferenceSpecifierNamed:@"Reset Settings"
					      target:self
						 set:NULL
						 get:NULL
					      detail:Nil
						cell:PSLinkCell
						edit:Nil];
	spec->action = @selector(reset);
	[specifiers addObject:spec];
		spec = [PSSpecifier preferenceSpecifierNamed:@"Developer"
						      target:self
											  set:Nil
											  get:Nil
					      detail:Nil
											  cell:PSGroupCell
											  edit:Nil];
		[spec setProperty:@"Developer" forKey:@"label"];
	[specifiers addObject:spec];
		spec = [PSSpecifier preferenceSpecifierNamed:@"Follow julioverne"
					      target:self
						 set:NULL
						 get:NULL
					      detail:Nil
						cell:PSLinkCell
						edit:Nil];
	spec->action = @selector(twitter);
		[spec setProperty:[NSNumber numberWithBool:TRUE] forKey:@"hasIcon"];
		[spec setProperty:[UIImage imageWithContentsOfFile:[[self bundle] pathForResource:@"twitter" ofType:@"png"]] forKey:@"iconImage"];
	[specifiers addObject:spec];
		spec = [PSSpecifier emptyGroupSpecifier];
	[spec setProperty:@"CyPush2 © 2017" forKey:@"footerText"];
	[specifiers addObject:spec];
		_specifiers = [specifiers copy];
	}
	return _specifiers;
}
- (void)twitter
{
	UIApplication *app = [UIApplication sharedApplication];
	if ([app canOpenURL:[NSURL URLWithString:@"twitter://user?screen_name=ijulioverne"]]) {
		[app openURL:[NSURL URLWithString:@"twitter://user?screen_name=ijulioverne"]];
	} else if ([app canOpenURL:[NSURL URLWithString:@"tweetbot:///user_profile/ijulioverne"]]) {
		[app openURL:[NSURL URLWithString:@"tweetbot:///user_profile/ijulioverne"]];		
	} else {
		[app openURL:[NSURL URLWithString:@"https://mobile.twitter.com/ijulioverne"]];
	}
}
- (void)love
{
	SLComposeViewController *twitter = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeTwitter];
	[twitter setInitialText:@"#CyPush2 by @ijulioverne is cool!"];
	if (twitter != nil) {
		[[self navigationController] presentViewController:twitter animated:YES completion:nil];
	}
}
- (void)showPrompt
{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:self.title message:@"An Respring is Requerid for this option." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Respring", nil];
	alert.tag = 55;
	[alert show];
}
- (void)reset
{
	[@{} writeToFile:@PLIST_PATH_Settings atomically:YES];
	[@{} writeToFile:@PLIST_PATH_Upgrades atomically:YES];
	notify_post("com.julioverne.cypush/SettingsChanged");
	[self reloadSpecifiers];
	[self showPrompt];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier
{
	@autoreleasepool {
		NSMutableDictionary *CydiaEnablePrefsCheck = [[NSMutableDictionary alloc] initWithContentsOfFile:@PLIST_PATH_Settings]?:[NSMutableDictionary dictionary];
		CydiaEnablePrefsCheck[[specifier identifier]] = value;
		[CydiaEnablePrefsCheck writeToFile:@PLIST_PATH_Settings atomically:YES];
		notify_post("com.julioverne.cypush/SettingsChanged");
		if ([[specifier properties] objectForKey:@"PromptRespring"]) {
			[self showPrompt];
		}
	}
}
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (alertView.tag == 55 && buttonIndex == 1) {
		system("killall backboardd SpringBoard");
    }
}
- (id)readPreferenceValue:(PSSpecifier*)specifier
{
	@autoreleasepool {
		NSDictionary *CydiaEnablePrefsCheck = [[NSDictionary alloc] initWithContentsOfFile:@PLIST_PATH_Settings]?:[NSDictionary dictionary];
		return CydiaEnablePrefsCheck[[specifier identifier]]?:[[specifier properties] objectForKey:@"default"];
	}
}
- (void)_returnKeyPressed:(id)arg1
{
	[super _returnKeyPressed:arg1];
	[self.view endEditing:YES];
}

- (void)HeaderCell
{
	@autoreleasepool {
		UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, 120)];
		int width = [[UIScreen mainScreen] bounds].size.width;
		CGRect frame = CGRectMake(0, 20, width, 60);
		CGRect botFrame = CGRectMake(0, 55, width, 60); 
		_label = [[UILabel alloc] initWithFrame:frame];
		[_label setNumberOfLines:1];
		_label.font = [UIFont fontWithName:@"HelveticaNeue-UltraLight" size:48];
		[_label setText:@"CyPush2"];
		[_label setBackgroundColor:[UIColor clearColor]];
		_label.textColor = [UIColor blackColor];
		_label.textAlignment = NSTextAlignmentCenter;
		_label.alpha = 0;

		underLabel = [[UILabel alloc] initWithFrame:botFrame];
		[underLabel setNumberOfLines:1];
		underLabel.font = [UIFont fontWithName:@"HelveticaNeue-Light" size:14];
		[underLabel setText:@"Push Notifications For Cydia"];
		[underLabel setBackgroundColor:[UIColor clearColor]];
		underLabel.textColor = [UIColor grayColor];
		underLabel.textAlignment = NSTextAlignmentCenter;
		underLabel.alpha = 0;
		
		[headerView addSubview:_label];
		[headerView addSubview:underLabel];

		[_table setTableHeaderView:headerView];
		[NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(increaseAlpha) userInfo:nil repeats:NO];
	}
}
- (void) loadView
{
	[super loadView];
	self.title = @"CyPush2"; 
	[UISwitch appearanceWhenContainedIn:self.class, nil].onTintColor = [UIColor brownColor];
	UIButton *heart = [[UIButton alloc] initWithFrame:CGRectZero];
	[heart setImage:[[UIImage alloc] initWithContentsOfFile:[[self bundle] pathForResource:@"Heart" ofType:@"png"]] forState:UIControlStateNormal];
	[heart sizeToFit];
	[heart addTarget:self action:@selector(love) forControlEvents:UIControlEventTouchUpInside];
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:heart];
	[self HeaderCell];
}
- (void)increaseAlpha
{
	[UIView animateWithDuration:0.5 animations:^{
		_label.alpha = 1;
	}completion:^(BOOL finished) {
		[UIView animateWithDuration:0.5 animations:^{
			underLabel.alpha = 1;
		}completion:nil];
	}];
}				
@end

@implementation CyPushBannerSettingsController
- (id)specifiers
{
	if (!_specifiers) {
		NSMutableArray* specifiers = [NSMutableArray array];
		PSSpecifier* spec;
		
		spec = [PSSpecifier preferenceSpecifierNamed:@"Use Badges"
					      target:self
											  set:@selector(setPreferenceValue:specifier:)
											  get:@selector(readPreferenceValue:)
					      detail:Nil
											  cell:PSSwitchCell
											  edit:Nil];
		[spec setProperty:@"useBadges" forKey:@"key"];
		[spec setProperty:@YES forKey:@"default"];
	[specifiers addObject:spec];
		
		spec = [PSSpecifier preferenceSpecifierNamed:@"Format Message"
						      target:self
											  set:Nil
											  get:Nil
					      detail:Nil
											  cell:PSGroupCell
											  edit:Nil];
		[spec setProperty:@"Format Message" forKey:@"label"];
		[spec setProperty:@"$#status: Status (New/Update/Change)\n$#name: Name Package\n$#version: Version Package\n$#description: Description Package\n$#section: Section Package\n$#source: Source Package\n$#author: Author Package\n$#hash: Hash Package (md5/sha1/sha256)\n$#id: ID Package\n$#version_name: Version Name\n$#price: if Paid will show 💰" forKey:@"footerText"];
	[specifiers addObject:spec];
		spec = [PSSpecifier preferenceSpecifierNamed:nil
					      target:self
											  set:@selector(setPreferenceValue:specifier:)
											  get:@selector(readPreferenceValue:)
					      detail:Nil
											  cell:PSEditTextCell
											  edit:Nil];
		[spec setProperty:@"FormatMessage" forKey:@"key"];
		[spec setProperty:@"$#status: $#name $#version $#price – $#section ($#source)" forKey:@"default"];
	[specifiers addObject:spec];
	
	spec = [PSSpecifier emptyGroupSpecifier];
	[specifiers addObject:spec];
		
		spec = [PSSpecifier preferenceSpecifierNamed:@"Show Upgrades Packages"
					      target:self
											  set:@selector(setPreferenceValue:specifier:)
											  get:@selector(readPreferenceValue:)
					      detail:Nil
											  cell:PSSwitchCell
											  edit:Nil];
		[spec setProperty:@"showUpdatesPackages" forKey:@"key"];
		[spec setProperty:@YES forKey:@"default"];
	[specifiers addObject:spec];
		
		spec = [PSSpecifier preferenceSpecifierNamed:@"Show Ignored Upgrades"
					      target:self
											  set:@selector(setPreferenceValue:specifier:)
											  get:@selector(readPreferenceValue:)
					      detail:Nil
											  cell:PSSwitchCell
											  edit:Nil];
		[spec setProperty:@"showIgnoredUpdates" forKey:@"key"];
		[spec setProperty:@YES forKey:@"default"];
	[specifiers addObject:spec];
		
		spec = [PSSpecifier preferenceSpecifierNamed:@"Show News Packages"
					      target:self
											  set:@selector(setPreferenceValue:specifier:)
											  get:@selector(readPreferenceValue:)
					      detail:Nil
											  cell:PSSwitchCell
											  edit:Nil];
		[spec setProperty:@"showNewPackages" forKey:@"key"];
		[spec setProperty:@NO forKey:@"default"];
	[specifiers addObject:spec];
		
		spec = [PSSpecifier preferenceSpecifierNamed:@"Show Changes Packages"
					      target:self
											  set:@selector(setPreferenceValue:specifier:)
											  get:@selector(readPreferenceValue:)
					      detail:Nil
											  cell:PSSwitchCell
											  edit:Nil];
		[spec setProperty:@"showAllChanges" forKey:@"key"];
		[spec setProperty:@NO forKey:@"default"];
	[specifiers addObject:spec];
	
		spec = [PSSpecifier emptyGroupSpecifier];
	[specifiers addObject:spec];
		
		spec = [PSSpecifier preferenceSpecifierNamed:@"Hide Section Themes"
					      target:self
											  set:@selector(setPreferenceValue:specifier:)
											  get:@selector(readPreferenceValue:)
					      detail:Nil
											  cell:PSSwitchCell
											  edit:Nil];
		[spec setProperty:@"hideSectionTheme" forKey:@"key"];
		[spec setProperty:@NO forKey:@"default"];
	[specifiers addObject:spec];
		
		spec = [PSSpecifier preferenceSpecifierNamed:@"Hide Section Tweaks"
					      target:self
											  set:@selector(setPreferenceValue:specifier:)
											  get:@selector(readPreferenceValue:)
					      detail:Nil
											  cell:PSSwitchCell
											  edit:Nil];
		[spec setProperty:@"hideSectionTweak" forKey:@"key"];
		[spec setProperty:@NO forKey:@"default"];
	[specifiers addObject:spec];
		
		spec = [PSSpecifier emptyGroupSpecifier];
	[specifiers addObject:spec];
		
		spec = [PSSpecifier preferenceSpecifierNamed:@"Show Progress Status"
						  target:self
												 set:@selector(setPreferenceValue:specifier:)
												 get:@selector(readPreferenceValue:)
						  detail:Nil
												cell:PSSwitchCell
												edit:Nil];
		[spec setProperty:@"showStatus" forKey:@"key"];
		[spec setProperty:@NO forKey:@"default"];
	[specifiers addObject:spec];
		spec = [PSSpecifier preferenceSpecifierNamed:@"Use libbulletin Dependency"
						  target:self
												 set:@selector(setPreferenceValue:specifier:)
												 get:@selector(readPreferenceValue:)
						  detail:Nil
												cell:PSSwitchCell
												edit:Nil];
		[spec setProperty:@"useLibbulletin" forKey:@"key"];
		[spec setProperty:@YES forKey:@"PromptRespring"];
		[spec setProperty:@NO forKey:@"default"];
		[spec setProperty:@((access("/Library/MobileSubstrate/DynamicLibraries/libbulletin.dylib", F_OK) == 0)?YES:NO) forKey: @"enabled"];
	[specifiers addObject:spec];
		
		_specifiers = [specifiers copy];
	}
	return _specifiers;
}
- (void)showPrompt
{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:self.title message:@"An Respring is Requerid for this option." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Respring", nil];
	alert.tag = 55;
	[alert show];
}
- (void)reset
{
	[@{} writeToFile:@PLIST_PATH_Settings atomically:YES];
	[@{} writeToFile:@PLIST_PATH_Upgrades atomically:YES];
	notify_post("com.julioverne.cypush/SettingsChanged");
	[self reloadSpecifiers];
	[self showPrompt];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier
{
	@autoreleasepool {
		NSMutableDictionary *CydiaEnablePrefsCheck = [[NSMutableDictionary alloc] initWithContentsOfFile:@PLIST_PATH_Settings]?:[NSMutableDictionary dictionary];
		CydiaEnablePrefsCheck[[specifier identifier]] = value;
		[CydiaEnablePrefsCheck writeToFile:@PLIST_PATH_Settings atomically:YES];
		notify_post("com.julioverne.cypush/SettingsChanged");
		if ([[specifier properties] objectForKey:@"PromptRespring"]) {
			[self showPrompt];
		}
	}
}
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (alertView.tag == 55 && buttonIndex == 1) {
		system("killall backboardd SpringBoard");
    }
}
- (id)readPreferenceValue:(PSSpecifier*)specifier
{
	@autoreleasepool {
		NSDictionary *CydiaEnablePrefsCheck = [[NSDictionary alloc] initWithContentsOfFile:@PLIST_PATH_Settings]?:[NSDictionary dictionary];
		return CydiaEnablePrefsCheck[[specifier identifier]]?:[[specifier properties] objectForKey:@"default"];
	}
}
- (void)_returnKeyPressed:(id)arg1
{
	[super _returnKeyPressed:arg1];
	[self.view endEditing:YES];
}
- (void) loadView
{
	[super loadView];	
	[UISwitch appearanceWhenContainedIn:self.class, nil].onTintColor = [UIColor brownColor];
}				
@end