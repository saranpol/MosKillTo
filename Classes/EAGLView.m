//
//  EAGLView.m
//  MosKillTo
//
//  Created by Sittiphol Phanvilai on 21/1/2009.
//  Copyright __MyCompanyName__ 2009. All rights reserved.
//



#import <QuartzCore/QuartzCore.h>
#import <OpenGLES/EAGLDrawable.h>
#import <AudioToolbox/AudioToolbox.h>

#import "EAGLView.h"
#import "MosKillToAppDelegate.h"
#import "oalPlayback.h"

#define USE_DEPTH_BUFFER 1

#define kScoreFontName				@"Arial Rounded MT Bold"
#define kScoreFontSize				18
#define kInstFontSize				24



// Constant for the number of times per second (Hertz) to sample acceleration.
#define kAccelerometerFrequency     40
#define TO_RADIAN 0.0174532925
#define TO_DEGREE 57.2957795



//-------------------- start light ---------------------
// MACROS
#define MATERIAL_MAX 1
#define MATERIALCOLOR(r, g, b, a)     \
(GLfloat)(r * MATERIAL_MAX),   \
(GLfloat)(g * MATERIAL_MAX),   \
(GLfloat)(b * MATERIAL_MAX),   \
(GLfloat)(a * MATERIAL_MAX)

#define LIGHT_MAX    (1 << 16)
#define LIGHTCOLOR(r, g, b, a)       \
(GLfixed)(r * LIGHT_MAX),     \
(GLfixed)(g * LIGHT_MAX),     \
(GLfixed)(b * LIGHT_MAX),     \
(GLfixed)(a * LIGHT_MAX)

/* Define global ambient light. */
//static const GLfixed globalAmbient[4]      = { LIGHTCOLOR(0.4, 0.4, 0.4, 1.0) };
static const GLfixed globalAmbient[4]      = { LIGHTCOLOR(1.0, 1.0, 1.0, 1.0) };

/* Define lamp parameters. */
static const GLfixed lightDiffuseLamp[4]   = { LIGHTCOLOR(0.5, 0.5, 0.5, 1.0) };
static const GLfixed lightAmbientLamp[4]   = { LIGHTCOLOR(0.3, 0.3, 0.3, 1.0) };
static const GLfixed lightSpecularLamp[4]  = { LIGHTCOLOR(1.0, 1.0, 1.0, 1.0) };
static const GLfixed lightPositionLamp[4]  = { 1, 2, 0, 0 };

//static const GLfloat objEmissionDuck[4] = { MATERIALCOLOR(0.0, 0.0, 0.0, 1.0) };
static const GLfloat objEmissionDuck[4] = { MATERIALCOLOR(0.5, 0.5, 0.5, 1.0) };

#define VN(x,y,z) x * 65536 , y * 65536, z * 65536
//-------------------- end light ---------------------


// A class extension to declare private methods
@interface EAGLView ()

@property (nonatomic, retain) EAGLContext *context;
@property (nonatomic, assign) NSTimer *animationTimer;

- (BOOL) createFramebuffer;
- (void) destroyFramebuffer;

- (void) setupView;

@end


@implementation EAGLView

@synthesize context;
@synthesize animationTimer;
@synthesize animationInterval;
@synthesize level;
@synthesize reach_level;
@synthesize game_state;
@synthesize clock;
@synthesize delegate;
@synthesize mos_num;
@synthesize mos_list;
@synthesize angle;
@synthesize lookangle;
@synthesize current_gun;
@synthesize current_score;
@synthesize current_map;
@synthesize bullet_2, bullet_3, bullet_4;
@synthesize hp;
@synthesize highscore_index;

// You must implement this method
+ (Class)layerClass {
    return [CAEAGLLayer class];
}


//The GL view is stored in the nib file. When it's unarchived it's sent -initWithCoder:
- (id)initWithCoder:(NSCoder*)coder {
    
    if ((self = [super initWithCoder:coder])) {
        // Get the layer
        CAEAGLLayer *eaglLayer = (CAEAGLLayer *)self.layer;
        
        eaglLayer.opaque = YES;
        eaglLayer.drawableProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                        [NSNumber numberWithBool:NO], kEAGLDrawablePropertyRetainedBacking, kEAGLColorFormatRGBA8, kEAGLDrawablePropertyColorFormat, nil];
        
        context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES1];
        
        if (!context || ![EAGLContext setCurrentContext:context]) {
            [self release];
            return nil;
        }
        
        animationInterval = 1.0 / 60.0;
		
		[self setupView];
    }
    return self;
}


- (UIImage*)thumbnailImage:(NSString*)fileName {
	UIImage *thumbnail = [thumbnailCache objectForKey:fileName];
	
	if (nil == thumbnail)
	{
		NSString *thumbnailFile = [NSString stringWithFormat:@"%@/%@", [[NSBundle mainBundle] resourcePath], fileName];
		thumbnail = [UIImage imageWithContentsOfFile:thumbnailFile];
		[thumbnailCache setObject:thumbnail forKey:fileName];
	}
	return thumbnail;
}


- (void)setupTexture:(NSString *)image_name textureVar:(GLuint *)texture_var {
	CGImageRef textureImage;
	CGContextRef textureContext;
	GLubyte *textureData;
	size_t	width, height;
	
	// Creates a Core Graphics image from an image file
	// this fix the problem of memory leak http://www.alexcurylo.com/blog/2009/01/13/imagenamed-is-evil/
	textureImage = [self thumbnailImage:image_name].CGImage;
	//textureImage = [UIImage imageNamed:image_name].CGImage;
	// Get the width and height of the image
	width = CGImageGetWidth(textureImage);
	height = CGImageGetHeight(textureImage);
	// Texture dimensions must be a power of 2. If you write an application that allows users to supply an image,
	// you'll want to add code that checks the dimensions and takes appropriate action if they are not a power of 2.
	
	if (textureImage) {
		// Allocated memory needed for the bitmap context
		textureData = (GLubyte *) malloc(width * height * 4);
		// Uses the bitmatp creation function provided by the Core Graphics framework. 
		textureContext = CGBitmapContextCreate(textureData, width, height, 8, width * 4, CGImageGetColorSpace(textureImage), kCGImageAlphaPremultipliedLast);
		// After you create the context, you can draw the texture image to the context.
		CGContextDrawImage(textureContext, CGRectMake(0.0, 0.0, (CGFloat)width, (CGFloat)height), textureImage);
		// You don't need the context at this point, so you need to release it to avoid memory leaks.
		CGContextRelease(textureContext);
		
		// Use OpenGL ES to generate a name for the texture.
		glGenTextures(1, texture_var);
		// Bind the texture name. 
		glBindTexture(GL_TEXTURE_2D, *texture_var);
		// Speidfy a 2D texture image, provideing the a pointer to the image data in memory
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, textureData);
		// Release the image data
		free(textureData);
		
		// Set the texture parameters to use a minifying filter and a linear filer (weighted average)
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
		

	}
}

- (void)refresh_stage_loading {
	stage_load_progress+= 10;
	[self drawView];	
}

- (void)load_room_texture:(Boolean)progress {
	NSString *s;
	current_room = (current_map-1);
	
	//static int first = 1;
	//if(first == 0)
	//	return;
	//first = 0;
	
	if(iRoom_top) glDeleteTextures(1, &iRoom_top);
	if(iRoom_bottom) glDeleteTextures(1, &iRoom_bottom);
	if(iRoom_right) glDeleteTextures(1, &iRoom_right);
	if(iRoom_left) glDeleteTextures(1, &iRoom_left);
	if(iRoom_front) glDeleteTextures(1, &iRoom_front);
	if(iRoom_back) glDeleteTextures(1, &iRoom_back);
	if(progress) [self refresh_stage_loading]; // 4

	
	s = [[NSString alloc] initWithFormat:@"room%i_top.png", current_room+1];
	[self setupTexture:s textureVar:&iRoom_top];
	[s release];
	if(progress) [self refresh_stage_loading]; // 5

	s = [[NSString alloc] initWithFormat:@"room%i_bottom.png", current_room+1];
	[self setupTexture:s textureVar:&iRoom_bottom];
	[s release];
	if(progress) [self refresh_stage_loading]; // 6

	s = [[NSString alloc] initWithFormat:@"room%i_right.png", current_room+1];
	[self setupTexture:s textureVar:&iRoom_right];
	[s release];
	if(progress) [self refresh_stage_loading]; // 7
	
	s = [[NSString alloc] initWithFormat:@"room%i_left.png", current_room+1];
	[self setupTexture:s textureVar:&iRoom_left];
	[s release];
	if(progress) [self refresh_stage_loading]; // 4

	s = [[NSString alloc] initWithFormat:@"room%i_front.png", current_room+1];
	[self setupTexture:s textureVar:&iRoom_front];
	[s release];
	if(progress) [self refresh_stage_loading]; // 8

	s = [[NSString alloc] initWithFormat:@"room%i_back.png", current_room+1];
	[self setupTexture:s textureVar:&iRoom_back];
	[s release];
	if(progress) [self refresh_stage_loading]; // 9

}	

- (void)setup_image:(struct Image2d *)im x:(float)x y:(float)y w:(float)w h:(float)h mw:(float)mw mh:(float)mh {
	h--;
	w--;
	mh--;
	mw--;
	
	im->Vertices[0] = x;
	im->Vertices[1] = y;
	im->Vertices[2] = x + w;
	im->Vertices[3] = y;
	im->Vertices[4] = x;
	im->Vertices[5] = y + h;
	im->Vertices[6] = x + w;
	im->Vertices[7] = y + h;
	
	im->Texcoords[0] = 0;
	im->Texcoords[1] = h/mh;
	im->Texcoords[2] = w/mw;
	im->Texcoords[3] = h/mh;
	im->Texcoords[4] = 0;
	im->Texcoords[5] = 0;
	im->Texcoords[6] = w/mw;
	im->Texcoords[7] = 0;
	
}


- (void)draw_image:(struct Image2d *)im iTexture:(GLuint)iTexture {
	glBindTexture(GL_TEXTURE_2D, iTexture);
	glVertexPointer(2, GL_FLOAT, 0, im->Vertices);
	glTexCoordPointer(2, GL_FLOAT, 0, im->Texcoords);
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
}

- (void)free_loading_texture {
	glDeleteTextures(1, &iLoading);
	glDeleteTextures(1, &iLoadingFrame);
	glDeleteTextures(1, &iLogoNeuvex);
	glDeleteTextures(1, &iLogoSipa);
}

- (void)load_loading_texture {
	[self setupTexture:@"loading.png" textureVar:&iLoading];
	[self setupTexture:@"loading_frame.png" textureVar:&iLoadingFrame];
	[self setupTexture:@"logo_neuvex.png" textureVar:&iLogoNeuvex];
	[self setupTexture:@"logo_sipa.png" textureVar:&iLogoSipa];

	[self setup_image:&image_logo_neuvex x:32 y:190 w:256 h:128 mw:256 mh:128];
	[self setup_image:&image_logo_sipa x:32 y:190 w:256 h:128 mw:256 mh:128];
}
	

- (void)draw_button:(struct Button *)button {
	if(button->status == Normal)
		[self draw_image:&button->image_button iTexture:*(button->iNormal)];
	else
		[self draw_image:&button->image_button iTexture:*(button->iDown)];
}

- (void)setup_button:(struct Button *)b image2d:(struct Image2d)im iNormal:(GLuint *)iNormal iDown:(GLuint *)iDown s:(int)s {
	b->image_button = im;
	b->iNormal = iNormal;
	b->iDown = iDown;
	b->status = Normal;
	b->sound = s;
}

