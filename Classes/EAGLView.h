//
//  EAGLView.h
//  MosKillTo
//
//  Created by Sittiphol Phanvilai on 21/1/2009.
//  Copyright __MyCompanyName__ 2009. All rights reserved.
//


#import <UIKit/UIKit.h>
#import <OpenGLES/EAGL.h>
#import <OpenGLES/ES1/gl.h>
#import <OpenGLES/ES1/glext.h>
#import "Texture2D.h"

@class MosKillToAppDelegate;

/*
This class wraps the CAEAGLLayer from CoreAnimation into a convenient UIView subclass.
The view content is basically an EAGL surface you render your OpenGL scene into.
Note that setting the view non-opaque will only work if the EAGL surface has an alpha channel.
*/
#define FRUSTUM_FAR  4000.f     //far depth clipping plane

#define FRUSTUM_LEFT   -0.04142f     //left vertical clipping plane
#define FRUSTUM_RIGHT   0.04142f     //right vertical clipping plane
#define FRUSTUM_BOTTOM -0.04142f     //bottom horizontal clipping plane
#define FRUSTUM_TOP     0.04142f     //top horizontal clipping plane
#define FRUSTUM_NEAR    0.1f     //near depth clipping plane

#define HP_MAX 2000.0
#define MAX_ROOM 4
#define LEVEL_PER_ROOM 4
#define MAX_LEVEL 16

#define MAX_SHOW_MOS 50

#define HIGHSCORE_KEEP_NUM 80  // 16 stage x 5 = 80
#define HIGHSCORE_PER_STAGE 5

enum state { Menu=0, Map, MapHighScore, NewHighScore, StageLoading, 
			Playing, Pause, Win, Lose, EnterNewHighScore, 
			Highscore, Options, Credits, Congratulations};

enum mos_status { Dead=0, Mos_hit, Mos_normal, Mos_big_1, Mos_big_2, Mos_big_3, Mos_bite, Mos_go, Item_bullet_2, Item_bullet_3, Item_bullet_4, Item_heal};

enum button_status { Normal=0, Down=1 };

struct Spice3d {
	float x,y,z;
	int frame;
	struct Spice3d *next, *prev;
} Spice3d;

struct Mosquito {
	GLfloat x,y,z;
	float x0,y0,z0,way;
	int status, frame;
} Mosquito;

struct Image2d {
	GLfloat Vertices[8];
	GLfloat Texcoords[8];
} Image2d;

struct Button {
	struct Image2d image_button;
	GLuint *iNormal;
	GLuint *iDown;
	int status; // 0 normal 1 down
	int sound;
} Button;

struct Text{
	Texture2D *text;
	float r,g,b; // Color
	CGPoint	p;
} Text;

@interface EAGLView : UIView {
    
@private
    /* The pixel dimensions of the backbuffer */
    GLint backingWidth;
    GLint backingHeight;
    
    EAGLContext *context;
    
    /* OpenGL names for the renderbuffer and framebuffers used to render to this view */
    GLuint viewRenderbuffer, viewFramebuffer;
    
    /* OpenGL name for the depth buffer that is attached to viewFramebuffer, if it exists (0 if it does not exist) */
    GLuint depthRenderbuffer;
    
	struct Image2d image_dialog_small;
	struct Image2d image_dialog_big;
	
	struct Image2d image_full;
	struct Image2d image_hpFrame;
	struct Image2d image_start_game;
	struct Image2d image_options;
	struct Image2d image_credits;
	
	struct Image2d image_gun_effect;
	
	struct Image2d image_stage_loading_bar;

	struct Image2d image_top_bar;
	struct Image2d image_top_bar_hp;

	struct Image2d image_time_m1;
	struct Image2d image_time_m0;	
	struct Image2d image_time_colon;	
	struct Image2d image_time_s1;	
	struct Image2d image_time_s0;	

	struct Image2d image_mos_left_x;
	struct Image2d image_mos_left_2;
	struct Image2d image_mos_left_1;
	struct Image2d image_mos_left_0;	

	struct Image2d image_logo_neuvex;
	struct Image2d image_logo_sipa;
	
	struct Image2d image_control_bar;
	struct Image2d image_you_are;
	struct Image2d image_mask;
	struct Image2d image_new_highscore;
	
	struct Button button_start_game;
	struct Button button_options;
	struct Button button_credits;
	struct Button button_pause;
	struct Button button_resume;
	struct Button button_next_instruction;
	struct Button button_exit;

	struct Button button_reset_level;
	struct Button button_reset_highscore;
	struct Button button_exit_big_dialog;
	
	// map ui
	struct Button button_quit;
	struct Button button_next;	
	struct Button button_prev;
	struct Button button_stage_point[MAX_LEVEL];
	
	// map high score
	struct Button button_yes_play_now;
	struct Button button_no_play_now;

	struct Button button_ok;

	
	struct Button button_ok_win;
	struct Button button_save_score;
	struct Button button_yes_retry;
	struct Button button_no_retry;
	
	/* OpenGL name for the sprite texture */

	GLuint iDialogBig;
	GLuint iDialogSmall;
	GLuint iDialogMiddle;

	GLuint iLogoNeuvex;
	GLuint iLogoSipa;
	
	GLuint iStageLoadingBar;
	
	GLuint iMenuButton;
	GLuint iMenuButtonOver;
	GLuint iStartGame;
	GLuint iOptions;
	GLuint iCredits;

