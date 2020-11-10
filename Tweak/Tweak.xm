#import "Headers.h"
#import "FlynnsArcade.h"
#import <notify.h>

//Lightmann
//Made during COVID-19
//Quorra

%group general
//Initialize my controller
%hook SpringBoard
- (void)applicationDidFinishLaunching:(UIApplication *)application {
    %orig;
	[FlynnsArcade sharedInstance];
}
%end
%end


%group camIndicator   
/* Apple doesn't give direct access to the camera at a low-level and only core methods I could find were for buffer allocation (i.e. when data is being saved), which happens too late in the cycle for what we want (when pixel data becomes available) */

// determine when camera is active by checking availability of the flashlight; if flash isn't available cam is active
%hook SBUIFlashlightController 
-(void)_updateStateWithAvailable:(BOOL)arg1 level:(unsigned long long)arg2 overheated:(BOOL)arg3 {
	%orig;

	if(!arg1)
		CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("me.lightmann.quorra/camActive"), nil, nil, true);
	
	else if (arg1)
		CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("me.lightmann.quorra/camInactive"), nil, nil, true);
	
	else
		%orig;
}
%end

%hook FlynnsArcade
+(void)initialize{
	%orig;

    int notify_token2;

    // change cam indicator for use
    notify_register_dispatch("me.lightmann.quorra/camActive", &notify_token2, dispatch_get_main_queue(), ^(int token) {
        [[[FlynnsArcade sharedInstance] container].greenDot setHidden:NO];
    });
	notify_register_dispatch("me.lightmann.quorra/camInactive", &notify_token2, dispatch_get_main_queue(), ^(int token) {
        [[[FlynnsArcade sharedInstance] container].greenDot setHidden:YES];
    });
}
%end

%end


%group micIndicator 
/* may eventually add check for phone calls too since that's the only other edge case not currently accounted for.
   no indicator when recording video to match w iOS 14 where camera indicator takes precedent 					  */

//determine when mic is active (pure audio recording)
%hookf(OSStatus, AudioUnitInitialize, AudioUnit inUnit){
	OSStatus orig = %orig;

	CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("me.lightmann.quorra/micActive"), nil, nil, true);

    return orig;
}

//determine when mic is inactive (pure audio recording)
%hookf(OSStatus, AudioUnitUninitialize, AudioUnit inUnit){
	OSStatus orig = %orig;

	CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("me.lightmann.quorra/micInactive"), nil, nil, true);

    return orig;
}

//Determine when dictation is in use
%hook UIDictationController
-(void)startDictation{
	%orig;

	CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("me.lightmann.quorra/micActive"), nil, nil, true);
}

-(void)stopDictation{
	%orig;
	
	CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("me.lightmann.quorra/micInactive"), nil, nil, true);
}
%end

//Determine when Siri is in use 
%hook AFUISiriSession
-(void)assistantConnectionSpeechRecordingWillBegin:(id)arg1 {
	%orig;

	CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("me.lightmann.quorra/micActive"), nil, nil, true);
}

-(void)assistantConnectionSpeechRecordingDidEnd:(id)arg1 {  //normal end 
	%orig;

	CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("me.lightmann.quorra/micInactive"), nil, nil, true);
}

-(void)endForReason:(long long)arg1{  //any other type of end 
	%orig;

	CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("me.lightmann.quorra/micInactive"), nil, nil, true);
}
%end

%hook FlynnsArcade
+(void)initialize{
	%orig;

    int notify_token2;

    // change mic indicator for use
    notify_register_dispatch("me.lightmann.quorra/micActive", &notify_token2, dispatch_get_main_queue(), ^(int token) {
        [[[FlynnsArcade sharedInstance] container].orangeDot setHidden:NO];
    });
	notify_register_dispatch("me.lightmann.quorra/micInactive", &notify_token2, dispatch_get_main_queue(), ^(int token) {
        [[[FlynnsArcade sharedInstance] container].orangeDot setHidden:YES];
    });
}
%end

%end


%group gpsIndicator
/* Quorra now checks for when the device's location is actively being updated, not if it has been or is stored, like previous builds did. 
   A CLLocation can be stored (i.e. updated once and then stored -- like w the weather) or it can be updated constantly (like w the compass) */

//Determine when location is being pulled (i.e. gps in use) 
%hook CLLocationManagerStateTracker
-(void)setUpdatingLocation:(BOOL)arg1 {
	%orig;

	if(arg1)
		CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("me.lightmann.quorra/gpsActive"), nil, nil, true);
	
	else if (!arg1)
		CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("me.lightmann.quorra/gpsInactive"), nil, nil, true);
	
	else 
		%orig;
}
%end

%hook FlynnsArcade
+(void)initialize{
	%orig;

    int notify_token2;

    // change location indicator for use
    notify_register_dispatch("me.lightmann.quorra/gpsActive", &notify_token2, dispatch_get_main_queue(), ^(int token) {
        [[[FlynnsArcade sharedInstance] container].blueDot setHidden:NO];
    });
	notify_register_dispatch("me.lightmann.quorra/gpsInactive", &notify_token2, dispatch_get_main_queue(), ^(int token) {
        [[[FlynnsArcade sharedInstance] container].blueDot setHidden:YES];
    });
}
%end

%end



//	PREFERENCES 
static void loadPrefs() {
  NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/me.lightmann.quorraprefs.plist"];

  if(prefs){
    isEnabled = ( [prefs objectForKey:@"isEnabled"] ? [[prefs objectForKey:@"isEnabled"] boolValue] : YES );
	gpsIndicator = ( [prefs objectForKey:@"gpsIndicator"] ? [[prefs objectForKey:@"gpsIndicator"] boolValue] : YES );
	micIndicator = ( [prefs objectForKey:@"micIndicator"] ? [[prefs objectForKey:@"micIndicator"] boolValue] : YES );
	camIndicator = ( [prefs objectForKey:@"camIndicator"] ? [[prefs objectForKey:@"camIndicator"] boolValue] : YES );
  }
}

static void initPrefs() {
  // Copy the default preferences file when the actual preference file doesn't exist
  NSString *path = @"/User/Library/Preferences/me.lightmann.quorraprefs.plist";
  NSString *pathDefault = @"/Library/PreferenceBundles/QuorraPrefs.bundle/defaults.plist";
  NSFileManager *fileManager = [NSFileManager defaultManager];
  if(![fileManager fileExistsAtPath:path]) {
    [fileManager copyItemAtPath:pathDefault toPath:path error:nil];
  }
}

%ctor {
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, (CFNotificationCallback)loadPrefs, CFSTR("me.lightmann.quorraprefs-updated"), NULL, CFNotificationSuspensionBehaviorCoalesce);
	initPrefs();
	loadPrefs();

	if(isEnabled){
		%init(general)

		if(gpsIndicator)
			%init(gpsIndicator)
		
		if(micIndicator)
			%init(micIndicator)

		if(camIndicator)
			%init(camIndicator)
	}
}