- (void)setup_buttons {
	// setup button
	struct Image2d image_button;

	[self setup_image:&image_start_game x:62 y:150 w:195 h:53 mw:256 mh:64];
	[self setup_button:&button_start_game image2d:image_start_game iNormal:&iMenuButton iDown:&iMenuButtonOver s:tngdorbl];
	
	[self setup_image:&image_options x:62 y:90 w:195 h:53 mw:256 mh:64];
	[self setup_button:&button_options image2d:image_options iNormal:&iMenuButton iDown:&iMenuButtonOver s:tngdorbl];

	[self setup_image:&image_credits x:62 y:30 w:195 h:53 mw:256 mh:64];
	[self setup_button:&button_credits image2d:image_credits iNormal:&iMenuButton iDown:&iMenuButtonOver s:tngdorbl];
	
	[self setup_image:&image_button x:0 y:413 w:64 h:64 mw:64 mh:64];
	[self setup_button:&button_pause image2d:image_button iNormal:&iPauseTexture iDown:&iPauseTexture s:tngdorbl];

	[self setup_image:&image_button x:95 y:207 w:64 h:64 mw:64 mh:64];	
	[self setup_button:&button_resume image2d:image_button iNormal:&iResumeTexture iDown:&iResumeTexture s:tngdorbl];	
	
	[self setup_image:&image_button x:159 y:207 w:64 h:64 mw:64 mh:64];	
	[self setup_button:&button_exit image2d:image_button iNormal:&iExitTexture iDown:&iExitTexture s:tngdorbl];

	[self setup_image:&image_button x:127 y:347 w:64 h:64 mw:64 mh:64];	
	[self setup_button:&button_next_instruction image2d:image_button iNormal:&iResumeTexture iDown:&iResumeTexture s:tngdorbl];	
	
	// map ui
	
	[self setup_image:&image_button x:280 y:170 w:44 h:82 mw:64 mh:128];	
	[self setup_button:&button_next image2d:image_button iNormal:&iNextButton iDown:&iNextButtonOver s:tngdorbl];

	[self setup_image:&image_button x:0 y:170 w:44 h:82 mw:64 mh:128];	
	[self setup_button:&button_prev image2d:image_button iNormal:&iPrevButton iDown:&iPrevButtonOver s:tngdorbl];

	[self setup_image:&image_button x:250 y:10 w:64 h:64 mw:64 mh:64];	
	[self setup_button:&button_quit image2d:image_button iNormal:&iQuit iDown:&iQuitOver s:tngdorbl];


	// stage point
	[self setup_image:&image_button x:70 y:305 w:64 h:64 mw:64 mh:64];	
	[self setup_button:&button_stage_point[0] image2d:image_button iNormal:&iStagePoint iDown:&iStagePointOver s:gunshot];
	[self setup_image:&image_button x:175 y:250 w:64 h:64 mw:64 mh:64];	
	[self setup_button:&button_stage_point[1] image2d:image_button iNormal:&iStagePoint iDown:&iStagePointOver s:bomb3];
	[self setup_image:&image_button x:125 y:150 w:64 h:64 mw:64 mh:64];	
	[self setup_button:&button_stage_point[2] image2d:image_button iNormal:&iStagePoint iDown:&iStagePointOver s:break_17];
	[self setup_image:&image_button x:220 y:110 w:64 h:64 mw:64 mh:64];	
	[self setup_button:&button_stage_point[3] image2d:image_button iNormal:&iStagePoint iDown:&iStagePointOver s:gunshot];

	[self setup_image:&image_button x:30 y:257 w:64 h:64 mw:64 mh:64];	
	[self setup_button:&button_stage_point[4] image2d:image_button iNormal:&iStagePoint iDown:&iStagePointOver s:bomb3];
	[self setup_image:&image_button x:150 y:240 w:64 h:64 mw:64 mh:64];	
	[self setup_button:&button_stage_point[5] image2d:image_button iNormal:&iStagePoint iDown:&iStagePointOver s:break_17];
	[self setup_image:&image_button x:140 y:150 w:64 h:64 mw:64 mh:64];	
	[self setup_button:&button_stage_point[6] image2d:image_button iNormal:&iStagePoint iDown:&iStagePointOver s:gunshot];
	[self setup_image:&image_button x:155 y:50 w:64 h:64 mw:64 mh:64];	
	[self setup_button:&button_stage_point[7] image2d:image_button iNormal:&iStagePoint iDown:&iStagePointOver s:bomb3];
	
	[self setup_image:&image_button x:75 y:245 w:64 h:64 mw:64 mh:64];	
	[self setup_button:&button_stage_point[8] image2d:image_button iNormal:&iStagePoint iDown:&iStagePointOver s:break_17];
	[self setup_image:&image_button x:95 y:160 w:64 h:64 mw:64 mh:64];	
	[self setup_button:&button_stage_point[9] image2d:image_button iNormal:&iStagePoint iDown:&iStagePointOver s:gunshot];
	[self setup_image:&image_button x:163 y:120 w:64 h:64 mw:64 mh:64];	
	[self setup_button:&button_stage_point[10] image2d:image_button iNormal:&iStagePoint iDown:&iStagePointOver s:bomb3];
	[self setup_image:&image_button x:170 y:45 w:64 h:64 mw:64 mh:64];	
	[self setup_button:&button_stage_point[11] image2d:image_button iNormal:&iStagePoint iDown:&iStagePointOver s:break_17];
	
	[self setup_image:&image_button x:40 y:110 w:64 h:64 mw:64 mh:64];	
	[self setup_button:&button_stage_point[12] image2d:image_button iNormal:&iStagePoint iDown:&iStagePointOver s:gunshot];
	[self setup_image:&image_button x:110 y:195 w:64 h:64 mw:64 mh:64];	
	[self setup_button:&button_stage_point[13] image2d:image_button iNormal:&iStagePoint iDown:&iStagePointOver s:bomb3];
	[self setup_image:&image_button x:165 y:80 w:64 h:64 mw:64 mh:64];	
	[self setup_button:&button_stage_point[14] image2d:image_button iNormal:&iStagePoint iDown:&iStagePointOver s:break_17];
	[self setup_image:&image_button x:230 y:270 w:64 h:64 mw:64 mh:64];	
	[self setup_button:&button_stage_point[15] image2d:image_button iNormal:&iStagePoint iDown:&iStagePointOver s:gunshot];
	
	
	
	
	
	
	// map high score
	[self setup_image:&image_button x:93 y:37 w:64 h:64 mw:64 mh:64];	
	[self setup_button:&button_yes_play_now image2d:image_button iNormal:&iOk iDown:&iOkOver s:tngdorbl];

	[self setup_image:&image_button x:167 y:37 w:64 h:64 mw:64 mh:64];	
	[self setup_button:&button_no_play_now image2d:image_button iNormal:&iQuit iDown:&iQuitOver s:tngdorbl];

	[self setup_image:&image_button x:127 y:37 w:64 h:64 mw:64 mh:64];	
	[self setup_button:&button_ok image2d:image_button iNormal:&iOk iDown:&iOkOver s:tngdorbl];

	
	
	[self setup_image:&image_button x:227 y:70 w:64 h:64 mw:64 mh:64];	
	[self setup_button:&button_ok_win image2d:image_button iNormal:&iOk iDown:&iOkOver s:tngdorbl];

	[self setup_image:&image_button x:127 y:150 w:64 h:64 mw:64 mh:64];	
	[self setup_button:&button_save_score image2d:image_button iNormal:&iOk iDown:&iOkOver s:tngdorbl];


	[self setup_image:&image_button x:93 y:150 w:64 h:64 mw:64 mh:64];	
	[self setup_button:&button_yes_retry image2d:image_button iNormal:&iOk iDown:&iOkOver s:tngdorbl];
	
	[self setup_image:&image_button x:167 y:150 w:64 h:64 mw:64 mh:64];	
	[self setup_button:&button_no_retry image2d:image_button iNormal:&iQuit iDown:&iQuitOver s:tngdorbl];
	

	// options
	[self setup_image:&image_button x:127 y:210 w:64 h:64 mw:64 mh:64];	
	[self setup_button:&button_reset_level image2d:image_button iNormal:&iOk iDown:&iOkOver s:tngdorbl];

	[self setup_image:&image_button x:127 y:110 w:64 h:64 mw:64 mh:64];	
	[self setup_button:&button_reset_highscore image2d:image_button iNormal:&iOk iDown:&iOkOver s:tngdorbl];

	[self setup_image:&image_button x:225 y:37 w:64 h:64 mw:64 mh:64];	
	[self setup_button:&button_exit_big_dialog image2d:image_button iNormal:&iQuit iDown:&iQuitOver s:tngdorbl];

}

- (void)setup_images {
	// setup image Image2d
	float x,y,c;
	[self setup_image:&image_full x:0 y:0 w:320 h:480 mw:512 mh:512];
    //[self setup_image:&image_full x:0 y:0 w:320 h:568 mw:568 mh:568]; // not work
	[self setup_image:&image_hpFrame x:60 y:400 w:256 h:48 mw:256 mh:256];
	
	[self setup_image:&image_stage_loading_bar x:0 y:150 w:320 h:200 mw:512 mh:256];

	[self setup_image:&image_top_bar x:0 y:390 w:320 h:90 mw:512 mh:128];
	[self setup_image:&image_top_bar_hp x:0 y:390 w:320 h:90 mw:512 mh:128];

	x = 128;
	y = 430;
	c = 15;
	[self setup_image:&image_time_m1 x:x y:y w:26 h:26 mw:64 mh:64];
	x += c;
	[self setup_image:&image_time_m0 x:x y:y w:26 h:26 mw:64 mh:64];
	x += 12;
	[self setup_image:&image_time_colon x:x y:y w:26 h:26 mw:64 mh:64];
	x += 12;
	[self setup_image:&image_time_s1 x:x y:y w:26 h:26 mw:64 mh:64];
	x += c;
	[self setup_image:&image_time_s0 x:x y:y w:26 h:26 mw:64 mh:64];

	x = 240;
	[self setup_image:&image_mos_left_x x:x y:y w:26 h:26 mw:64 mh:64];
	x += c;
	[self setup_image:&image_mos_left_2 x:x y:y w:26 h:26 mw:64 mh:64];
	x += c;
	[self setup_image:&image_mos_left_1 x:x y:y w:26 h:26 mw:64 mh:64];
	x += c;
	[self setup_image:&image_mos_left_0 x:x y:y w:26 h:26 mw:64 mh:64];


	[self setup_image:&image_control_bar x:0 y:0 w:320 h:69 mw:512 mh:128];

	[self setup_image:&image_dialog_small x:0 y:130 w:320 h:256 mw:512 mh:256];
	[self setup_image:&image_dialog_big x:0 y:30 w:320 h:480 mw:512 mh:512];
	[self setup_image:&image_you_are x:32 y:275 w:256 h:64 mw:256 mh:64];
	[self setup_image:&image_mask x:32 y:112 w:256 h:256 mw:256 mh:256];
	[self setup_image:&image_new_highscore x:0 y:70 w:256 h:64 mw:256 mh:64];
	
	[self setup_image:&image_gun_effect x:0 y:75 w:320 h:320 mw:256 mh:256];
	image_gun_effect.Texcoords[1] = 1;
	image_gun_effect.Texcoords[2] = 1;
	image_gun_effect.Texcoords[3] = 1;
	image_gun_effect.Texcoords[6] = 1;
}





- (void)draw_text:(struct Text*)text {
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	glColor4f(text->r, text->g, text->b, 1);
	[text->text drawAtPoint:text->p];
	glColor4f(1, 1, 1, 1);
	glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
}

- (void)setup_text_color:(struct Text*)text r:(float)r g:(float)g b:(float)b {
	text->r = r/255;
	text->g = g/255;
	text->b = b/255;
}

- (void)setup_text_level {
	NSString *s = [[NSString alloc] initWithFormat:@"LV%i", level];

	if(text_level.text)
		[text_level.text dealloc];
	text_level.text = [[Texture2D alloc] initWithString:s dimensions:CGSizeMake(64, 32)
										   alignment:UITextAlignmentCenter fontName:kScoreFontName fontSize:16];
	[self setup_text_color:&text_level r:238 g:151 b:0];
	text_level.p = CGPointMake(51, 415);
	[s release];
}



- (void)setup_text_time_bonus {
	int clock_count;
	clock_count = clock / 60;
	time_left_count = clock_limit - clock_count;
	
	NSString *s = [[NSString alloc] initWithFormat:@"Time Bonus : %i", time_left_count*10];
	
	if(text_time_bonus.text)
		[text_time_bonus.text dealloc];
	text_time_bonus.text = [[Texture2D alloc] initWithString:s dimensions:CGSizeMake(256, 64)
												   alignment:UITextAlignmentCenter fontName:kScoreFontName fontSize:20];
	[self setup_text_color:&text_time_bonus r:243 g:247 b:177];
	text_time_bonus.p = CGPointMake(32, 203);
	[s release];
}

- (void)setup_text_health_bonus {
	NSString *s = [[NSString alloc] initWithFormat:@"Health Bonus : %i", (int)(hp*1000/HP_MAX)];
	
	if(text_health_bonus.text)
		[text_health_bonus.text dealloc];
	text_health_bonus.text = [[Texture2D alloc] initWithString:s dimensions:CGSizeMake(256, 64)
													 alignment:UITextAlignmentCenter fontName:kScoreFontName fontSize:20];
	[self setup_text_color:&text_health_bonus r:243 g:247 b:177];
	text_health_bonus.p = CGPointMake(32, 170);
	[s release];
}

- (void)setup_text_score {
	NSString *s = [[NSString alloc] initWithFormat:@"%i", current_score];
	
	if(text_score.text)
		[text_score.text dealloc];
	text_score.text = [[Texture2D alloc] initWithString:s dimensions:CGSizeMake(256, 64)
											  alignment:UITextAlignmentCenter fontName:kScoreFontName fontSize:40];
	[self setup_text_color:&text_score r:255 g:255 b:255];
	text_score.p = CGPointMake(32, 120);
	[s release];
	
	[self setup_text_time_bonus];
	[self setup_text_health_bonus];
}



- (void)setup_text_map_name {
	NSString *s;
	switch (current_map) {
		case 1:	s = [[NSString alloc] initWithFormat:@"Ocean World", level]; break;
		case 2:	s = [[NSString alloc] initWithFormat:@"Panda Jungle", level]; break;
		case 3:	s = [[NSString alloc] initWithFormat:@"Shopping Mall", level]; break;
		case 4:	s = [[NSString alloc] initWithFormat:@"Star Space", level]; break;
	}
	
	
	if(text_map_name.text)
		[text_map_name.text dealloc];
	text_map_name.text = [[Texture2D alloc] initWithString:s dimensions:CGSizeMake(256, 64)
												   alignment:UITextAlignmentCenter fontName:kScoreFontName fontSize:26];
	[self setup_text_color:&text_map_name r:255 g:255 b:255];
	text_map_name.p = CGPointMake(32, 342);
	[s release];
}

- (void)setup_text_title:(NSString *)s {
	if(text_title.text)
		[text_title.text dealloc];
	text_title.text = [[Texture2D alloc] initWithString:s dimensions:CGSizeMake(256, 64)
												   alignment:UITextAlignmentCenter fontName:kScoreFontName fontSize:26];
	[self setup_text_color:&text_title r:216 g:228 b:27];
	text_title.p = CGPointMake(32, 322);	
}


- (void)setup_text_congratulations {
	if(text_congratulations.text)
		[text_congratulations.text dealloc];
	text_congratulations.text = [[Texture2D alloc] initWithString:@"You just cleared all stages.\nSee you in next update,\nit will not be easy like this." dimensions:CGSizeMake(256, 256)
												alignment:UITextAlignmentCenter fontName:kScoreFontName fontSize:24];
	[self setup_text_color:&text_congratulations r:255 g:255 b:255];
	text_congratulations.p = CGPointMake(32, 40);	
}


- (void)setup_text_credits {
	if(text_credits.text)
		[text_credits.text dealloc];
	text_credits.text = [[Texture2D alloc] initWithString:@"Product Company\nHLPTH (www.hlpth.com)\n\nGame Producer\nSittiphol Phanvilai\n\nDeveloper\nSaran Dumronggittigule\n\nGraphics Designer\nchangnumcg\n\nSponsors\nSIPA Thailand" dimensions:CGSizeMake(256, 256)
											  alignment:UITextAlignmentCenter fontName:kScoreFontName fontSize:14];
	[self setup_text_color:&text_credits r:255 g:255 b:255];
	text_credits.p = CGPointMake(32, 40);	
}

- (void)setup_text_stage_name {
	NSString *s;
	switch ((current_map-1)%4) {
		case 0:	s = [[NSString alloc] initWithFormat:@"Ocean LV%i", level]; break;
		case 1:	s = [[NSString alloc] initWithFormat:@"Panda LV%i", level]; break;
		case 2:	s = [[NSString alloc] initWithFormat:@"Mall LV%i", level]; break;
		case 3:	s = [[NSString alloc] initWithFormat:@"Star LV%i", level]; break;
	}

	
	if(text_stage_name.text)
		[text_stage_name.text dealloc];
	text_stage_name.text = [[Texture2D alloc] initWithString:s dimensions:CGSizeMake(256, 64)
											  alignment:UITextAlignmentCenter fontName:kScoreFontName fontSize:26];
	[self setup_text_color:&text_stage_name r:216 g:228 b:27];
	text_stage_name.p = CGPointMake(32, 292);
	[s release];
}





- (void)setup_texts {
	text_highscores.text = [[Texture2D alloc] initWithString:@"-Highscores-" dimensions:CGSizeMake(256, 64) 
												   alignment:UITextAlignmentCenter fontName:kScoreFontName fontSize:22];
	[self setup_text_color:&text_highscores r:215 g:173 b:62];
	text_highscores.p = CGPointMake(32, 240);

	
	text_loading.text = [[Texture2D alloc] initWithString:@"...Loading..." dimensions:CGSizeMake(256, 64) 
												   alignment:UITextAlignmentCenter fontName:kScoreFontName fontSize:22];
	[self setup_text_color:&text_loading r:243 g:247 b:177];
	text_loading.p = CGPointMake(32, 210);


	text_select_stage.text = [[Texture2D alloc] initWithString:@"Select Stage" dimensions:CGSizeMake(256, 64) 
												alignment:UITextAlignmentCenter fontName:kScoreFontName fontSize:30];
	[self setup_text_color:&text_select_stage r:255 g:255 b:255];
	text_select_stage.p = CGPointMake(32, 400);

	
	text_play_now.text = [[Texture2D alloc] initWithString:@"Play Now?" dimensions:CGSizeMake(256, 64) 
													 alignment:UITextAlignmentCenter fontName:kScoreFontName fontSize:26];
	[self setup_text_color:&text_play_now r:255 g:120 b:0];
	text_play_now.p = CGPointMake(32, 80);
	
	
	text_enter_your_name.text = [[Texture2D alloc] initWithString:@"Enter Your Name" dimensions:CGSizeMake(256, 64) 
												 alignment:UITextAlignmentCenter fontName:kScoreFontName fontSize:24];
	[self setup_text_color:&text_enter_your_name r:255 g:120 b:0];
	text_enter_your_name.p = CGPointMake(32, 250);
	

	text_retry.text = [[Texture2D alloc] initWithString:@"Retry?" dimensions:CGSizeMake(256, 64) 
												 alignment:UITextAlignmentCenter fontName:kScoreFontName fontSize:26];
	[self setup_text_color:&text_retry r:255 g:120 b:0];
	text_retry.p = CGPointMake(32, 200);

	text_reset_level.text = [[Texture2D alloc] initWithString:@"Reset Level" dimensions:CGSizeMake(256, 64) 
											  alignment:UITextAlignmentCenter fontName:kScoreFontName fontSize:22];
	[self setup_text_color:&text_reset_level r:255 g:255 b:255];
	text_reset_level.p = CGPointMake(32, 235);

	text_reset_highscore.text = [[Texture2D alloc] initWithString:@"Reset Highscore" dimensions:CGSizeMake(256, 64) 
													alignment:UITextAlignmentCenter fontName:kScoreFontName fontSize:22];
	[self setup_text_color:&text_reset_highscore r:255 g:255 b:255];
	text_reset_highscore.p = CGPointMake(32, 138);

}

