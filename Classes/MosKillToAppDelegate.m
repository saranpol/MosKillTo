//
//  MosKillToAppDelegate.m
//  MosKillTo
//
//  Created by Sittiphol Phanvilai on 21/1/2009.
//  Copyright Neuvex 2009. All rights reserved.
//

#import "MosKillToAppDelegate.h"
#import "EAGLView.h"
#import "oalPlayback.h"

#define kUserNameDefaultKey			@"userName"   // NSString
#define kFontName					@"Arial Rounded MT Bold"
#define kStatusFontSize				30

//NSString *kRestoreDataKey = @"RestoreData";	// preference key to obtain our restore save data
NSString *kLevelKey = @"Level";
NSString *kReachLevelKey = @"ReachLevel";
NSString *kClockKey = @"Clock";
NSString *kStateKey = @"State";
NSString *kMosNumKey = @"MosNum";
NSString *kItemNumKey = @"ItemNum";
NSString *kMosListKey = @"MosList";
NSString *kHighscoreListKey = @"HighscoreList";
NSString *kAngleKey = @"Angle";
NSString *kLookAngleKey = @"LookAngle";
NSString *kCurrentGunKey = @"CurrentGun";
NSString *kCurrentScoreKey = @"CurrentScore";
NSString *kHighScoreIndexKey = @"HighScoreIndex";
NSString *kCurrentMapKey = @"CurrentMap";
NSString *kBullet2Key = @"Bullet2";
NSString *kBullet3Key = @"Bullet3";
NSString *kBullet4Key = @"Bullet4";
NSString *kHpKey = @"Hp";


@implementation MosKillToAppDelegate

@synthesize window;
@synthesize glView;
@synthesize playback;

//@synthesize savedData;
@synthesize level;
@synthesize reach_level;
@synthesize clock;
@synthesize state;
@synthesize mos_num;
@synthesize mos_list;
@synthesize highscore_list;
@synthesize angle;
@synthesize lookangle;
@synthesize current_gun;
@synthesize current_score;
@synthesize highscore_index;
@synthesize current_map;
@synthesize bullet_2, bullet_3, bullet_4;
@synthesize hp;

- (NSNumber *)restoreInteger:(NSString *)key initValue:(int)i{
	
	NSNumber *tempNumberCopy;
	
	tempNumberCopy = [[[NSUserDefaults standardUserDefaults] objectForKey:key] copy];
	if(tempNumberCopy == nil){
		tempNumberCopy = [[NSNumber numberWithInteger:i] retain];
	}else{
		printf("%s %i\n", [key UTF8String], [tempNumberCopy integerValue]);
	}
	//printf("clockddsss %p %p\n", self.clock, var);
	// register our preference selection data to be archived
	NSDictionary *Dict = [NSDictionary dictionaryWithObject:tempNumberCopy forKey:key];
	[[NSUserDefaults standardUserDefaults] registerDefaults:Dict];
	return tempNumberCopy;
}

- (NSNumber *)restoreFloat:(NSString *)key initValue:(int)i{
	
	NSNumber *tempNumberCopy;
	
	tempNumberCopy = [[[NSUserDefaults standardUserDefaults] objectForKey:key] copy];
	if(tempNumberCopy == nil){
		tempNumberCopy = [[NSNumber numberWithFloat:i] retain];
	}else{
		printf("%s %i\n", [key UTF8String], [tempNumberCopy floatValue]);
	}
	//printf("clockddsss %p %p\n", self.clock, var);
	// register our preference selection data to be archived
	NSDictionary *Dict = [NSDictionary dictionaryWithObject:tempNumberCopy forKey:key];
	[[NSUserDefaults standardUserDefaults] registerDefaults:Dict];
	return tempNumberCopy;
}


- (void) refresh_loading:(int)i {
	load_progress+= i;
	[glView drawView];
}

#define MAX_LENGTH 7

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
	//printf("asdf %i %i %i\n", textField.text.length, range.length, string.length);
    //if (textField.text.length >= MAX_LENGTH && range.length == 0 )
	if (textField.text.length >= MAX_LENGTH && string.length > 0 )
    {
        return NO; // return NO to not change text
    }
    else
    {return YES;}
}

