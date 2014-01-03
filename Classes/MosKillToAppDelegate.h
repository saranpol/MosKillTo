//
//  MosKillToAppDelegate.h
//  MosKillTo
//
//  Created by Sittiphol Phanvilai on 21/1/2009.
//  Copyright __MyCompanyName__ 2009. All rights reserved.
//

#import <UIKit/UIKit.h>

@class EAGLView;
@class oalPlayback;

@interface MosKillToAppDelegate : NSObject <UIAccelerometerDelegate, UITextFieldDelegate> {
    UIWindow *window;
    EAGLView *glView;
	
	oalPlayback *playback;
	
	
	UITextField*			_textField;
	
	//NSMutableArray		*savedData;	// an array of selections for each drill level
	NSNumber *level;
	NSNumber *reach_level;
	NSNumber *clock;
	NSNumber *state;
	NSNumber *mos_num;
	NSMutableArray *mos_list;
	NSMutableArray *highscore_list;
	
	NSNumber *angle;
	NSNumber *lookangle;
	NSNumber *current_gun;
	NSNumber *current_score;
	NSNumber *highscore_index;
	NSNumber *current_map;
	NSNumber *bullet_2, *bullet_3, *bullet_4;
	NSNumber *hp;

@public
	int load_progress;
	
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet EAGLView *glView;
@property (nonatomic, retain) oalPlayback *playback;

//@property (nonatomic, retain) NSMutableArray *savedData;
@property (nonatomic, retain) NSNumber *level;
@property (nonatomic, retain) NSNumber *reach_level;
@property (nonatomic, retain) NSNumber *clock;
@property (nonatomic, retain) NSNumber *state;
@property (nonatomic, retain) NSNumber *mos_num;
@property (nonatomic, retain) NSMutableArray *mos_list;
@property (nonatomic, retain) NSMutableArray *highscore_list;
@property (nonatomic, retain) NSNumber *angle;
@property (nonatomic, retain) NSNumber *lookangle;
@property (nonatomic, retain) NSNumber *current_gun;
@property (nonatomic, retain) NSNumber *current_score;
@property (nonatomic, retain) NSNumber *highscore_index;
@property (nonatomic, retain) NSNumber *current_map;
@property (nonatomic, retain) NSNumber *bullet_2, *bullet_3, *bullet_4;
@property (nonatomic, retain) NSNumber *hp;

- (void)showTextField;
- (void)load_resource;
- (void)refresh_loading:(int)i;
- (void)saveScore;
- (void)resetScore;

@end