- (void)load_menu_texture {
	[self setupTexture:@"menu_button.png" textureVar:&iMenuButton];
	[self setupTexture:@"menu_button_over.png" textureVar:&iMenuButtonOver];
	[self setupTexture:@"start_game.png" textureVar:&iStartGame];
	[self setupTexture:@"options.png" textureVar:&iOptions];
	[self setupTexture:@"credits.png" textureVar:&iCredits];
	[self setupTexture:@"menu_bg.png" textureVar:&iMenuBg];
	[[delegate playback] stopSound:f8loop021];
	[[delegate playback] startSound:f8loop199];
}

- (void)free_menu_texture {
	[[delegate playback] stopSound:f8loop199];
	glDeleteTextures(1, &iMenuButton);
	glDeleteTextures(1, &iMenuButtonOver);
	glDeleteTextures(1, &iStartGame);
	glDeleteTextures(1, &iOptions);
	glDeleteTextures(1, &iCredits);
	glDeleteTextures(1, &iMenuBg);
}

- (void)load_map_texture {
	switch (current_map) {
		case 1:	if(!iMap1) [self setupTexture:@"map_1.png" textureVar:&iMap1]; break;
		case 2:	if(!iMap2) [self setupTexture:@"map_2.png" textureVar:&iMap2]; break;
		case 3:	if(!iMap3) [self setupTexture:@"map_3.png" textureVar:&iMap3]; break;
		case 4:	if(!iMap4) [self setupTexture:@"map_4.png" textureVar:&iMap4]; break;
	}
	if(![delegate playback]->_stillPlay[f8loop021])
		[[delegate playback] startSound:f8loop021];
}

- (void)free_map_texture {
	[[delegate playback] stopSound:f8loop021];
	glDeleteTextures(1, &iMap1);
	glDeleteTextures(1, &iMap2);
	glDeleteTextures(1, &iMap3);
	glDeleteTextures(1, &iMap4);
	iMap1 = iMap2 = iMap3 = iMap4 = 0;
}


- (void)load_texture {
	
	[self setup_images];
	[self setup_texts];
	[self setup_buttons];

	
	[self setupTexture:@"ok.png" textureVar:&iOk];
	[self setupTexture:@"ok_over.png" textureVar:&iOkOver];
	[self setupTexture:@"quit_over.png" textureVar:&iQuitOver];
	[self setupTexture:@"quit.png" textureVar:&iQuit];
	[self setupTexture:@"prev_button.png" textureVar:&iPrevButton];
	[self setupTexture:@"prev_button_over.png" textureVar:&iPrevButtonOver];	
	[self setupTexture:@"next_button.png" textureVar:&iNextButton];
	[self setupTexture:@"next_button_over.png" textureVar:&iNextButtonOver];	
	[self setupTexture:@"stage_point.png" textureVar:&iStagePoint];
	[self setupTexture:@"stage_point_over.png" textureVar:&iStagePointOver];	
	
	[self setupTexture:@"stage_loading_bar.png" textureVar:&iStageLoadingBar];


	[self setupTexture:@"pause.png" textureVar:&iPauseTexture];
	[self setupTexture:@"resume.png" textureVar:&iResumeTexture];
	[self setupTexture:@"exit.png" textureVar:&iExitTexture];
	[self setupTexture:@"retry.png" textureVar:&iRetryTexture];
	[self setupTexture:@"you_win.png" textureVar:&iYouWinTexture];
	[self setupTexture:@"you_lost.png" textureVar:&iYouLostTexture];

	[delegate refresh_loading:10]; // 4

	[self setupTexture:@"new_highscore.png" textureVar:&iNewHighscore];
	[self setupTexture:@"iphone_h1.png" textureVar:&iPhone_h1];
	[self setupTexture:@"iphone_h2.png" textureVar:&iPhone_h2];
	[self setupTexture:@"iphone_h3.png" textureVar:&iPhone_h3];
	[self setupTexture:@"iphone_h4.png" textureVar:&iPhone_h4];
	[self setupTexture:@"arrow.png" textureVar:&iArrow];	
	[self setupTexture:@"dialog_big.png" textureVar:&iDialogBig];


	[self setupTexture:@"dialog_small.png" textureVar:&iDialogSmall];
	[self setupTexture:@"dialog_middle.png" textureVar:&iDialogMiddle];
	
	iRoom_top = 0;
	iRoom_bottom = 0;
	iRoom_right = 0;
	iRoom_left = 0;
	iRoom_front = 0;
	iRoom_back = 0;		
	[self load_room_texture:FALSE];
	
	[self setupTexture:@"mos_1.png" textureVar:&iMos_1];
	[self setupTexture:@"mos_2.png" textureVar:&iMos_2];
	[self setupTexture:@"mos_3.png" textureVar:&iMos_3];
	[self setupTexture:@"mos_4.png" textureVar:&iMos_4];
	[self setupTexture:@"mos_bite_1.png" textureVar:&iMosBite_1];
	[self setupTexture:@"mos_bite_2.png" textureVar:&iMosBite_2];
	[self setupTexture:@"mos_bite_3.png" textureVar:&iMosBite_3];
	[self setupTexture:@"mos_bite_4.png" textureVar:&iMosBite_4];
	[self setupTexture:@"mos_big_1.png" textureVar:&iMosBig_1];
	[self setupTexture:@"mos_big_2.png" textureVar:&iMosBig_2];
	[self setupTexture:@"mos_big_3.png" textureVar:&iMosBig_3];
	[self setupTexture:@"mos_big_4.png" textureVar:&iMosBig_4];
	[delegate refresh_loading:10]; // 5
	[self setupTexture:@"mos_hit_1.png" textureVar:&iMosHit_1];
	[self setupTexture:@"mos_hit_2.png" textureVar:&iMosHit_2];
	[delegate refresh_loading:2]; // 5.2
	[self setupTexture:@"mos_hit_3.png" textureVar:&iMosHit_3];
	[self setupTexture:@"mos_hit_4.png" textureVar:&iMosHit_4];
	[delegate refresh_loading:2]; // 5.4
	[self setupTexture:@"mos_hit_5.png" textureVar:&iMosHit_5];
	[delegate refresh_loading:2]; // 5.6
	[self setupTexture:@"mos_hit_6.png" textureVar:&iMosHit_6];
	[delegate refresh_loading:2]; // 5.8
	[self setupTexture:@"mos_hit_7.png" textureVar:&iMosHit_7];
	
	[delegate refresh_loading:2]; // 6

	[delegate refresh_loading:1]; // 6.1
	[self setupTexture:@"gun1.png" textureVar:&iGun1];
	[self setupTexture:@"gun1_shot.png" textureVar:&iGun1Shot];
	[delegate refresh_loading:1]; // 6.2
	[self setupTexture:@"gun2.png" textureVar:&iGun2];
	[self setupTexture:@"gun2_shot.png" textureVar:&iGun2Shot];
	[delegate refresh_loading:1]; // 6.3
	[self setupTexture:@"gun3.png" textureVar:&iGun3];
	[self setupTexture:@"gun3_shot.png" textureVar:&iGun3Shot];
	[delegate refresh_loading:1]; // 6.4
	[self setupTexture:@"gun4.png" textureVar:&iGun4];
	[self setupTexture:@"gun4_shot.png" textureVar:&iGun4Shot];
	[delegate refresh_loading:1]; // 6.5
	
	
	int i;
	NSString *s;
	for(i=0; i<9; i++){
		s = [[NSString alloc] initWithFormat:@"gun4_effect_%i.png", i+1];
		[self setupTexture:s textureVar:&iGun4Effect[i]];	
		[s release];
		[delegate refresh_loading:1]; // 6.6 - 7.4
	}
	
	[delegate refresh_loading:1]; // 7.5

	[self setupTexture:@"top_bar.png" textureVar:&iTopBar];
	[delegate refresh_loading:1]; // 7.6
	[self setupTexture:@"top_bar_hp.png" textureVar:&iTopBarHp];
	[delegate refresh_loading:1]; // 7.7
	[self setupTexture:@"item_gun2.png" textureVar:&iItemGun2];
	[delegate refresh_loading:1]; // 7.8
	[self setupTexture:@"item_gun3.png" textureVar:&iItemGun3];
	[delegate refresh_loading:1]; // 7.9
	[self setupTexture:@"item_gun4.png" textureVar:&iItemGun4];
	[delegate refresh_loading:1]; // 8
	[delegate refresh_loading:1]; // 8.1


	[self setupTexture:@"cross_hair.png" textureVar:&iCrossHair];	
	[delegate refresh_loading:1]; // 8.2
	[self setupTexture:@"map_bg.png" textureVar:&iMapBg];	
	[delegate refresh_loading:1]; // 8.3
	
	[self setupTexture:@"digit_0.png" textureVar:&iDigit0];	
	[delegate refresh_loading:1]; // 8.4
	[self setupTexture:@"digit_1.png" textureVar:&iDigit1];	
	[delegate refresh_loading:1]; // 8.5

	[self setupTexture:@"digit_2.png" textureVar:&iDigit2];	
	[delegate refresh_loading:1]; // 8.6
	[self setupTexture:@"digit_3.png" textureVar:&iDigit3];	
	[delegate refresh_loading:1]; // 8.7
	[self setupTexture:@"digit_4.png" textureVar:&iDigit4];	
	[delegate refresh_loading:1]; // 8.8
	[self setupTexture:@"digit_5.png" textureVar:&iDigit5];	
	[delegate refresh_loading:1]; // 8.8
	[self setupTexture:@"digit_6.png" textureVar:&iDigit6];	
	[delegate refresh_loading:1]; // 9.0
	[self setupTexture:@"digit_7.png" textureVar:&iDigit7];	
	[delegate refresh_loading:1]; // 9.1
	[self setupTexture:@"digit_8.png" textureVar:&iDigit8];	
	[delegate refresh_loading:1]; // 9.2
	[self setupTexture:@"digit_9.png" textureVar:&iDigit9];	
	[delegate refresh_loading:1]; // 9.3
	[self setupTexture:@"digit_colon.png" textureVar:&iColon];	
	[delegate refresh_loading:1]; // 9.4
	[self setupTexture:@"digit_x.png" textureVar:&iDigitX];	
	[delegate refresh_loading:1]; // 9.5
	
	
	[self setupTexture:@"heal.png" textureVar:&iHeal];
	[delegate refresh_loading:1]; // 9.6
	[self setupTexture:@"bullet_hole.png" textureVar:&iBulletHole];
	[delegate refresh_loading:1]; // 9.7
	[self setupTexture:@"control_bar.png" textureVar:&iControlBar];
	[delegate refresh_loading:1]; // 9.8
	[self setupTexture:@"mask.png" textureVar:&iMask];
	[delegate refresh_loading:1]; // 9.9
	
	

	
	//------------------- start setup light ----------------------
	glEnable( GL_NORMALIZE );
	glEnableClientState(GL_NORMAL_ARRAY);
	
	/* Set up global ambient light. */
	glLightModelxv( GL_LIGHT_MODEL_AMBIENT, globalAmbient );
	
	/* Set up lamp. */
	glEnable( GL_LIGHT0 );
	glLightxv( GL_LIGHT0, GL_DIFFUSE,  lightDiffuseLamp  );
	glLightxv( GL_LIGHT0, GL_AMBIENT,  lightAmbientLamp  );
	glLightxv( GL_LIGHT0, GL_SPECULAR, lightSpecularLamp );
	glLightxv( GL_LIGHT0, GL_POSITION, lightPositionLamp );
	
	glLightf( GL_LIGHT0, GL_CONSTANT_ATTENUATION, 1.0f );
	glLightf( GL_LIGHT0, GL_LINEAR_ATTENUATION, 0.2f );
	glLightf( GL_LIGHT0, GL_QUADRATIC_ATTENUATION, 0.08f );
	
	//glEnable(GL_COLOR_MATERIAL);
	//glDisable(GL_COLOR_MATERIAL);
	//const GLfloat objDiffuse[4] = { MATERIALCOLOR(0.5, 0.2, 0.0, 0.3) };
	//const GLfloat objAmbient[4] = { MATERIALCOLOR(0.5, 0.2, 0.0, 0.3) };
	//const GLfloat objSpecular[4] = { MATERIALCOLOR(0.9, 0.9, 0.9, 0.3) };
	glMaterialfv(GL_FRONT_AND_BACK, GL_EMISSION, objEmissionDuck);
	//glMaterialfv(GL_FRONT, GL_DIFFUSE, objDiffuse);
	//glMaterialfv(GL_FRONT, GL_AMBIENT, objAmbient);
	//glMaterialfv(GL_FRONT, GL_SPECULAR, objSpecular);
	//glMaterialx(GL_FRONT, GL_SHININESS, 20 << 16);	
	
	//------------------- end setup light ----------------------
	[delegate refresh_loading:1]; // 10

}

- (void)setupView {
    // Enable back face culling. 
    //glEnable( GL_CULL_FACE  );
	// comment because text not show if enable cull_face

	// Set the initial shading mode 
    glShadeModel( GL_SMOOTH ); 



	// Enable use of the texture
	glEnable(GL_TEXTURE_2D);
	// Set a blending function to use
	glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
	// Enable blending
	glEnable(GL_BLEND);
	
	
    // Do not use perspective correction 
    glHint( GL_PERSPECTIVE_CORRECTION_HINT, GL_FASTEST );


	glEnableClientState(GL_VERTEX_ARRAY);
	glEnableClientState(GL_TEXTURE_COORD_ARRAY);




	
}

- (void)create_bullet_hole_bx:(float)bx by:(float)by bz:(float)bz {
	struct Spice3d *bullet_hole;
	bullet_hole = (struct Spice3d *)malloc(sizeof(struct Spice3d));
	bullet_hole->x = bx;
	bullet_hole->y = by;
	bullet_hole->z = bz;
	bullet_hole->frame = 0;
	
	if(!bullet_hole_list){
		bullet_hole_list = bullet_hole;
		bullet_hole->next = nil;
		bullet_hole->prev = nil;
	}else{
		// Add bullet_hole
		struct Spice3d *b;
		b = bullet_hole_list;
		while(b->next)
			b = b->next;
		b->next = bullet_hole;
		bullet_hole->prev = b;
		bullet_hole->next = nil;
	}	
}

- (void)find_next_gun {
	[[delegate playback] startSound:load4];
	if(bullet_4 > 0)
		current_gun = 4;
	else if(bullet_3 > 0)
		current_gun = 3;
	else if(bullet_2 > 0)
		current_gun = 2;
	else
		current_gun = 1;
}

- (void)random_fly:(struct Mosquito *)m step:(float)step{
	if(rand()%2) m->x0 = (rand()%10)/step;
	else m->x0 = -(rand()%10)/step;
	
	if(m->status != Mos_hit){
		if(rand()%2) m->y0 = (rand()%10)/step;
		else m->y0 = -(rand()%10)/step;
	}
	
	if(rand()%2) m->z0 = (rand()%10)/step;
	else m->z0 = -(rand()%10)/step;	
}