- (void) load_resource {

	playback = [[oalPlayback alloc] init];

	[self refresh_loading:10]; // 1
	
	//Create and editable text field. This is used only when the user successfully lands the rocket.
	_textField = [[UITextField alloc] initWithFrame:CGRectMake(60, 210, 200, 40)];
	[_textField setDelegate:self];
	[_textField setBackgroundColor:[UIColor colorWithWhite:0.0 alpha:1.0]];
	[_textField setTextColor:[UIColor whiteColor]];
	[_textField setFont:[UIFont fontWithName:kFontName size:kStatusFontSize]];
	[_textField setPlaceholder:@"Your Name"];	
	
	
	NSNumber *tempNumberCopy;
	
	tempNumberCopy = [self restoreInteger:kLevelKey initValue:1];
	self.level = tempNumberCopy;
	[tempNumberCopy release];

	tempNumberCopy = [self restoreInteger:kReachLevelKey initValue:0];
	self.reach_level = tempNumberCopy;
	[tempNumberCopy release];
	
	tempNumberCopy = [self restoreInteger:kClockKey initValue:0];
	self.clock = tempNumberCopy;
	[tempNumberCopy release];
	
	tempNumberCopy = [self restoreInteger:kStateKey initValue:0];
	self.state = tempNumberCopy;
	[tempNumberCopy release];
	
	tempNumberCopy = [self restoreInteger:kMosNumKey initValue:0];
	self.mos_num = tempNumberCopy;
	[tempNumberCopy release];
	
	tempNumberCopy = [self restoreInteger:kCurrentGunKey initValue:1];
	self.current_gun = tempNumberCopy;
	[tempNumberCopy release];
	
	tempNumberCopy = [self restoreInteger:kCurrentScoreKey initValue:0];
	self.current_score = tempNumberCopy;
	[tempNumberCopy release];

	tempNumberCopy = [self restoreInteger:kHighScoreIndexKey initValue:-1];
	self.highscore_index = tempNumberCopy;
	[tempNumberCopy release];
	
	tempNumberCopy = [self restoreInteger:kCurrentMapKey initValue:1];
	self.current_map = tempNumberCopy;
	[tempNumberCopy release];
	
	tempNumberCopy = [self restoreInteger:kBullet2Key initValue:0];
	self.bullet_2 = tempNumberCopy;
	[tempNumberCopy release];
	
	tempNumberCopy = [self restoreInteger:kBullet3Key initValue:0];
	self.bullet_3 = tempNumberCopy;
	[tempNumberCopy release];
	
	tempNumberCopy = [self restoreInteger:kBullet4Key initValue:0];
	self.bullet_4 = tempNumberCopy;
	[tempNumberCopy release];
	
	tempNumberCopy = [self restoreInteger:kHpKey initValue:HP_MAX];
	self.hp = tempNumberCopy;
	[tempNumberCopy release];
	
	tempNumberCopy = [self restoreFloat:kAngleKey initValue:0];
	self.angle = tempNumberCopy;
	[tempNumberCopy release];
	
	tempNumberCopy = [self restoreFloat:kLookAngleKey initValue:0];
	self.lookangle = tempNumberCopy;
	[tempNumberCopy release];
	

	NSMutableArray *tempMutableCopy = [[[NSUserDefaults standardUserDefaults] objectForKey:kMosListKey] mutableCopy];
	self.mos_list = tempMutableCopy;
	[tempMutableCopy release];
	if(mos_list == nil){
		mos_list = [[NSMutableArray arrayWithObjects:nil] retain];
	}
	// register our preference selection data to be archived
	NSDictionary *mosListDict = [NSDictionary dictionaryWithObject:mos_list forKey:kMosListKey];
	[[NSUserDefaults standardUserDefaults] registerDefaults:mosListDict];
	
	
	tempMutableCopy = [[[NSUserDefaults standardUserDefaults] objectForKey:kHighscoreListKey] mutableCopy];
	self.highscore_list = tempMutableCopy;
	[tempMutableCopy release];
	if(highscore_list == nil || [highscore_list count] < HIGHSCORE_KEEP_NUM){
		//highscore_list = [[NSMutableArray arrayWithObjects:nil] retain];
		highscore_list = [[NSMutableArray arrayWithCapacity:HIGHSCORE_KEEP_NUM] retain];
		int i;
		for(i=0; i<HIGHSCORE_KEEP_NUM; i++)
			[highscore_list insertObject:[NSMutableArray arrayWithObjects:
										  @"-",
										  [NSNumber numberWithInteger:0],
										  nil] atIndex:i];
	}
	// register our preference selection data to be archived
	NSDictionary *highscoreListDict = [NSDictionary dictionaryWithObject:highscore_list forKey:kHighscoreListKey];
	[[NSUserDefaults standardUserDefaults] registerDefaults:highscoreListDict];
	
	//int i;
	//for(i=0; i<[highscore_list count]; i++){
	//	printf("ddd %i\n", i);
	//	//	printf("score %i %s %i\n", i+1, [[[highscore_list objectAtIndex:i] objectAtIndex:0] UTF8String]
	//		   , [[[highscore_list objectAtIndex:i] objectAtIndex:1] integerValue]);
	//}
	
	[self refresh_loading:10]; // 2

	[[NSUserDefaults standardUserDefaults] synchronize];
	
	
	
	
	
	[glView initGame];
	
	[self refresh_loading:10]; // 3
	
	// init Accelerometer
	UIAccelerometer*  theAccelerometer = [UIAccelerometer sharedAccelerometer]; 
    theAccelerometer.updateInterval = 1.0 / 60.0; 
    theAccelerometer.delegate = self;
}