	GLuint iStagePoint;
	GLuint iStagePointOver;
	
	GLuint iOk;
	GLuint iOkOver;
	GLuint iQuitOver;
	GLuint iQuit;
	GLuint iPrevButton;
	GLuint iPrevButtonOver;
	GLuint iNextButton;
	GLuint iNextButtonOver;
	
	
	GLuint iPauseTexture;
	GLuint iResumeTexture;
	GLuint iExitTexture;
	GLuint iRetryTexture;
	GLuint iYouWinTexture;
	GLuint iYouLostTexture;
	GLuint iNewHighscore;
	GLuint iPhone_h1, iPhone_h2, iPhone_h3, iPhone_h4;
	GLuint iArrow;
	
	GLuint iRoom_top;
	GLuint iRoom_bottom;
	GLuint iRoom_front;
	GLuint iRoom_right;
	GLuint iRoom_left;
	GLuint iRoom_back;

	GLuint iMos_1;
	GLuint iMos_2;
	GLuint iMos_3;
	GLuint iMos_4;
	GLuint iMosBite_1;
	GLuint iMosBite_2;
	GLuint iMosBite_3;
	GLuint iMosBite_4;
	GLuint iMosBig_1;
	GLuint iMosBig_2;
	GLuint iMosBig_3;
	GLuint iMosBig_4;
	GLuint iMosHit_1;
	GLuint iMosHit_2;
	GLuint iMosHit_3;
	GLuint iMosHit_4;
	GLuint iMosHit_5;
	GLuint iMosHit_6;
	GLuint iMosHit_7;

	
	GLuint iControlBar;
	GLuint iGun1, iGun2, iGun3, iGun4;
	GLuint iGun1Shot, iGun2Shot, iGun3Shot, iGun4Shot;
	GLuint iGun4Effect[9];
	GLuint iMask;
	GLuint iHeal;
	GLuint iItemGun2, iItemGun3, iItemGun4;
	GLuint iBulletHole;
	GLuint iCrossHair;
	GLuint iLoading;
	GLuint iLoadingFrame;
	GLuint iTopBar;
	GLuint iTopBarHp;
	
	GLuint iMenuBg;
	GLuint iMapBg;
	GLuint iMap1;
	GLuint iMap2;
	GLuint iMap3;
	GLuint iMap4;
	
	GLuint iDigit0;
	GLuint iDigit1;
	GLuint iDigit2;
	GLuint iDigit3;
	GLuint iDigit4;
	GLuint iDigit5;
	GLuint iDigit6;
	GLuint iDigit7;
	GLuint iDigit8;
	GLuint iDigit9;
	GLuint iColon;
	GLuint iDigitX;
	

	GLfloat angle;
	GLfloat lookangle;	
	GLfloat iX, iY, iZ, iX0, iX1, iX2, iY1, iZ0, iZ1, iZ2;

    NSTimer *animationTimer;
    NSTimeInterval animationInterval;

	
	
	MosKillToAppDelegate *delegate;
	struct Mosquito **mos_list;
	struct Spice3d *bullet_hole_list;
	
	int mos_num;
	int mos_left;
	int mos_left_show;
	
	int game_state;
	int clock;
	int clock_limit;
	int level;
	int time_left_count;
	int current_score;
	int current_map;
	int reach_level;
	int current_gun;
	int gun_time;
	int bullet_2, bullet_3, bullet_4;
	int hp;
	int current_room;
	Boolean gun_hold;
	Boolean gun_4_hold;
	
	int highscore_index;
	float step_go;
	int tutorial_step;
	
	int stage_load_progress;
	
	Texture2D** highscore_texture_list;
	Texture2D** number_texture_list;
	
	// Text
	struct Text text_highscores;
	struct Text text_loading;
	struct Text text_select_stage;
	struct Text text_stage_name;
	struct Text text_map_name;
	struct Text text_level;
	struct Text text_title;
	struct Text text_score;
	struct Text text_time_bonus;
	struct Text text_health_bonus;
	struct Text text_play_now;
	struct Text text_enter_your_name;
	struct Text text_retry;
	struct Text text_credits;
	struct Text text_congratulations;
	struct Text text_reset_level;
	struct Text text_reset_highscore;
	
	NSMutableDictionary *thumbnailCache;
}

@property (nonatomic, assign) MosKillToAppDelegate *delegate;
@property NSTimeInterval animationInterval;
@property int clock;
@property int level;
@property int game_state;
@property int mos_num;
@property struct Mosquito **mos_list;
@property GLfloat angle;
@property GLfloat lookangle;
@property int current_gun;
@property int current_score;
@property int current_map;
@property int bullet_2, bullet_3, bullet_4;
@property int hp;
@property int highscore_index;
@property int reach_level;

- (void)setupTexture:(NSString *)image_name textureVar:(GLuint *)texture_var;
- (void)startAnimation;
- (void)initGame;
- (void)stopAnimation;
- (void)drawView;
- (void)shot;
- (void)free_mosquito;
- (void)freeHighscore_texture_list;
- (void)add_mosquito:(int)num list:(NSMutableArray *)ml;
- (void)accelerometer:(UIAcceleration *)acceleration;
- (void)SmoothOutRawDataX:(float)aX Y:(float)aY Z:(float)aZ;
- (void)load_loading_texture;

@end