- (struct Mosquito *)new_mos:(struct Mosquito *)m status:(int)status {
	struct Mosquito *m_add;
	m_add = (struct Mosquito *)malloc(sizeof(struct Mosquito));
	m_add->x = m->x+0.14;
	m_add->y = m->y+0.14;
	m_add->z = m->z+0.14;
	[self random_fly:m_add step:step_go];
	m_add->way = m->way;
	m_add->status = status;
	m_add->frame = rand()%4;
	return m_add;
}

- (void)shot {
	int i;
	float hit_range;
	if(gun_time == 0){
		switch (current_gun) {
			case 1:	// 0.5 second can shot again
					gun_time = 30;
					hit_range = 0.14;
					if(rand()%2)
						[[delegate playback] startSound:laser07];
					else
						[[delegate playback] startSound:laser21];
					break;
			case 2:	// 0.1 second can shot again
					if(bullet_2 <= 0){
						[self find_next_gun];
						gun_hold = FALSE;
						return;
					}
					gun_time = 6;
					hit_range = 0.14;
					bullet_2--;
					if(rand()%2)
						[[delegate playback] startSound:laser07];
					else
						[[delegate playback] startSound:laser21];
					break;
			case 3:	// 1 second can shot again
					if(bullet_3 <= 0){
						[self find_next_gun];
						gun_hold = FALSE;
						return;
					}
					gun_time = 60;
					hit_range = 0.5;
					bullet_3--;
					[[delegate playback] startSound:gunshot];
					break;
			case 4:	// 0.1 second can shot again
					if(bullet_4 <= 0){
						[self find_next_gun];
						gun_hold = FALSE;
						if(gun_4_hold){
							[[delegate playback] stopSound:jet];
						}
						gun_4_hold = FALSE;						
						return;
					}
					gun_time = 27;
					hit_range = 0.5;
					bullet_4--;
					if(!gun_4_hold || ![delegate playback]->_stillPlay[jet]){
						[[delegate playback] startSound:jet];
						gun_4_hold = TRUE;
					}
					break;
		}
			
		float x1, y1, z1;
		// v1 camera vector
		x1 = cos(-lookangle*TO_RADIAN) * sin((180-angle)*TO_RADIAN);
		y1 = sin(-lookangle*TO_RADIAN);
		z1 = cos(-lookangle*TO_RADIAN) * cos((180-angle)*TO_RADIAN);
		
		
		
		int limit = 0;
		Boolean is_hit = FALSE;
		struct Mosquito * big_mos_hit[MAX_SHOW_MOS];
		int big_mos_hit_num = 0;
		struct Mosquito *m;
		
		// Hit mos or not
		for(i=0; i<mos_num; i++){
			m = mos_list[i];
			// Dont check dead or hit mosquito
			if(m->status == Dead)
				continue;
		
			limit++;
			if(limit > MAX_SHOW_MOS)
				break;
			
			if(m->status == Mos_hit)
				continue;
			
			float x2, y2, z2, ox, oy, oz, d, dd;
			
			// v2 mosquito position vector
			x2 = m->x;
			y2 = m->y;
			z2 = m->z;
			
			// v1 x v2
			ox = (y1 * z2) - (y2 * z1);
			oy = (z1 * x2) - (z2 * x1);
			oz = (x1 * y2) - (x2 * y1);

			// |v1xv2| = |v1||v2|sin a
			// d = |v2|sin a
			// |v1| = 1 because unit vector
			// d = |v1xv2|
			if(m->status >= Mos_big_1 && m->status <= Mos_big_3)
				d = sqrt(pow(ox,2) + pow(oy,2) + pow(oz,2))/2;
			else
				d = sqrt(pow(ox,2) + pow(oy,2) + pow(oz,2));
			// dd = v1 . v2
			// check angle between v1 and v2 
			// if dd > 0 angle is 0-90
			dd = x1*x2 + y1*y2 + z1*z2;
			
			
			//printf("far %f %f %f %f %f\n", d, dd, x1, y1, z1);
			if(d < hit_range && dd > 0){				
				is_hit = TRUE;
				if(m->status == Mos_normal || m->status == Mos_bite || m->status == Mos_go){
					
					m->status = Mos_hit;
					m->frame = 0;
					mos_left_show--;
					[[delegate playback] startSound:bomb3];
					[[delegate playback] stopSound:mosquito];
					[[delegate playback] stopSound:kiss3];

					switch(rand()%6){
						case 0 : [[delegate playback] startSound:oooooh]; break;
						case 1 : [[delegate playback] startSound:hit]; break;
						case 2 : [[delegate playback] startSound:hiccup]; break;
						case 3 : [[delegate playback] startSound:grunt11]; break;
						case 4 : [[delegate playback] startSound:grunt12]; break;
						case 5 : [[delegate playback] startSound:grunt13]; break;
					}
				}else if(m->status == Mos_big_1 || m->status == Mos_big_2 || m->status == Mos_big_3){
					big_mos_hit[big_mos_hit_num++] = m;
					
					//        [[delegate playback] startSound:bomb3];
					if(rand()%2)
						[[delegate playback] startSound:cartoon49];
					else
						[[delegate playback] startSound:squert];
					/*
					// add new mos
					mos_num+=3;
					mos_left+=3;
					mos_left_show+=3;
					mos_list = (struct Mosquito **)realloc(mos_list, sizeof(struct Mosquito *)*mos_num);

					int status;
					if(m->status == Mos_big_1)
						status = Mos_big_2;
					else if(m->status == Mos_big_2)
						status = Mos_big_3;
					else if(m->status == Mos_big_3)
						status = Mos_normal;
					
					mos_list[mos_num-1] = [self new_mos:m status:status];
					mos_list[mos_num-2] = [self new_mos:m status:status];
					mos_list[mos_num-3] = [self new_mos:m status:status];

					if(mos_num > MAX_SHOW_MOS){
						struct Mosquito *m0 = mos_list[0];
						struct Mosquito *m1	= mos_list[1];
						struct Mosquito *m2	= mos_list[2];
						mos_list[0] = mos_list[mos_num-1];
						mos_list[1] = mos_list[mos_num-2];
						mos_list[2] = mos_list[mos_num-3];
						mos_list[mos_num-1] = m0;
						mos_list[mos_num-2] = m1;
						mos_list[mos_num-3] = m2;
					}
					
					
					m->status = Mos_hit;
					m->frame = 0;
					mos_left_show--;
					
					
					break;
					*/
				}else if(m->status == Item_bullet_2){
					bullet_2 += 40;
					[[delegate playback] startSound:diamon];
					m->status = Dead;
					// send message to draw animation effect get bullet
				}
				else if(m->status == Item_bullet_3){
					bullet_3 += 5;
					[[delegate playback] startSound:diamon];
					m->status = Dead;
				}
				else if(m->status == Item_bullet_4){
					bullet_4 += 5;
					[[delegate playback] startSound:diamon];
					m->status = Dead;
				}
				else if(m->status == Item_heal){
					hp = HP_MAX;
					[[delegate playback] startSound:diamon];
					m->status = Dead;
				}
				
			}
		}
		

		
		// Big mos hit
		for(i=0; i<big_mos_hit_num; i++){
			m = big_mos_hit[i];
			mos_num+=3;
			mos_left+=3;
			mos_left_show+=3;
			mos_list = (struct Mosquito **)realloc(mos_list, sizeof(struct Mosquito *)*mos_num);
			
			int status;
			if(m->status == Mos_big_1)
				status = Mos_big_2;
			else if(m->status == Mos_big_2)
				status = Mos_big_3;
			else if(m->status == Mos_big_3)
				status = Mos_normal;

			if(mos_left > MAX_SHOW_MOS){
				int j;
				for(j=mos_num-1; j>=5; j--){
					mos_list[j] = mos_list[j-3];
					mos_list[j-1] = mos_list[j-4];
					mos_list[j-2] = mos_list[j-5];
				}
				mos_list[0] = [self new_mos:m status:status];
				mos_list[1] = [self new_mos:m status:status];
				mos_list[2] = [self new_mos:m status:status];
			}else{
				mos_list[mos_num-1] = [self new_mos:m status:status];
				mos_list[mos_num-2] = [self new_mos:m status:status];
				mos_list[mos_num-3] = [self new_mos:m status:status];
			}
			
			m->status = Mos_hit;
			m->frame = 0;
			mos_left_show--;			
		}
		
		
		
		
		
		if((current_gun != 4 && !is_hit) || current_gun == 3){
			// Create Bullet Hole
			float bx, by, bz;
			int cc;
			if((fabs(x1) >= fabs(y1*3)) && (fabs(x1) >= fabs(z1))){
				// x case
				cc = 1;
				bx = 3*x1/fabs(x1);
				by = y1*bx/x1;
				bz = z1*bx/x1;
			}else if(fabs(y1*3) >= fabs(z1)){
				// y case
				cc = 2;
				by = 1*y1/fabs(y1);
				bx = x1*by/y1;
				bz = z1*by/y1;
			}else{
				// z case
				cc = 3;
				bz = 3*z1/fabs(z1);
				bx = x1*bz/z1;
				by = y1*bz/z1;
			}
			
			
			// add shotgun hole
			if(current_gun == 3){
				float r;
				float u, v, ze;
				for(i=0; i<20; i++){
					ze = rand()%360;
					r = 0.05 + 0.75*rand()/RAND_MAX;
					u = r*cos(ze*TO_RADIAN);
					v = r*sin(ze*TO_RADIAN);
					if(cc == 1)
						[self create_bullet_hole_bx:bx by:by+u bz:bz+v];
					else if(cc == 2)
						[self create_bullet_hole_bx:bx+u by:by bz:bz+v];
					else if(cc == 3)
						[self create_bullet_hole_bx:bx+u by:by+v bz:bz];
				}
			}else
				[self create_bullet_hole_bx:bx by:by bz:bz];

			// Play bullet hole sound
			// this should delay
			[[delegate playback] startSound:break_17];
		}
		
		
	}else{
		// can't shot play some sound here maybe
	}
}


- (GLint)getNumberTexture:(int)i {
	switch (i){
		case 0:	return iDigit0;
		case 1:	return iDigit1;
		case 2:	return iDigit2;
		case 3:	return iDigit3;
		case 4:	return iDigit4;
		case 5:	return iDigit5;
		case 6:	return iDigit6;
		case 7:	return iDigit7;
		case 8:	return iDigit8;
		case 9:	return iDigit9;
	}
	return iDigit0;
}






- (void)draw_dimming_screen {
	// drawing 2d data menu
	const GLfloat dimmingVertices[] = {
		0.0f, 0.0f,
		319.0f,  0.0f,
		0.0f,  479.0f,
		319.0f, 479.0f,
	};
	glDisable(GL_TEXTURE_2D);
	glColor4f(0, 0, 0, 0.7f);
	glVertexPointer(2, GL_FLOAT, 0, dimmingVertices);
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
	glColor4f(1, 1, 1, 1);
	glEnable(GL_TEXTURE_2D);	
}





- (void)freeHighscore_texture_list{
	int i;
	if(highscore_texture_list){
		for(i=0; i<HIGHSCORE_PER_STAGE; i++){
			[highscore_texture_list[i] dealloc];
		}
		free(highscore_texture_list);
		highscore_texture_list = nil;
	}
}

- (void)freeNumber_texture_list{
	int i;
	if(number_texture_list){
		for(i=0; i<10; i++){
			[number_texture_list[i] dealloc];
		}
		free(number_texture_list);
		number_texture_list = nil;
	}
}

- (void)setupHighScore {
	
	int i;
	NSString* s;
	NSMutableArray *hl = [delegate highscore_list];
	
	[self freeHighscore_texture_list];
	
	highscore_texture_list = (Texture2D **)malloc(sizeof(Texture2D *) * HIGHSCORE_PER_STAGE);
	int j = (level-1)*HIGHSCORE_PER_STAGE;
	for(i=j; i<j+HIGHSCORE_PER_STAGE; i++){
		
		if([hl objectAtIndex:i] != nil){
			//const char* name = [[[hl objectAtIndex:i] objectAtIndex:0] UTF8String];
			int score = [[[hl objectAtIndex:i] objectAtIndex:1] integerValue];
			//s = [[NSString alloc] initWithFormat:@"%i. %s   %i", i+1, name, score];
			if(i == highscore_index)
				s = [[NSString alloc] initWithFormat:@"%i. %@  %i <", i-j+1, [[hl objectAtIndex:i] objectAtIndex:0], score];
			else
				s = [[NSString alloc] initWithFormat:@"%i. %@  %i", i-j+1, [[hl objectAtIndex:i] objectAtIndex:0], score];
		}else{
			s = [[NSString alloc] initWithFormat:@"%i. -", i-j+1];
		}
		
		highscore_texture_list[i-j] = [[Texture2D alloc] initWithString:s 
														   dimensions:CGSizeMake(256, 64)
															alignment:UITextAlignmentLeft
															 fontName:kScoreFontName
															 fontSize:kScoreFontSize];
		[s release];
	}
	
}


- (void)setupNumber {
	int i;
	NSString* s;
	number_texture_list = (Texture2D **)malloc(sizeof(Texture2D *) * 10);
	for(i=0; i<10; i++){
		s = [[NSString alloc] initWithFormat:@"%i", i];
		number_texture_list[i] = [[Texture2D alloc] initWithString:s 
													dimensions:CGSizeMake(32, 32)
													 alignment:UITextAlignmentLeft
													  fontName:kScoreFontName
													  fontSize:kScoreFontSize];
		[s release];
	}
}


// draw high score
- (void)draw_highscore {
	if(!highscore_texture_list)
		[self setupHighScore];
	
	// text from Texture2D uses A8 tex format, so needs GL_SRC_ALPHA
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	glColor4f(text_loading.r, text_loading.g, text_loading.b, 1);
	int i;
	for(i=0; i<HIGHSCORE_PER_STAGE; i++){			
		//[iTextureStr drawAtPoint:CGPointMake(100, 100)];
		[highscore_texture_list[i] drawAtPoint:CGPointMake(80, 200-i*20)];
	}
	
	glColor4f(1,1,1,1);
	// switch it back to GL_ONE for other types of images, rather than text because Texture2D uses CG to load, which premultiplies alpha
	glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
}


- (void)draw_bullet {
	int i2, i1, i0;
	switch (current_gun) {
		case 1:
			return;
			break;
		case 2:
			i2 = (bullet_2 % 1000) / 100;
			i1 = (bullet_2 % 100) / 10;
			i0 = bullet_2 % 10;
			break;
		case 3:
			i2 = (bullet_3 % 1000) / 100;
			i1 = (bullet_3 % 100) / 10;
			i0 = bullet_3 % 10;
			break;
		case 4:
			i2 = (bullet_4 % 1000) / 100;
			i1 = (bullet_4 % 100) / 10;
			i0 = bullet_4 % 10;
			break;
	}
	
	if(!number_texture_list)
		[self setupNumber];
	
	// text from Texture2D uses A8 tex format, so needs GL_SRC_ALPHA
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	
	if(i2 > 0) [number_texture_list[i2] drawAtPoint:CGPointMake(60, 28)];
	if(i2 > 0 || i1 > 0) [number_texture_list[i1] drawAtPoint:CGPointMake(70, 28)];
	[number_texture_list[i0] drawAtPoint:CGPointMake(80, 28)];
	
	// switch it back to GL_ONE for other types of images, rather than text because Texture2D uses CG to load, which premultiplies alpha
	glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);	
}

- (Texture2D *)create_text_inst:(NSString *)t alignment:(int)a {
	return [[Texture2D alloc] initWithString:t
						   dimensions:CGSizeMake(256, 32)
							alignment:a
							 fontName:kScoreFontName
							 fontSize:kInstFontSize];
}