- (void)applicationDidFinishLaunching:(UIApplication *)application {
	// No dimming while play game
	load_progress = 0;
	application.idleTimerDisabled = YES;
	glView.animationInterval = 1.0 / 60.0;
	[glView startAnimation];
	glView.delegate = self;
	[glView load_loading_texture];
}

- (void)showTextField {
	//Show text field that allows the user to enter a name for the score
	[_textField setText:[[NSUserDefaults standardUserDefaults] stringForKey:kUserNameDefaultKey]];
	[window addSubview:_textField];

	// show keyboard
	//[_textField becomeFirstResponder];
}

- (void)applicationWillTerminate:(UIApplication *)application {
	// save the drill-down hierarchy of selections to preferences

	//[savedData replaceObjectAtIndex:0 withObject:[NSNumber numberWithInteger:2]];

	[level release];
	level = [[NSNumber numberWithInteger:glView.level] retain];

	[reach_level release];
	reach_level = [[NSNumber numberWithInteger:glView.reach_level] retain];
	
	[clock release];
	clock = [[NSNumber numberWithInteger:glView.clock] retain];

	[state release];
	state = [[NSNumber numberWithInteger:glView.game_state] retain];

	[mos_num release];
	mos_num = [[NSNumber numberWithInteger:glView.mos_num] retain];

	[current_gun release];
	current_gun = [[NSNumber numberWithInteger:glView.current_gun] retain];

	[current_score release];
	current_score = [[NSNumber numberWithInteger:glView.current_score] retain];

	[highscore_index release];
	highscore_index = [[NSNumber numberWithInteger:glView.highscore_index] retain];
	
	[current_map release];
	current_map = [[NSNumber numberWithInteger:glView.current_map] retain];
	
	[bullet_2 release];
	bullet_2 = [[NSNumber numberWithInteger:glView.bullet_2] retain];

	[bullet_3 release];
	bullet_3 = [[NSNumber numberWithInteger:glView.bullet_3] retain];

	[bullet_4 release];
	bullet_4 = [[NSNumber numberWithInteger:glView.bullet_4] retain];

	[hp release];
	hp = [[NSNumber numberWithInteger:glView.hp] retain];

	[angle release];
	angle = [[NSNumber numberWithFloat:glView.angle] retain];

	[lookangle release];
	lookangle = [[NSNumber numberWithFloat:glView.lookangle] retain];

	
	int i;
	[mos_list removeAllObjects];
	for(i=0; i < [mos_num integerValue]; i++){
		float x,y,z,way;
		int status, frame;
		x = glView.mos_list[i]->x;
		y = glView.mos_list[i]->y;
		z = glView.mos_list[i]->z;
		way = glView.mos_list[i]->way;
		status = glView.mos_list[i]->status;
		frame = glView.mos_list[i]->frame;
		
		[mos_list addObject:[NSMutableArray arrayWithObjects:
								[NSNumber numberWithFloat:x],
								[NSNumber numberWithFloat:y],
								[NSNumber numberWithFloat:z],
								[NSNumber numberWithFloat:way],
								[NSNumber numberWithInteger:status],
 								[NSNumber numberWithInteger:frame],
								nil] ];
	}
	
	//[[NSUserDefaults standardUserDefaults] setObject:savedData forKey:kRestoreDataKey];
	[[NSUserDefaults standardUserDefaults] setObject:level forKey:kLevelKey];
	[[NSUserDefaults standardUserDefaults] setObject:reach_level forKey:kReachLevelKey];
	[[NSUserDefaults standardUserDefaults] setObject:clock forKey:kClockKey];
	[[NSUserDefaults standardUserDefaults] setObject:state forKey:kStateKey];
	[[NSUserDefaults standardUserDefaults] setObject:mos_num forKey:kMosNumKey];
	[[NSUserDefaults standardUserDefaults] setObject:current_gun forKey:kCurrentGunKey];
	[[NSUserDefaults standardUserDefaults] setObject:current_score forKey:kCurrentScoreKey];
	[[NSUserDefaults standardUserDefaults] setObject:highscore_index forKey:kHighScoreIndexKey];
	[[NSUserDefaults standardUserDefaults] setObject:current_map forKey:kCurrentMapKey];
	[[NSUserDefaults standardUserDefaults] setObject:bullet_2 forKey:kBullet2Key];
	[[NSUserDefaults standardUserDefaults] setObject:bullet_3 forKey:kBullet3Key];
	[[NSUserDefaults standardUserDefaults] setObject:bullet_4 forKey:kBullet4Key];
	[[NSUserDefaults standardUserDefaults] setObject:hp forKey:kHpKey];
	[[NSUserDefaults standardUserDefaults] setObject:angle forKey:kAngleKey];
	[[NSUserDefaults standardUserDefaults] setObject:lookangle forKey:kLookAngleKey];
	[[NSUserDefaults standardUserDefaults] setObject:mos_list forKey:kMosListKey];
	
}