- (void)draw_instruction {
	
	static Texture2D* text_0;
	static Texture2D* text_1;
	static Texture2D* text_2;
	static Texture2D* text_3;
	static Texture2D* text_4;
	static Texture2D* text_5;
	Texture2D* text_x;
	
	switch (tutorial_step) {
		case 0: 
			if(!text_0)
				text_0 = [self create_text_inst:@"Look up and down" alignment:UITextAlignmentCenter];
			text_x = text_0;
			break;
		case 1:
			if(!text_1)
				text_1 = [self create_text_inst:@"Turn left" alignment:UITextAlignmentLeft];
			[text_0 release]; text_0 = nil;
			text_x = text_1;
			break;
		case 2: 
			if(!text_2)
				text_2 = [self create_text_inst:@"Turn right" alignment:UITextAlignmentRight];
			[text_1 release]; text_1 = nil;
			text_x = text_2;
			break;
		case 3: 
			if(!text_3)
				text_3 = [self create_text_inst:@"Touch here to shot" alignment:UITextAlignmentCenter];
			text_x = text_3;
			[text_2 release]; text_2 = nil;
			break;
		case 4: 
			if(!text_4)
				text_4 = [self create_text_inst:@"Switch the gun" alignment:UITextAlignmentCenter];
			text_x = text_4;
			[text_3 release]; text_3 = nil;
			break;			
		case 5: 
			if(!text_5)
				text_5 = [self create_text_inst:@"Let's kill mosquitos" alignment:UITextAlignmentCenter];
			text_x = text_5;
			[text_4 release]; text_4 = nil;
			break;			
		default:text_x = text_5; break;
	}
	
	
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	[text_x drawAtPoint:CGPointMake(30, 310)];
	glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);	
}




- (void)draw_level {
	[self draw_text:&text_level];
}


- (void)random_pos:(struct Mosquito *)m{
	float f;
	f = (float)rand()/RAND_MAX;
	m->x = 6*f-3;
	f = (float)rand()/RAND_MAX;
	m->y = 2*f-1;
	f = (float)rand()/RAND_MAX;
	m->z = 6*f-3;
}

- (void)stop_sound_loop {
	[[delegate playback] stopSound:jet];
	[[delegate playback] stopSound:mosquito];
	[[delegate playback] stopSound:kiss3];	
}

- (void)draw3D {
	// setup camera 3d  -------------------------
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	// Calculate the view frustrum
	GLfloat aspectRatio = (GLfloat)(backingWidth) / (GLfloat)(backingHeight);
	glFrustumf( FRUSTUM_LEFT * aspectRatio, FRUSTUM_RIGHT * aspectRatio,
			   FRUSTUM_BOTTOM, FRUSTUM_TOP,
			   FRUSTUM_NEAR, FRUSTUM_FAR);
	
	
	// start draw 3d -------
	
	glEnable( GL_LIGHTING ); // Enable lighting
	
	
	
	
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
	glScalef(400, 400, 400);
	// Gun up a little after shot
	//glRotatef(lookangle-(gun_time)/4.0, 1.0f, 0.0f, 0.0f);
	glRotatef(lookangle, 1.0f, 0.0f, 0.0f);
	glRotatef(angle, 0.0f, 1.0f, 0.0f);
	
	
	
	
	// Amazing 3d texture coordinate pointer
	GLfixed tTexCoords[2*4*2];
	
#define GEN_TEXCOORDS_BRICK(aArr, aX, aY)    {\
const GLubyte* tmp = aArr;			\
tTexCoords[tmp[0]*2]   = aX * 65536.0f;		\
tTexCoords[tmp[0]*2+1] = aY * 65536.0f;		\
tTexCoords[tmp[1]*2]   = aX * 65536.0f;		\
tTexCoords[tmp[1]*2+1] = 0 * 65536.0f;		\
tTexCoords[tmp[2]*2]   = 0 * 65536.0f;		\
tTexCoords[tmp[2]*2+1] = aY * 65536.0f;		\
tTexCoords[tmp[3]*2]   = 0 * 65536.0f;		\
tTexCoords[tmp[3]*2+1] = 0 * 65536.0f;		\
}
	
	glTexCoordPointer(2, GL_FIXED, 0, tTexCoords);
	
	
	
	
	
	
	// drawing 3d home
	static const GLbyte vertices_home_body[8 * 3] =
	{
		-3,  1,  3,
		3,  1,  3,
		3, -1,  3,
		-3, -1,  3,
		
		-3,  1, -3,
		3,  1, -3,
		3, -1, -3,
		-3, -1, -3
		
	};

	static const GLfloat vertices2_home_body[8 * 3] =
	{
		-3.02,  1,  3.02,
		3.02,  1,  3.02,
		3.02, -1,  3.02,
		-3.02, -1,  3.02,
		
		-3.02,  1, -3.02,
		3.02,  1, -3.02,
		3.02, -1, -3.02,
		-3.02, -1, -3.02
		
	};	
	static GLubyte tFront[]  = {3,0,2,1};
	static GLubyte tBack[]   = {6,5,7,4};
	static GLubyte tBottom[]    = {2,6,3,7};
	static GLubyte tTop[] = {5,1,4,0};
	static GLubyte tRight[]   = {7,4,3,0};
	static GLubyte tLeft[]  = {2,1,6,5};
	
	GLfixed vnormals[3 * 8];
	
#define SET_VNORMALS(x, y, z, i)    {\
vnormals[i*3] = x;\
vnormals[i*3+1] = y;\
vnormals[i*3+2] = z;\
}
	
	
#define SET_VNORMALS_FACE(x, y, z, t)    {\
SET_VNORMALS(x, y, z, t[0]);\
SET_VNORMALS(x, y, z, t[1]);\
SET_VNORMALS(x, y, z, t[2]);\
SET_VNORMALS(x, y, z, t[3]);\
}
	
	
	glVertexPointer( 3, GL_BYTE, 0, vertices_home_body );
	glNormalPointer( GL_FIXED, 0, vnormals);
	
	
	glBindTexture(GL_TEXTURE_2D, iRoom_front);
	//GEN_TEXCOORDS_BRICK(tFront, 1, 0.3333);
	GEN_TEXCOORDS_BRICK(tFront, 1, 0.6679);
	SET_VNORMALS_FACE(0, 0, -1, tFront);
	glDrawElements( GL_TRIANGLE_STRIP, 4, GL_UNSIGNED_BYTE, tFront );
	
	glBindTexture(GL_TEXTURE_2D, iRoom_back);
	//GEN_TEXCOORDS_BRICK(tBack, 1, 0.3333);
	GEN_TEXCOORDS_BRICK(tBack, 1, 0.6679);
	SET_VNORMALS_FACE(0, 0, 1, tBack);
	glDrawElements( GL_TRIANGLE_STRIP, 4, GL_UNSIGNED_BYTE, tBack );
	
	glBindTexture(GL_TEXTURE_2D, iRoom_left);
	//GEN_TEXCOORDS_BRICK(tLeft, 1, 0.3333);
	GEN_TEXCOORDS_BRICK(tLeft, 1, 0.6679);
	SET_VNORMALS_FACE(-1, 0, 0, tLeft);
	glDrawElements( GL_TRIANGLE_STRIP, 4, GL_UNSIGNED_BYTE, tLeft );
	
	glBindTexture(GL_TEXTURE_2D, iRoom_right);
	//GEN_TEXCOORDS_BRICK(tRight, 1, 0.3333);
	GEN_TEXCOORDS_BRICK(tRight, 1, 0.6679
	);
	SET_VNORMALS_FACE(1, 0, 0, tRight);
	glDrawElements( GL_TRIANGLE_STRIP, 4, GL_UNSIGNED_BYTE, tRight );
	
	glVertexPointer( 3, GL_FLOAT, 0, vertices2_home_body );
	
	glBindTexture(GL_TEXTURE_2D, iRoom_bottom);
	GEN_TEXCOORDS_BRICK(tBottom, 1, 1);
	SET_VNORMALS_FACE(0, 1, 0, tBottom);
	glDrawElements( GL_TRIANGLE_STRIP, 4, GL_UNSIGNED_BYTE, tBottom );
	
	glBindTexture(GL_TEXTURE_2D, iRoom_top);
	GEN_TEXCOORDS_BRICK(tTop, 1, 1);
	SET_VNORMALS_FACE(0, -1, 0, tTop);
	glDrawElements( GL_TRIANGLE_STRIP, 4, GL_UNSIGNED_BYTE, tTop );
	
	
	
	
	
	
	// draw bullet hole
	//glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	static const GLfloat vertices_bullet_hole[4 * 3] =
	{
		-0.14f,  0.14f,  0,
		0.14f,  0.14,  0,
		0.14f, -0.14f,  0,
		-0.14f, -0.14f,  0,
	};
	static GLubyte tBulletHole[]  = {3,0,2,1};
	
	glBindTexture(GL_TEXTURE_2D, iBulletHole);
	GEN_TEXCOORDS_BRICK(tBulletHole, 1, 1);
	glVertexPointer( 3, GL_FLOAT, 0, vertices_bullet_hole );
	
	struct Spice3d *b, *n;
	b = bullet_hole_list;
	float fade;
	while(b){
		b->frame++;
		
		if(b->frame > 300){
			if(b->prev){
				b->prev->next = b->next;
				if(b->next)
					b->next->prev = b->prev;
			}else{
				bullet_hole_list = b->next;
				if(b->next)
					b->next->prev = nil;
			}
			n = b->next;
			free(b);
			b = n;
			continue;
		}
		if(b->frame > 100)
			fade = (200.0 - (b->frame-100.0))/200.0;
		else
			fade = 1.0;
		//glColor4f(1, 1, 1, fade);
		
		glPushMatrix();
		glTranslatef(b->x, b->y, b->z);
		glScalef(fade, fade, fade);
		if((fabs(b->x) >= fabs(b->y*3)) && (fabs(b->x) >= fabs(b->z))){
			glRotatef(90, 0.0f, 1.0f, 0.0f);
		}else if(fabs(b->y*3) >= fabs(b->z)){
			glRotatef(90, 1.0f, 0.0f, 0.0f);
		}				
		glDrawElements( GL_TRIANGLE_STRIP, 4, GL_UNSIGNED_BYTE, tBulletHole);
		glPopMatrix();
		b = b->next;
	}
	//glColor4f(1, 1, 1, 1);
	//glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
	
	
	
	
	
	// drawing 3d mosquito
	// draw mos and bullet hole
	glEnable(GL_DEPTH_TEST);
	glEnable( GL_ALPHA_TEST );
	glAlphaFunc(GL_GREATER, 0.1);
	
	
	// mos
	int i,k, limit;
	float step;
	limit = 0;
	//int k_decide = 20-level*2;
	int k_decide = 20;
	for(i=0; i<mos_num; i++){
		struct Mosquito *m = mos_list[i];
		if(m->status == Dead)
			continue;
		
		limit++;
		if(limit > MAX_SHOW_MOS)
			break;
		
		// Update Next position
		if(game_state == Playing){
			
			k = (m->status == Mos_hit) ? 2 : k_decide; // x : 10 hard 20 easy
			step = (m->status == Mos_hit) ? 200 : step_go; // x : 500 hard 1000 easy
			
			if(m->status == Mos_normal){
				// Mos decide to bite
				if(rand()%3000 == 0 && level != 1){
					m->status = Mos_bite;
				}
			}
			
			
			
			
			
			if(m->status == Mos_hit){
				/*
				 if(m->frame > 12){
				 if(m->y < -0.80)
				 m->y -= 0.0005;
				 else{
				 m->x += m->x0;
				 m->y -= 0.05;
				 m->z += m->z0;
				 m->way = (old_z * m->x) - (m->z * old_x);
				 }
				 }else{
				 // hold mos_hit in the air
				 m->y += 0.01;
				 m->way = (old_z * m->x) - (m->z * old_x);
				 }*/
				m->frame += 1;
				
			}else{
				
				float old_x, old_z;
				old_x = m->x;
				old_z = m->z;
				
				
				if(m->status == Mos_bite || m->status == Mos_go){
					
					float dis;
					dis = sqrt(pow(m->x,2)+pow(m->y,2)+pow(m->z,2));
					
					if(m->status == Mos_bite && dis < 1.0){
						if(![delegate playback]->_stillPlay[mosquito])
							[[delegate playback] startSound:mosquito];
					}
					
					// Mos bite you
					if(m->status == Mos_bite && dis < 0.35){
						if(![delegate playback]->_stillPlay[kiss3]){
							[[delegate playback] startSound:kiss3];
							AudioServicesPlayAlertSound(kSystemSoundID_Vibrate);
						}
						if(m->frame > 100){
							m->status = Mos_go;
							[[delegate playback] stopSound:mosquito];
							[[delegate playback] stopSound:kiss3];
							//[self random_pos:m];
						}
						
						if(hp > 0)
							hp--;
						
						// mos stay bite
						m->frame = m->frame + 1;
					}else{
						if(m->status == Mos_go){
							dis *= -1;
							if(m->frame > 400)
								m->status = Mos_normal;
							else
								m->frame = m->frame + 1;
						}else
							m->frame = (m->frame + 1)%4;
						
						if(m->x > 0) m->x -= 0.01*fabs(m->x)/dis;
						else if(m->x < 0) m->x += 0.01*fabs(m->x)/dis;
						
						if(m->y > 0) m->y -= 0.01*fabs(m->y)/dis;
						else if(m->y < 0) m->y += 0.01*fabs(m->y)/dis;
						
						if(m->z > 0) m->z -= 0.01*fabs(m->z)/dis;
						else if(m->z < 0) m->z += 0.01*fabs(m->z)/dis;
						
					}
					
				}
				
				
				if(m->status != Mos_bite){
					
					if(rand()%k == 0)
						[self random_fly:m step:step];
					
					m->x += m->x0;
					m->y += m->y0;
					m->z += m->z0;
					
					// cross only x z
					// to determine which way mosquito go
					m->way = (old_z * m->x) - (m->z * old_x);
					
				}
				
				
				if(m->status >= Mos_normal && m->status <= Mos_big_3){
					// Update next animation frame
					m->frame = (m->frame + 1)%4;
				}
			}
			
			
			
			//if(m->status == Mos_hit && m->y < -0.9){
			if(m->status == Mos_hit && m->frame > 50){
				m->status = Dead;
				mos_left--;
			}else{
				
				// limit bound
				if(m->x > 2.8) m->x = 2.8;
				else if(m->x < -2.8) m->x = -2.8;	
				if(m->y > 0.8) m->y = 0.8;
				else if(m->y < -0.8) m->y = -0.8;
				if(m->z > 2.8) m->z = 2.8;
				else if(m->z < -2.8) m->z = -2.8;
				
			}
			
			
			
		}
		// End update next position
		
		
		
		GLfloat mos_ry = fabs(atan(m->x/m->z))*TO_DEGREE;
		
		if(m->x >= 0 && m->z >= 0)
			mos_ry += 0;
		else if(m->x >= 0 && m->z <=0 )
			mos_ry = 180 - mos_ry;
		else if(m->x <= 0 && m->z <=0 )
			mos_ry += 180;
		else if(m->x <= 0 && m->z >= 0 )
			mos_ry = 360 - mos_ry;
		
		GLfloat mos_rx = -atan(m->y/sqrt(pow(m->x,2)+pow(m->z,2)))*TO_DEGREE;
		
		
		static const GLfloat vertices_mosquito[4 * 3] =
		{
			-0.14f,  0.14f,  0,
			0.14f,  0.14,  0,
			0.14f, -0.14f,  0,
			-0.14f, -0.14f,  0,
		};
		static const GLfloat vertices_mosquito_hit[4 * 3] =
		{
			-0.28f,  0.28f,  0,
			0.28f,  0.28,  0,
			0.28f, -0.28f,  0,
			-0.28f, -0.28f,  0,
		};
		static GLubyte tMosquito[]  = {3,0,2,1};
		static GLubyte tMosquito2[]  = {2,1,3,0};
		
		
		glPushMatrix();
		glTranslatef(m->x, m->y, m->z);
		glRotatef(mos_ry, 0.0f, 1.0f, 0.0f);
		glRotatef(mos_rx, 1.0f, 0.0f, 0.0f);
		
		
		switch (m->status) {
			case Mos_normal :
			case Mos_go :
				switch (m->frame%4){
					case 0 : glBindTexture(GL_TEXTURE_2D, iMos_1); break;
					case 1 : glBindTexture(GL_TEXTURE_2D, iMos_2); break;
					case 2 : glBindTexture(GL_TEXTURE_2D, iMos_3); break;
					case 3 : glBindTexture(GL_TEXTURE_2D, iMos_4); break;
					default : glBindTexture(GL_TEXTURE_2D, iMos_1); break;
				} break;
			case Mos_big_1 :
			case Mos_big_2 :
			case Mos_big_3 :
				switch (m->frame%4){
					case 0 : glBindTexture(GL_TEXTURE_2D, iMosBig_1); break;
					case 1 : glBindTexture(GL_TEXTURE_2D, iMosBig_2); break;
					case 2 : glBindTexture(GL_TEXTURE_2D, iMosBig_3); break;
					case 3 : glBindTexture(GL_TEXTURE_2D, iMosBig_4); break;
					default : glBindTexture(GL_TEXTURE_2D, iMosBig_1); break;
				} break;
			case Mos_bite :
				switch (m->frame%4){
					case 0 : glBindTexture(GL_TEXTURE_2D, iMosBite_1); break;
					case 1 : glBindTexture(GL_TEXTURE_2D, iMosBite_2); break;
					case 2 : glBindTexture(GL_TEXTURE_2D, iMosBite_3); break;
					case 3 : glBindTexture(GL_TEXTURE_2D, iMosBite_4); break;
					default : glBindTexture(GL_TEXTURE_2D, iMosBite_1); break;
				} break;
			case Dead :
			case Mos_hit :
				switch (m->frame/6){
					case 0 : glBindTexture(GL_TEXTURE_2D, iMosHit_1); break;
					case 1 : glBindTexture(GL_TEXTURE_2D, iMosHit_2); break;
					case 2 : glBindTexture(GL_TEXTURE_2D, iMosHit_3); break;
					case 3 : glBindTexture(GL_TEXTURE_2D, iMosHit_4); break;
					case 4 : glBindTexture(GL_TEXTURE_2D, iMosHit_5); break;
					case 5 : glBindTexture(GL_TEXTURE_2D, iMosHit_6); break;
					case 6 : glBindTexture(GL_TEXTURE_2D, iMosHit_7); break;
					default : glBindTexture(GL_TEXTURE_2D, iMosHit_7); break;
				}
				glDisable(GL_DEPTH_TEST);
				glDisable(GL_ALPHA_TEST);
				/*
				 if(m->y < -0.8){
				 glColor4f(1, 1, 1, (m->y + 0.9)/0.1);
				 glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
				 } */
				break;
			case Item_bullet_2 :
				glBindTexture(GL_TEXTURE_2D, iItemGun2);
				break;
			case Item_bullet_3 :
				glBindTexture(GL_TEXTURE_2D, iItemGun3);
				break;
			case Item_bullet_4 :
				glBindTexture(GL_TEXTURE_2D, iItemGun4);
				break;
			case Item_heal :
				glBindTexture(GL_TEXTURE_2D, iHeal);
				break;
			default :
				glBindTexture(GL_TEXTURE_2D, iMos_1);
				break;
		}
		
		if(m->way > 0){
			GEN_TEXCOORDS_BRICK(tMosquito2, 1, 1);
		}else{
			GEN_TEXCOORDS_BRICK(tMosquito, 1, 1);
		}
		
		// 256x256 or 128x128
		if(m->status == Mos_hit	|| (m->status >= Mos_big_1 && m->status <= Mos_big_3))
			glVertexPointer( 3, GL_FLOAT, 0, vertices_mosquito_hit );
		else
			glVertexPointer( 3, GL_FLOAT, 0, vertices_mosquito );

		glDrawElements( GL_TRIANGLE_STRIP, 4, GL_UNSIGNED_BYTE, tMosquito );
		//glColor4f(1, 1, 1, 1);
		glPopMatrix();
		
		//glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
		
		// restore from mos_hit 
		if(m->status == Mos_hit){
			glEnable(GL_DEPTH_TEST);
			glEnable(GL_ALPHA_TEST);
		}
	}
	
	
	glDisable(GL_DEPTH_TEST);
	glDisable(GL_ALPHA_TEST);
	glDisable( GL_LIGHTING ); // Enable lighting	
}





// Sets up an array of values for the texture coordinates.
const GLshort spriteTexcoords[] = {
0, 1,
1, 1,
0, 0,
1, 0,
};


- (void)draw_menu {
	// draw menu
	[self draw_image:&image_full iTexture:iMenuBg];

	[self draw_button:&button_start_game];
	[self draw_image:&image_start_game iTexture:iStartGame];

	[self draw_button:&button_options];
	[self draw_image:&image_options iTexture:iOptions];

	[self draw_button:&button_credits];
	[self draw_image:&image_credits iTexture:iCredits];

}

- (void)draw_options {
	[self draw_menu];
	[self draw_dimming_screen];
	[self draw_image:&image_full iTexture:iDialogBig];
	[self draw_text:&text_title];
	[self draw_text:&text_reset_level];
	[self draw_text:&text_reset_highscore];
	[self draw_button:&button_reset_level];
	[self draw_button:&button_reset_highscore];
	[self draw_button:&button_exit_big_dialog];
}

- (void)draw_credits {
	[self draw_menu];
	[self draw_dimming_screen];
	[self draw_image:&image_full iTexture:iDialogBig];
	[self draw_text:&text_title];
	[self draw_text:&text_credits];
}





- (void)draw_map {
	
	[self draw_image:&image_full iTexture:iMapBg];
	[self draw_text:&text_select_stage];
	[self draw_text:&text_map_name];

	
	switch (current_map) {
		case 1:	[self draw_image:&image_full iTexture:iMap1]; break;
		case 2:	[self draw_image:&image_full iTexture:iMap2]; break;
		case 3:	[self draw_image:&image_full iTexture:iMap3]; break;
		case 4:	[self draw_image:&image_full iTexture:iMap4]; break;
	}

	
	if(current_map*LEVEL_PER_ROOM <= reach_level && current_map < MAX_ROOM)
		[self draw_button:&button_next];
	if(current_map > 1)
		[self draw_button:&button_prev];
	[self draw_button:&button_quit];
	
	int i;
	for(i=(current_map-1)*LEVEL_PER_ROOM; i<current_map*LEVEL_PER_ROOM; i++){
		if(i>reach_level)
			break;
		[self draw_button:&button_stage_point[i]];
	}
}


- (void)draw_congratulations {
	[self draw_map];
	[self draw_dimming_screen];
	[self draw_image:&image_full iTexture:iDialogBig];
	[self draw_text:&text_title];
	[self draw_text:&text_congratulations];
	[self draw_button:&button_ok];
}



- (void)draw_map_high_score {
	
	[self draw_map];
	[self draw_dimming_screen];
	[self draw_image:&image_full iTexture:iDialogBig];
	[self draw_text:&text_highscores];
	[self draw_text:&text_stage_name];
	
	[self draw_text:&text_play_now];
	[self draw_button:&button_yes_play_now];
	[self draw_button:&button_no_play_now];
	
	[self draw_highscore];
}


- (void)draw_new_high_score {
	[self draw_image:&image_full iTexture:iDialogBig];
	
	[self draw_button:&button_ok];
	
	[self draw_highscore];
}



- (void)draw_tutorial {
	// drawing 2d data control bar
	const GLfloat iphoneVertices[] = {
		31.0f, 105.0f,
		287.0f, 105.0f,
		31.0f, 346.0f,
		287.0f, 346.0f,
	};
	const GLfloat arrowVertices[] = {
		0.0f, 0.0f,
		127.0f, 0.0f,
		0.0f, 127.0f,
		127.0f, 127.0f,
	};

	GLuint iPhone;
	static int n = 1;
	static Boolean up = TRUE;

	
	if(clock % 8 == 0){
		if(up){
			if(n == 4)
				up = FALSE;
			else
				n++;
		}else{
			if(n == 1)
				up = TRUE;
			else
				n--;
		}
	}

	if(tutorial_step == 0){
		switch (n) {
			case 1:	iPhone = iPhone_h1; break;
			case 2:	iPhone = iPhone_h2; break;
			case 3:	iPhone = iPhone_h3; break;
			case 4:	iPhone = iPhone_h4; break;
			default: iPhone = iPhone_h1;
		}

		glBindTexture(GL_TEXTURE_2D, iPhone);
		glVertexPointer(2, GL_FLOAT, 0, iphoneVertices);
		glTexCoordPointer(2, GL_SHORT, 0, spriteTexcoords);
		glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

	}else if(tutorial_step == 1 || tutorial_step == 2){

		glPushMatrix();
		glTranslatef(159.0f, 233.0f, 0);
		if(tutorial_step == 1)
			glRotatef(n*10, 0, 0, 1);
		else
			glRotatef(n*-10, 0, 0, 1);
		glTranslatef(-159.0f, -233.0f, 0);
		glBindTexture(GL_TEXTURE_2D, iPhone_h3);
		glVertexPointer(2, GL_FLOAT, 0, iphoneVertices);
		glTexCoordPointer(2, GL_SHORT, 0, spriteTexcoords);
		glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
		glPopMatrix();

	}else if(tutorial_step == 3 || tutorial_step == 4){

		glPushMatrix();
		if(tutorial_step == 3){
			glTranslatef(5.0*n, 5.0*n, 0);
			glTranslatef(145.0, 10.0, 0);
		}else{
			glTranslatef(1.0*n, 5.0*n, 0);
			glTranslatef(24.0, -10.0, 0);
			glRotatef(30, 0, 0, 1); 
		}
		glBindTexture(GL_TEXTURE_2D, iArrow);
		glVertexPointer(2, GL_FLOAT, 0, arrowVertices);
		glTexCoordPointer(2, GL_SHORT, 0, spriteTexcoords);
		glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
		glPopMatrix();
		
	}
	
	if(tutorial_step <= 5){
		[self draw_instruction];
		[self draw_button:&button_next_instruction];
	}

}


- (void)draw_mask {
	[self draw_image:&image_mask iTexture:iMask];
	
	const GLfloat dimmingVertices1[] = {
		0.0f, 367.0f,
		319.0f,  367.0f,
		0.0f,  479.0f,
		319.0f, 479.0f,
	};
	const GLfloat dimmingVertices2[] = {
		0.0f, 112.0f,
		32.0f,  112.0f,
		0.0f,  367.0f,
		32.0f, 367.0f,
	};
	const GLfloat dimmingVertices3[] = {
		287.0f, 112.0f,
		319.0f,  112.0f,
		287.0f,  367.0f,
		319.0f, 367.0f,
	};
	const GLfloat dimmingVertices4[] = {
		0.0f, 0.0f,
		319.0f,  0.0f,
		0.0f,  112.0f,
		319.0f, 112.0f,
	};
	glDisable(GL_TEXTURE_2D);
	glColor4f(0, 0, 0, 0.92578125f);
	glVertexPointer(2, GL_FLOAT, 0, dimmingVertices1);
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
	glVertexPointer(2, GL_FLOAT, 0, dimmingVertices2);
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
	glVertexPointer(2, GL_FLOAT, 0, dimmingVertices3);
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
	glVertexPointer(2, GL_FLOAT, 0, dimmingVertices4);
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
	glColor4f(1, 1, 1, 1);
	glEnable(GL_TEXTURE_2D);	
}