- (void)applicationWillResignActive:(UIApplication *)application {
	glView.animationInterval = 1.0 / 5.0;
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
	glView.animationInterval = 1.0 / 60.0;
}


// UIAccelerometerDelegate method, called when the device accelerates.
- (void)accelerometer:(UIAccelerometer *)accelerometer didAccelerate:(UIAcceleration *)acceleration {
	[glView accelerometer:acceleration];
}


- (void)resetScore {
	int i;
	for(i=0; i<[highscore_list count]; i++){
		[highscore_list replaceObjectAtIndex:i withObject:[NSMutableArray arrayWithObjects:
														   @"-",
														   [NSNumber numberWithInteger:0],
														   nil]
		 ];
	}
	[[NSUserDefaults standardUserDefaults] setObject:highscore_list forKey:kHighscoreListKey];
}

- (void)saveScore {

	int score = glView.current_score;
	int i = glView.highscore_index;
	int current_level = glView.level;
	
//	[highscore_list insertObject:[NSMutableArray arrayWithObjects:
//								  [_textField text],
//								  [NSNumber numberWithInteger:score],
//								  nil] atIndex:i];
	// 0 1 2 3 4 level=1
	// 5 6 7 8 9 level=2
	
	// shift 
	int j = current_level*HIGHSCORE_PER_STAGE - 1;
	int k;
	for(k=j; k>i; k--){
		[highscore_list replaceObjectAtIndex:k withObject:[highscore_list objectAtIndex:k-1]];
	}
	
	if([_textField text] == nil)
		_textField.text = [[NSString alloc] initWithString:@"<noname>"];
	
	[highscore_list replaceObjectAtIndex:i withObject:[NSMutableArray arrayWithObjects:
													   [_textField text],
													   [NSNumber numberWithInteger:score],
													   nil]
	];
	
	[[NSUserDefaults standardUserDefaults] setObject:highscore_list forKey:kHighscoreListKey];
	
	
	//glView.game_state = NewHighScore;
	
	// Free highscore_texture_list to force it refresh if it already created
	[glView freeHighscore_texture_list];
	
	//Dismiss text field
	[_textField endEditing:YES];
	[_textField removeFromSuperview];
}

// Saves the user name and score after the user enters it in the provied text field. 
- (void)textFieldDidEndEditing:(UITextField*)textField {
	//Save name
	[[NSUserDefaults standardUserDefaults] setObject:[textField text] forKey:kUserNameDefaultKey];
}

// Terminates the editing session
- (BOOL)textFieldShouldReturn:(UITextField*)textField {
	//Terminate editing
	[textField resignFirstResponder];
	
	return YES;
}


- (void)dealloc {
	[window release];
	[glView release];
	[playback release];

	//[savedData release];
	[level release];
	[clock release];
	[state release];
	[mos_num release];
	[current_gun release];
	[current_score release];
	[current_map release];
	[bullet_2 release];
	[bullet_3 release];
	[bullet_4 release];
	[hp release];
	[angle release];
	[lookangle release];
	[mos_list release];
	
	
	[_textField release];
	
	[super dealloc];
}

@end