- (void)draw2D {
	
	// draw mask
	if(level%4 == 3)
		[self draw_mask];
	
	// draw gun effect
	
	if(current_gun == 4 && gun_time > 0){
		[self draw_image:&image_gun_effect iTexture:iGun4Effect[(27-gun_time)/3]];
	}
	
	
	[self draw_image:&image_top_bar iTexture:iTopBar];
	
	// draw time
	int clock_count;
	clock_count = clock / 60;
	if(game_state == Playing){
		clock++;
		if(gun_time > 0)
			gun_time--;
		if(gun_hold)
			[self shot];
	}
	
	GLint min1, min0, time1, time0;
	// 2 Minutes here
	time_left_count = clock_limit - clock_count;
	if(game_state == Playing){
		if(time_left_count == 0 && mos_left_show > 0 || hp == 0){
			// Lose sound
			[[delegate playback] startSound:harmonik];
			[self stop_sound_loop];
			game_state = Lose; // game over here
			[self setup_text_title:@"Summary"];
			[self free_mosquito];
		}
		if(mos_left == 0){
			// Win sound
			[[delegate playback] startSound:cheer1];
			[self stop_sound_loop];
			game_state = Win; // game over here
			
			// calculate current_score
			current_score = time_left_count*10 + (int)(hp*1000/HP_MAX);
			
			[self setup_text_title:@"Summary"];
			[self setup_text_score];
			// set max level that user can get
			if(level > reach_level)
				reach_level = level;
			[self free_mosquito];
			
			// Check new highscore or not
			int i;
			int j = (level-1)*HIGHSCORE_PER_STAGE;
			for(i=j; i<j+HIGHSCORE_PER_STAGE; i++){
				if([[delegate highscore_list] objectAtIndex:i] == nil
				   || current_score >= [[[[delegate highscore_list] objectAtIndex:i] objectAtIndex:1] integerValue])
					break;
			}
			
			// save score for current level
			// Keep 5 highscore
			highscore_index = -1;
			if(i<j+HIGHSCORE_PER_STAGE && current_score > 0){
				highscore_index = i;
			}
			
			
		}
	}

	
	
	int tt = time_left_count / 60;
	int m1 = (tt)/10;
	int m0 = (tt)%10;
	int second_left = time_left_count - 60*m0;
	int t1 = (second_left % 100) / 10;
	int t0 = second_left % 10;

	min1 = [self getNumberTexture:m1];
	min0 = [self getNumberTexture:m0];
	time1 = [self getNumberTexture:t1]; 
	time0 = [self getNumberTexture:t0]; 
	
	[self draw_image:&image_time_m1 iTexture:min1];
	[self draw_image:&image_time_m0 iTexture:min0];
	[self draw_image:&image_time_colon iTexture:iColon];
	[self draw_image:&image_time_s1 iTexture:time1];
	[self draw_image:&image_time_s0 iTexture:time0];
	
	
	
	
	
	
	
	
	// draw mos left number
	
	GLint left2, left1, left0;
	int l0 = mos_left_show % 10;
	int l1 = (mos_left_show % 100) / 10;
	int l2 = (mos_left_show % 1000) / 100;
	
	
	left0 = [self getNumberTexture:l0]; 
	left1 = [self getNumberTexture:l1]; 
	left2 = [self getNumberTexture:l2]; 

	[self draw_image:&image_mos_left_x iTexture:iDigitX];
	[self draw_image:&image_mos_left_2 iTexture:left2];
	[self draw_image:&image_mos_left_1 iTexture:left1];
	[self draw_image:&image_mos_left_0 iTexture:left0];
	
	
	
	
	// draw hp

	

	
	float hpx;
	//hpx = 0.02 + hp/(HP_MAX+225);
	hpx = 102 + 212*hp/HP_MAX;

	[self setup_image:&image_top_bar_hp x:0  y:390 w:hpx h:90 mw:512 mh:128];
	[self draw_image:&image_top_bar_hp iTexture:iTopBarHp];
	//hpVertices[2] = hpVertices[6] = 60.0+255.0*hpx;
	//hpTexcoords[2] = hpTexcoords[6] = hpx;



	
	
	
	

	
	
	// drawing 2d gun
	const GLfloat gunVertices[] = {
		33.0f, 30.0f,
		289.0f,  30.0f,
		33.0f,  286.0f,
		289.0f,   286.0f,
	};
	// Sets up an array of values for the texture coordinates.
	const GLfloat gunTexcoords[] = {
		0.01f, 1.0f,
		1.0f, 1.0f,
		0.01f, 0.01f,
		1.0f, 0.01f,
	};
	
	
	GLuint iGun;
	
	switch (current_gun) {
		case 1:	iGun = (gun_time < 25) ? iGun1 : iGun1Shot; break;
		case 2:	iGun = (gun_time < 2) ? iGun2 : iGun2Shot; break;
		case 3:	iGun = (gun_time < 51) ? iGun3 : iGun3Shot; break;
		case 4:	iGun = (gun_time < 18) ? iGun4 : iGun4Shot; break;
		default: iGun = iGun1; break;
	}
	
	glBindTexture(GL_TEXTURE_2D, iGun);
	glVertexPointer(2, GL_FLOAT, 0, gunVertices);
	glTexCoordPointer(2, GL_FLOAT, 0, gunTexcoords);
	glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
	
	
	
	
	
	if(game_state == Playing){
		[self draw_button:&button_pause];
		
		
		// drawing 2d cross hair
		const GLfloat crossHairVertices[] = {
			127.0f, 207.0f,
			191.0f,  207.0f,
			127.0f,  271.0f,
			191.0f,   271.0f,
		};
		if(gun_time > 0)
			glColor4f(1, 0, 0, 1);
		glBindTexture(GL_TEXTURE_2D, iCrossHair);
		glVertexPointer(2, GL_FLOAT, 0, crossHairVertices);
		glTexCoordPointer(2, GL_SHORT, 0, spriteTexcoords);
		glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
		glColor4f(1, 1, 1, 1);
	}
	
	
	
	[self draw_image:&image_control_bar iTexture:iControlBar];
	
	
	
	// Draw tutorial
	if(game_state == Playing && level == 1)
		[self draw_tutorial];
	
	
	// Draw Bullet Number
	[self draw_bullet];
	
	// Draw Level Number
	[self draw_level];
	
	
	
	// Draw dimming screen 
	if(game_state == Highscore || game_state == Win 
	   || game_state == EnterNewHighScore || game_state == NewHighScore
	   || game_state == Lose || game_state == Pause){
		[self draw_dimming_screen];
	}
	
	// Draw top High Score ///// this will be deprecated
	if(game_state == Highscore){
		[self draw_highscore];
	}
	
	if(game_state == EnterNewHighScore){
		[self draw_image:&image_full iTexture:iDialogMiddle];
		[self draw_text:&text_title];
		[self draw_text:&text_enter_your_name];
		[self draw_button:&button_save_score];
	}
	 
	if(game_state == NewHighScore){
		[self draw_new_high_score];
		[self draw_text:&text_title];
	}
	
	if(game_state == Pause){
		[self draw_button:&button_resume];
		[self draw_button:&button_exit];
	}
	
	
	if(game_state == Lose){
		[self draw_image:&image_full iTexture:iDialogMiddle];
		[self draw_text:&text_title];
		[self draw_image:&image_you_are iTexture:iYouLostTexture];
		[self draw_text:&text_retry];
		[self draw_button:&button_yes_retry];
		[self draw_button:&button_no_retry];			
	}
	
	if(game_state == Win){
		[self draw_image:&image_dialog_big iTexture:iDialogBig];
		[self draw_text:&text_title];
		[self draw_image:&image_you_are iTexture:iYouWinTexture];
		if(highscore_index != -1)
			[self draw_image:&image_new_highscore iTexture:iNewHighscore];
		[self draw_button:&button_ok_win];
		
		
		[self draw_text:&text_score];
		[self draw_text:&text_time_bonus];
		[self draw_text:&text_health_bonus];

		
	}
}



- (void)draw_loading {
	
	if(delegate->load_progress < 40){
		[self draw_image:&image_logo_neuvex iTexture:iLogoNeuvex];
	}
	else if(delegate->load_progress < 50){
		[self draw_image:&image_logo_sipa iTexture:iLogoSipa];
	}
	else{
		// draw loading
		const GLfloat loadingFrameVertices[] = {
			32.0f, 112.0f, // 0 0
			288.0f, 112.0f, // 1 0
			32.0f, 368.0f, // 0 1
			288.0f, 368.0f, // 1 1
		};
		const GLfloat loadingFrameTexcoords[] = {
			0.0f, 1.0f,
			1.0f, 1.0f,
			0.0f, 0.0f,
			1.0f, 0.0f,
		};
		
		GLfloat loadingVertices[] = {
			32.0f, 112.0f, // 0 0
			288.0f, 112.0f, // 1 0
			32.0f, 368.0f, // 0 1
			288.0f, 368.0f, // 1 1
		};
		GLfloat loadingTexcoords[] = {
			0.0f, 1.0f,
			1.0f, 1.0f,
			0.0f, 0.0f,
			1.0f, 0.0f,
		};
		
		float xx = (delegate->load_progress-50)/50.0;
		loadingVertices[2] = loadingVertices[6] = 32.0+255.0*(xx);
		loadingTexcoords[2] = loadingTexcoords[6] = xx;
		glTexCoordPointer(2, GL_FLOAT, 0, loadingFrameTexcoords);
		glVertexPointer(2, GL_FLOAT, 0, loadingFrameVertices);
		glBindTexture(GL_TEXTURE_2D, iLoadingFrame);
		glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);	
		
		glTexCoordPointer(2, GL_FLOAT, 0, loadingTexcoords);
		glVertexPointer(2, GL_FLOAT, 0, loadingVertices);
		glBindTexture(GL_TEXTURE_2D, iLoading);
		glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
	}
}


- (void)draw_stage_loading {
	
	[self draw_map];
	[self draw_dimming_screen];
	[self draw_image:&image_dialog_small iTexture:iDialogSmall];
	[self draw_text:&text_loading];
	glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
	glColor4f(text_stage_name.r, text_stage_name.g, text_stage_name.b, 1);
	[text_stage_name.text drawAtPoint:CGPointMake(32, 265)];
	glColor4f(1,1,1,1);
	glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
	[self setup_image:&image_stage_loading_bar x:0 y:150 w:320*(stage_load_progress/100.0) h:200 mw:512 mh:256];
	[self draw_image:&image_stage_loading_bar iTexture:iStageLoadingBar];
}




- (void)drawView {
	
	
	// Start context #########################
	[EAGLContext setCurrentContext:context];    
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
    glViewport(0, 0, backingWidth, backingHeight);
	
	glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
	
	
	
	
	
	
	if(delegate->load_progress == 100){
		if(game_state == Playing || game_state == Pause || game_state == Win 
		   || game_state == EnterNewHighScore || game_state == NewHighScore
		   || game_state == Lose || game_state == Highscore){
			[self draw3D];
		}
	}
	
	
	
	
	
	

	// setup camera 2d  ---------------------------
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
	glOrthof(0.0f, 319.0f, 0.0f, 479.0f, -1.0f, 1.0f);
	
    // start draw 2d -------
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
	
	if(delegate->load_progress == 100){
		if(game_state == Playing || game_state == Pause || game_state == Win 
		   || game_state == EnterNewHighScore || game_state == NewHighScore
		   || game_state == Lose || game_state == Highscore){
			[self draw2D];
		}
		else if(game_state == Menu){
			[self draw_menu];
		}
		else if(game_state == Options){
			[self draw_options];
		}
		else if(game_state == Credits){
			[self draw_credits];
		}
		else if(game_state == Congratulations){
			[self draw_congratulations];
		}
		else if(game_state == Map){
			[self draw_map];
		}
		else if(game_state == MapHighScore){
			[self draw_map_high_score];
		}
		else if(game_state == StageLoading){
			[self draw_stage_loading];
		}
	}

	
	
	
	if(delegate->load_progress > 0 && delegate->load_progress < 100){
		[self draw_loading];
	}
		
	// End context ##########################
	glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
	[context presentRenderbuffer:GL_RENDERBUFFER_OES];

	if(delegate->load_progress == 1){
		[delegate load_resource];
		[self load_texture];
		delegate->load_progress = 100;
		[self free_loading_texture];
	}

	if(delegate->load_progress == 0)
		delegate->load_progress = 1;

}






- (void)layoutSubviews {
    [EAGLContext setCurrentContext:context];
    [self destroyFramebuffer];
    [self createFramebuffer];
    [self drawView];
}


- (BOOL)createFramebuffer {
    
    glGenFramebuffersOES(1, &viewFramebuffer);
    glGenRenderbuffersOES(1, &viewRenderbuffer);
    
    glBindFramebufferOES(GL_FRAMEBUFFER_OES, viewFramebuffer);
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, viewRenderbuffer);
    [context renderbufferStorage:GL_RENDERBUFFER_OES fromDrawable:(CAEAGLLayer*)self.layer];
    glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, viewRenderbuffer);
    
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &backingWidth);
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &backingHeight);
    
    if (USE_DEPTH_BUFFER) {
        glGenRenderbuffersOES(1, &depthRenderbuffer);
        glBindRenderbufferOES(GL_RENDERBUFFER_OES, depthRenderbuffer);
        glRenderbufferStorageOES(GL_RENDERBUFFER_OES, GL_DEPTH_COMPONENT16_OES, backingWidth, backingHeight);
        glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_DEPTH_ATTACHMENT_OES, GL_RENDERBUFFER_OES, depthRenderbuffer);
    }
    
    if(glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES) != GL_FRAMEBUFFER_COMPLETE_OES) {
        NSLog(@"failed to make complete framebuffer object %x", glCheckFramebufferStatusOES(GL_FRAMEBUFFER_OES));
        return NO;
    }
    
    return YES;
}


- (void)destroyFramebuffer {
    
    glDeleteFramebuffersOES(1, &viewFramebuffer);
    viewFramebuffer = 0;
    glDeleteRenderbuffersOES(1, &viewRenderbuffer);
    viewRenderbuffer = 0;
    
    if(depthRenderbuffer) {
        glDeleteRenderbuffersOES(1, &depthRenderbuffer);
        depthRenderbuffer = 0;
    }
}

- (void)calculate_step_go {
	// mosquito speed
	step_go = 1000-level*30;
}

- (void)set_clock_limit {
	if(level == 1){
		clock_limit = 200;
		return;
	}
	
	clock_limit = 100+level*2;
	if(level%4 == 3)
		clock_limit += 30;
	if(level > 12)
		clock_limit += 200;
	
}

- (void)initGame {
	// init game here
	level = [delegate.level integerValue];
	reach_level = [delegate.reach_level integerValue];
	//reach_level = MAX_LEVEL;
	[self set_clock_limit];
	clock = [delegate.clock integerValue];
	game_state = [delegate.state integerValue];
	mos_num = [delegate.mos_num integerValue];
	angle = [delegate.angle floatValue];
	lookangle = [delegate.lookangle floatValue];
	current_gun = [delegate.current_gun integerValue];
	current_score = [delegate.current_score integerValue];
	highscore_index = [delegate.highscore_index integerValue];
	if(game_state == EnterNewHighScore && highscore_index != -1){
		[delegate showTextField];
		[self setup_text_title:@"New Highscore"];
	}
	
	if(game_state == NewHighScore){
		[self setup_text_title:@"New Highscore"];
		text_title.p = CGPointMake(32, 292);
	}

	current_map = [delegate.current_map integerValue];
	[self setup_text_map_name];
	bullet_2 = [delegate.bullet_2 integerValue];
	bullet_3 = [delegate.bullet_3 integerValue];
	bullet_4 = [delegate.bullet_4 integerValue];
	hp = [delegate.hp integerValue];
	[self calculate_step_go];
	
	bullet_hole_list = nil;

	if(game_state == Menu || game_state == Options || game_state == Credits){
		[self load_menu_texture];	
	}
	// setup some need text
	if(game_state == Map){
		[self load_map_texture];
	}
	
	if(game_state == MapHighScore){
		[self setup_text_stage_name];
		[self load_map_texture];
	}

	if(game_state == Win){
		[self setup_text_title:@"Summary"];
		[self setup_text_score];
	}
	
	if(game_state == Lose){
		[self setup_text_title:@"Summary"];
	}
	
	if(game_state == Options){
		[self setup_text_title:@"Options"];
		text_title.p = CGPointMake(32, 292);
	}
	
	if(game_state == Credits){
		[self setup_text_title:@"Credits"];
		text_title.p = CGPointMake(32, 292);
		[self setup_text_credits];
	}

	if(game_state == Congratulations){
		[self setup_text_title:@"Congratulations!"];
		[self load_map_texture];
		text_title.p = CGPointMake(32, 292);
		[self setup_text_congratulations];
	}
	
	
	// bullet must restore here
	
	if(game_state == Playing || game_state == Pause || game_state == Win || game_state == Lose || game_state == Highscore){
		if(game_state == Playing)
			game_state = Pause;
		// allocate mosquito
		[self setup_text_level];
		[self add_mosquito:mos_num list:delegate.mos_list];
	}
}


- (void)startAnimation {
    self.animationTimer = [NSTimer scheduledTimerWithTimeInterval:animationInterval target:self selector:@selector(drawView) userInfo:nil repeats:YES];
}


- (void)stopAnimation {
    self.animationTimer = nil;
}


- (void)setAnimationTimer:(NSTimer *)newTimer {
    [animationTimer invalidate];
    animationTimer = newTimer;
}


- (void)setAnimationInterval:(NSTimeInterval)interval {
    animationInterval = interval;
    if (animationTimer) {
        [self stopAnimation];
        [self startAnimation];
    }
}


- (void)accelerometer:(UIAcceleration *)acceleration
{
	if(game_state == Playing){
		[self SmoothOutRawDataX:acceleration.x Y:acceleration.y Z:acceleration.z];
		angle += acceleration.x * 4;
	//	lookangle = acceleration.z * 180;
		if (iZ0 < 0)
			lookangle = - iZ0 * 96 * 90 * 1.1;
		else
			lookangle = - iZ0 * 96 * 90 * 1.22;
		if (lookangle < -90) lookangle = -90;
		if (lookangle >  90) lookangle =  90;
	}
}


- (void)SmoothOutRawDataX:(float)aX Y:(float)aY Z:(float)aZ
{
	const float K128 = 0.0078125;// 1/128
	const float KPole1 = 0.97;//pole of lowpass filter applied to X and Y
	const float KPole2 = 0.90;//pole of lowpass filter applied to Z
	const float KPole3 = 0.75;//pole of highpass filter applied to Z
	
	//single-pole lowpass-filtering of X and Y
	iX = KPole1 * iX1 + ( 1.0 - KPole1 ) * ( K128 * aX );
	iY = KPole1 * iY1 + ( 1.0 - KPole1 ) * ( K128 * aY );
	
	//1st order highpass-filtering of X (zero at 1)
	iX2 = KPole3 * iX2 + ( 1.0 - KPole3 ) * ( iX - iX1 );
	
	//single-pole lowpass-filtering of Z
	iZ0 = KPole2 * iZ1 + ( 1.0 - KPole2 ) * ( K128 * aZ );
	//1st order highpass-filtering of Z (zero at 1)
	iZ2 = KPole3 * iZ2 + ( 1.0 - KPole3 ) * ( iZ0 - iZ1 );
	
	//update variables for use at next sample
	iX1 = iX;
	iY1 = iY;
	iZ1 = iZ0;
}




- (void)free_mosquito {
	// Free mosquito
	int i;
	for(i=0; i<mos_num; i++)
		free(mos_list[i]);
	free(mos_list);
	mos_num = 0;
}


- (void)add_mosquito:(int)num list:(NSMutableArray *)ml{
	// Add mosquito
	mos_num = num;
	mos_left = 0;
	mos_list = (struct Mosquito **)malloc(sizeof(struct Mosquito *)*mos_num);
	int i,j;
	struct Mosquito *m;
	
	if(ml){
		for(i=0; i<mos_num; i++){
			m = (struct Mosquito *)malloc(sizeof(struct Mosquito));
			mos_list[i] = m;
			m->x = [[[ml objectAtIndex:i] objectAtIndex:0] floatValue];
			m->y = [[[ml objectAtIndex:i] objectAtIndex:1] floatValue];
			m->z = [[[ml objectAtIndex:i] objectAtIndex:2] floatValue];
			[self random_fly:m step:step_go];
			m->way = [[[ml objectAtIndex:i] objectAtIndex:3] floatValue];
			m->status = [[[ml objectAtIndex:i] objectAtIndex:4] integerValue];
			m->frame = [[[ml objectAtIndex:i] objectAtIndex:5] integerValue];
			if((m->status >= Mos_normal && m->status <= Mos_big_3)
			   || m->status == Mos_hit || m->status == Mos_bite || m->status == Mos_go)
				mos_left++;
		}
	}else{
		for(i=0; i<mos_num; i++){
			m = (struct Mosquito *)malloc(sizeof(struct Mosquito));
			mos_list[i] = m;
			[self random_pos:m];
			[self random_fly:m step:step_go];

			// Add Item
			//if(i > mos_num - (mos_num*5/100)){
			j = i+1;
			if(j%39 == 0){
				m->status = Item_bullet_4;
			}else if(j%29 == 0){
				m->status = Item_bullet_3;
			}else if(j%19 == 0){
				m->status = Item_bullet_2;
			}else if(j%25 == 0){
				m->status = Item_heal;
			}else{
				if(level%4 == 0)
					m->status = Mos_big_1;
				else
					m->status = Mos_normal;
			}
			
			if(m->status >= Mos_normal && m->status <= Mos_big_3){				
				m->frame = rand()%4;
				mos_left++;
			}
		}
	}
	mos_left_show = mos_left;
}


- (void)play_game {
	game_state = StageLoading;
	stage_load_progress = 0;
	[self refresh_stage_loading]; // 1
	
	clock = 0;
	[self set_clock_limit];
	[self refresh_stage_loading]; // 2
	// this will add when shot and decrement every frame
	// gun can shot when gun_time == 0
	gun_time = 0;
	gun_hold = FALSE;
	current_score = 0;
	
	[self calculate_step_go];
	[self refresh_stage_loading]; // 3
	[self load_room_texture:TRUE]; // 4-9
	[self setup_text_level];
	
	if(level == 1){
		current_gun = 1;
		//bullet_2 = 0;
		//bullet_3 = 0;
		//bullet_4 = 0;
		hp = HP_MAX;
		tutorial_step = 0;
		[self add_mosquito:20+10 list:nil];
		//[self add_mosquito:3 list:nil];
	}

	if(level > 1){
		hp = HP_MAX;
		if(level%4 == 0){
			if(level > 12)
				[self add_mosquito:level list:nil];
			else
				[self add_mosquito:level/2 list:nil];
		}else{
			if(level > 12)
				[self add_mosquito:20+10*level+300 list:nil];
			else
				[self add_mosquito:20+10*level list:nil];
		}
		//[self add_mosquito:3 list:nil];
	}
	
	[self refresh_stage_loading]; // 10

	game_state = Playing;
}


- (Boolean)button_is_hit:(struct Button *)b p:(CGPoint)p s:(int)s{
	Boolean h = (b->image_button.Vertices[0] <= p.x && b->image_button.Vertices[2] >= p.x
			&& (480 - b->image_button.Vertices[5]) <= p.y && (480 - b->image_button.Vertices[1]) >= p.y);
	
	if(h){
		b->status = s;
		if(s==Down && b->sound)
			[[delegate playback] startSound:b->sound];
	}
	return h;
}

// #############################
// Touches Event Handler
// #############################

// touch begin

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
	UITouch *touch = [touches anyObject];
	CGPoint touchPoint = [touch locationInView:self];
	//printf("start %f %f\n", touchPoint.x, touchPoint.y );

	if(game_state == Menu){
		if([self button_is_hit:&button_start_game p:touchPoint s:Down])
			;
		else if([self button_is_hit:&button_options p:touchPoint s:Down])
			;
		else if([self button_is_hit:&button_credits p:touchPoint s:Down])
			;
	}
	else if(game_state == Options){
		if([self button_is_hit:&button_exit_big_dialog p:touchPoint s:Down])
			;
		else if([self button_is_hit:&button_reset_level p:touchPoint s:Down])
			;
		else if([self button_is_hit:&button_reset_highscore p:touchPoint s:Down])
			;
	}
	else if(game_state == Credits){
		[[delegate playback] startSound:tngdorbl];
	}
	else if(game_state == Congratulations){
		if([self button_is_hit:&button_ok p:touchPoint s:Down])
			;
	}
	else if(game_state == Map){
		if(current_map*LEVEL_PER_ROOM <= reach_level && current_map < MAX_ROOM && [self button_is_hit:&button_next p:touchPoint s:Down])
			;
		else if(current_map > 1 && [self button_is_hit:&button_prev p:touchPoint s:Down])
			;
		else if([self button_is_hit:&button_quit p:touchPoint s:Down])
			;
		else{
			int i;
			for(i=(current_map-1)*LEVEL_PER_ROOM; i<current_map*LEVEL_PER_ROOM; i++){
				if(i>reach_level)
					break;
				if([self button_is_hit:&button_stage_point[i] p:touchPoint s:Down])	
					break;
			}
		}
	}
	else if(game_state == MapHighScore){
		if([self button_is_hit:&button_yes_play_now p:touchPoint s:Down])
			;
		else if([self button_is_hit:&button_no_play_now p:touchPoint s:Down])
			;
	}
	else if(game_state == NewHighScore){
		if([self button_is_hit:&button_ok p:touchPoint s:Down])
			;
	}
	else if(game_state == Playing){

		if(touchPoint.x >= 127 && touchPoint.x <= 191 && touchPoint.y >= 287){
			switch (current_gun) {
				case 1:	[self shot];
						break;
				case 2:	gun_hold = TRUE;
						break;
				case 3:	[self shot];
						break;
				case 4:	gun_hold = TRUE;
						break;
			}
		}else if([self button_is_hit:&button_pause p:touchPoint s:Down]){
			;
		}
		else if(touchPoint.x >= 0 && touchPoint.x <= 80 && touchPoint.y >= 287){
			// Change Gun
			[[delegate playback] startSound:load4];
			current_gun = (current_gun + 1) % 5;
			gun_time = 0;
			if(current_gun == 0)
				current_gun = 1;
			if(current_gun == 2 && bullet_2 == 0)
				current_gun = 3;
			if(current_gun == 3 && bullet_3 == 0)
				current_gun = 4;
			if(current_gun == 4 && bullet_4 == 0)
				current_gun = 1;
		}
		
		if(level == 1 && tutorial_step <= 5){
			if([self button_is_hit:&button_next_instruction p:touchPoint s:Down])
				;
		}
	}
	else if(game_state == Pause){
		if([self button_is_hit:&button_resume p:touchPoint s:Down]){
			;
		}
		else if([self button_is_hit:&button_exit p:touchPoint s:Down]){
			;
		}
	}
	else if(game_state == Lose){
		// lose 
		if([self button_is_hit:&button_yes_retry p:touchPoint s:Down])
			;
		else if([self button_is_hit:&button_no_retry p:touchPoint s:Down])
			;
	}
	else if(game_state == Win){
		// win
		if([self button_is_hit:&button_ok_win p:touchPoint s:Down])
			;
	}
	else if(game_state == EnterNewHighScore){
		if([self button_is_hit:&button_save_score p:touchPoint s:Down])
			;
	}
}


- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
	UITouch *touch = [touches anyObject];
	CGPoint touchPoint = [touch locationInView:self];
	//printf("move %f %f\n", touchPoint.x, touchPoint.y );
	
	if(game_state == Playing){
		// Move outside gun button so unhold
		if(!(touchPoint.x >= 127 && touchPoint.x <= 191 && touchPoint.y >= 287)){
			gun_hold = FALSE;
			if(gun_4_hold){
				[[delegate playback] stopSound:jet];
			}
			gun_4_hold = FALSE;
		}
	}
	
}


// touch end

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
	UITouch *touch = [touches anyObject];
	CGPoint touchPoint = [touch locationInView:self];
	//printf("end %f %f\n", touchPoint.x, touchPoint.y );
	if(game_state == Menu){

		button_start_game.status = Normal;
		button_options.status = Normal;
		button_credits.status = Normal;
		
		if([self button_is_hit:&button_start_game	p:touchPoint s:Normal]){
			game_state = Map;
			[self free_menu_texture];
			[self load_map_texture];
		}
		else if([self button_is_hit:&button_options p:touchPoint s:Normal]){
			game_state = Options;
			[self setup_text_title:@"Options"];
			text_title.p = CGPointMake(32, 292);
		}
		else if([self button_is_hit:&button_credits p:touchPoint s:Normal]){
			game_state = Credits;			
			[self setup_text_title:@"Credits"];
			text_title.p = CGPointMake(32, 292);
			[self setup_text_credits];
		}
		
		
	}
	else if(game_state == Options){
		button_exit_big_dialog.status = Normal;
		button_reset_level.status = Normal;
		button_reset_highscore.status = Normal;
		if([self button_is_hit:&button_exit_big_dialog p:touchPoint s:Normal])
			game_state = Menu;
		else if([self button_is_hit:&button_reset_level p:touchPoint s:Normal]){
			reach_level = 0;
			current_map = 1;
		}else if([self button_is_hit:&button_reset_highscore p:touchPoint s:Normal])
			[delegate resetScore];
	}
	else if(game_state == Credits){
		game_state = Menu;
	}
	else if(game_state == Congratulations){
		button_ok.status = Normal;
		if([self button_is_hit:&button_ok p:touchPoint s:Normal]){
			game_state = Map;
			[self load_map_texture];
		}
	}
	else if(game_state == Map){

		button_next.status = Normal;
		button_prev.status = Normal;
		button_quit.status = Normal;
		int i;
		for(i=(current_map-1)*LEVEL_PER_ROOM; i<current_map*LEVEL_PER_ROOM; i++){
			if(i>reach_level)
				break;
			button_stage_point[i].status = Normal;
		}
		
		if(current_map*LEVEL_PER_ROOM <= reach_level && current_map < MAX_ROOM && [self button_is_hit:&button_next	p:touchPoint s:Normal]){
			current_map++;
			[self setup_text_map_name];
			[self load_map_texture];
		}
		else if(current_map > 1 && [self button_is_hit:&button_prev p:touchPoint s:Normal]){
			current_map--;
			[self setup_text_map_name];
			[self load_map_texture];
		}
		else if([self button_is_hit:&button_quit p:touchPoint s:Normal]){
			game_state = Menu;
			[self load_menu_texture];
		}

		else{
			int i;
			for(i=(current_map-1)*LEVEL_PER_ROOM; i<current_map*LEVEL_PER_ROOM; i++){
				if(i>reach_level)
					break;
				if([self button_is_hit:&button_stage_point[i] p:touchPoint s:Normal]){
					level = i+1;
					game_state = MapHighScore;
					// force free to update new texture
					[self setup_text_stage_name];
					[self freeHighscore_texture_list];
					break;
				}
			}
		} 
		
	}
	else if(game_state == MapHighScore){
		button_yes_play_now.status = Normal;
		button_no_play_now.status = Normal;
		
		if([self button_is_hit:&button_yes_play_now p:touchPoint s:Normal]){
			// Game start here
			[self play_game];
			[self free_map_texture];
		}
		else if([self button_is_hit:&button_no_play_now p:touchPoint s:Normal]){
			game_state = Map;
		}
	}
	else if(game_state == NewHighScore){
		button_ok.status = Normal;
		if([self button_is_hit:&button_ok p:touchPoint s:Normal]){
			if(level == MAX_LEVEL){
				game_state = Congratulations;
				[self setup_text_title:@"Congratulations!"];
				[self load_map_texture];
				text_title.p = CGPointMake(32, 292);
				[self setup_text_congratulations];
			}				
			else{
				game_state = Map;
				[self load_map_texture];
			}
		}
	}
	else if(game_state == Playing){
		gun_hold = FALSE;
		if(gun_4_hold){
			[[delegate playback] stopSound:jet];
		}
		gun_4_hold = FALSE;
		
		if(level == 1 && tutorial_step <= 5){
			button_next_instruction.status = Normal;
			if([self button_is_hit:&button_next_instruction p:touchPoint s:Normal])
				tutorial_step++;
		}
		
		button_pause.status = Normal;
		if([self button_is_hit:&button_pause p:touchPoint s:Normal]){
			game_state = Pause;
			[self stop_sound_loop];
		}
	}
	else if(game_state == Pause){
		button_resume.status = Normal;
		button_exit.status = Normal;
		
		if([self button_is_hit:&button_resume p:touchPoint s:Normal]){
			game_state = Playing;
		}
		else if([self button_is_hit:&button_exit p:touchPoint s:Normal]){
			[self free_mosquito];
			game_state = Map;
			[self load_map_texture];
		}
	}
	else if(game_state == Win){
		button_ok_win.status = Normal;
		if([self button_is_hit:&button_ok_win p:touchPoint s:Normal]){
			if(highscore_index != -1){
				game_state = EnterNewHighScore;
				[self setup_text_title:@"New Highscore"];
				[self drawView];
				[delegate showTextField];
			}else{
				if(level == MAX_LEVEL){
					game_state = Congratulations;
					[self setup_text_title:@"Congratulations!"];
					[self load_map_texture];
					text_title.p = CGPointMake(32, 292);
					[self setup_text_congratulations];		
				}else{
					game_state = Map;
					[self load_map_texture];
				}
			}
		}
	}
	else if(game_state == Lose){
		// lose 
		button_yes_retry.status = Normal;
		button_no_retry.status = Normal;
		// Retry
		if([self button_is_hit:&button_yes_retry p:touchPoint s:Normal]){
			[self free_mosquito];
			[self setup_text_stage_name];
			[self load_map_texture];
			[self play_game];
			[self free_map_texture];
		}
		// Exit
		else if([self button_is_hit:&button_no_retry p:touchPoint s:Normal]){
			[self free_mosquito];
			game_state = Map;
			[self load_map_texture];
		}
	}
	else if(game_state == EnterNewHighScore){
		button_save_score.status = Normal;
		if([self button_is_hit:&button_save_score p:touchPoint s:Normal]){
			[[self delegate] saveScore];
			game_state = NewHighScore;
			[self setup_text_title:@"New Highscore"];
			text_title.p = CGPointMake(32, 292);
		}
	}
	
	
}


- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
	//UITouch *touch = [touches anyObject];
	//CGPoint touchPoint = [touch locationInView:self];
	//printf("cancel %f %f\n", touchPoint.x, touchPoint.y );
}








- (void)dealloc {

    // delete mos_list here
	// soon.........
	// 
	
	
    [self stopAnimation];
    
    if ([EAGLContext currentContext] == context) {
        [EAGLContext setCurrentContext:nil];
    }

	[self freeHighscore_texture_list];
	[self freeNumber_texture_list];
	
    [context release];  
    [super dealloc];
}

@end
