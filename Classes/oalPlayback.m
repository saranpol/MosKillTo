/*

    File: oalPlayback.m
Abstract: An Obj-C class which wraps an OpenAL playback environment
 Version: 1.4

Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
Inc. ("Apple") in consideration of your agreement to the following
terms, and your use, installation, modification or redistribution of
this Apple software constitutes acceptance of these terms.  If you do
not agree with these terms, please do not use, install, modify or
redistribute this Apple software.

In consideration of your agreement to abide by the following terms, and
subject to these terms, Apple grants you a personal, non-exclusive
license, under Apple's copyrights in this original Apple software (the
"Apple Software"), to use, reproduce, modify and redistribute the Apple
Software, with or without modifications, in source and/or binary forms;
provided that if you redistribute the Apple Software in its entirety and
without modifications, you must retain this notice and the following
text and disclaimers in all such redistributions of the Apple Software.
Neither the name, trademarks, service marks or logos of Apple Inc. may
be used to endorse or promote products derived from the Apple Software
without specific prior written permission from Apple.  Except as
expressly stated in this notice, no other rights or licenses, express or
implied, are granted by Apple herein, including but not limited to any
patent rights that may be infringed by your derivative works or by other
works in which the Apple Software may be incorporated.

The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.

IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.

Copyright (C) 2009 Apple Inc. All Rights Reserved.


*/

#import "oalPlayback.h"
#import "MyOpenALSupport.h"

// this must sync with enum sound in oalPlayback.h
NSString *sound_file[NSOUND] = {@"laser07",\
@"laser21",\
@"gunshot",\
@"break_17",\
@"jet",\
\
@"hiccup",\
@"hit",\
@"oooooh",\
@"diamon",\
@"cheer1",\
\
@"grunt11",\
@"grunt12",\
@"grunt13",\
@"harmonik",\
\
@"mosquito",\
@"kiss3",\
@"bomb3",\
@"tngdorbl",\
\
@"load4",\
@"squert",\
@"cartoon49",\
\
@"f8loop021",\
@"f8loop199",\
};

Boolean   sound_loop[NSOUND] = {FALSE,\
FALSE,\
FALSE,\
FALSE,\
TRUE,\
\
FALSE,\
FALSE,\
FALSE,\
FALSE,\
FALSE,\
\
FALSE,\
FALSE,\
FALSE,\
FALSE,\
\
FALSE,\
TRUE,\
FALSE,\
FALSE,\
\
FALSE,\
FALSE,\
FALSE,\
\
TRUE,\
TRUE,\
\
};


@implementation oalPlayback

@synthesize isPlaying = _isPlaying;
@synthesize wasInterrupted = _wasInterrupted;
@synthesize listenerRotation = _listenerRotation;

#pragma mark Object Init / Maintenance
void interruptionListener(	void *	inClientData,
							UInt32	inInterruptionState)
{
	oalPlayback *THIS = (oalPlayback*)inClientData;
	if (inInterruptionState == kAudioSessionBeginInterruption)
	{
		// do nothing
		[THIS teardownOpenAL];
		if ([THIS isPlaying]) {
			THIS->_wasInterrupted = YES;
			THIS->_isPlaying = NO;
		}
	}
	else if (inInterruptionState == kAudioSessionEndInterruption)
	{
		OSStatus result = AudioSessionSetActive(true);
		if (result) printf("Error setting audio session active! %d\n", result);
		[THIS initOpenAL];
		if (THIS->_wasInterrupted)
		{
			[THIS startSound:0];			
			THIS->_wasInterrupted = NO;
		}
	}
}

- (id)init
{	
	if (self = [super init]) {
		// Start with our sound source slightly in front of the listener
		_sourcePos = CGPointMake(0., -70.);
		
		// Put the listener in the center of the stage
		_listenerPos = CGPointMake(0., 0.);
		
		// Listener looking straight ahead
		_listenerRotation = 0.;
		
		// setup our audio session
		OSStatus result = AudioSessionInitialize(NULL, NULL, interruptionListener, self);
		if (result) printf("Error initializing audio session! %d\n", result);
		else {
			UInt32 category = kAudioSessionCategory_AmbientSound;
			result = AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(category), &category);
			if (result) printf("Error setting audio session category! %d\n", result);
			else {
				result = AudioSessionSetActive(true);
				if (result) printf("Error setting audio session active! %d\n", result);
			}
		}
		
		_wasInterrupted = NO;
		
		// Initialize our OpenAL environment
		[self initOpenAL];
	}
	
	return self;
}

- (void)dealloc
{
	if (_data){
		int i;
		for(i=0; i<NSOUND; i++)
			free(_data[i]);
		free(_data);
	}
		
	[self teardownOpenAL];
	[super dealloc];
}

#pragma mark OpenAL

- (void) initBuffer:(int)i filename:(NSString *)fname
{
	ALenum  error = AL_NO_ERROR;
	ALenum  format;
	ALsizei size;
	ALsizei freq;
	ALuint b = _buffer[i];
	
	NSBundle*				bundle = [NSBundle mainBundle];
	
	// get some audio data from a wave file
	CFURLRef fileURL = (CFURLRef)[[NSURL fileURLWithPath:[bundle pathForResource:fname ofType:@"caf"]] retain];
	
	if (fileURL)
	{	
		_data[i] = MyGetOpenALAudioData(fileURL, &size, &format, &freq);
		CFRelease(fileURL);
		
		if((error = alGetError()) != AL_NO_ERROR) {
			printf("error loading sound: %x\n", error);
			exit(1);
		}
		
		// use the static buffer data API
		alBufferDataStaticProc(b, format, _data[i], size, freq);
		
		if((error = alGetError()) != AL_NO_ERROR) {
			printf("error attaching audio to buffer: %x\n", error);
		}		
	}
	else
	{
		printf("Could not find file!\n");
		_data[i] = NULL;
	}
}

- (void) initSource:(int)i loop:(Boolean)l
{
	ALenum error = AL_NO_ERROR;
	alGetError(); // Clear the error
    ALuint s = _source[i];
	ALuint b = _buffer[i];
	
	if(l){
		// Turn Looping ON
		alSourcei(s, AL_LOOPING, AL_TRUE);
	}
	
	// Set Source Position
	float sourcePosAL[] = {_sourcePos.x, _sourcePos.y, kDefaultDistance};
	alSourcefv(s, AL_POSITION, sourcePosAL);
	
	// Set Source Reference Distance
	alSourcef(s, AL_REFERENCE_DISTANCE, 50.0f);
	
	// attach OpenAL Buffer to OpenAL Source
	alSourcei(s, AL_BUFFER, b);
	
	if((error = alGetError()) != AL_NO_ERROR) {
		printf("Error attaching buffer to source: %x\n", error);
		exit(1);
	}	
}


- (void)initOpenAL
{
	ALenum			error;
	ALCcontext		*newContext = NULL;
	ALCdevice		*newDevice = NULL;
	
	_buffer = (ALuint *)malloc(sizeof(ALuint)*NSOUND);
	_source = (ALuint *)malloc(sizeof(ALuint)*NSOUND);
	_stillPlay = (BOOL *)malloc(sizeof(BOOL)*NSOUND);
	_data = (void **)malloc(sizeof(void *)*NSOUND);
	
	// Create a new OpenAL Device
	// Pass NULL to specify the system’s default output device
	newDevice = alcOpenDevice(NULL);
	if (newDevice != NULL)
	{
		// Create a new OpenAL Context
		// The new context will render to the OpenAL Device just created 
		newContext = alcCreateContext(newDevice, 0);
		if (newContext != NULL)
		{
			// Make the new context the Current OpenAL Context
			alcMakeContextCurrent(newContext);
			
			// Create some OpenAL Buffer Objects
			alGenBuffers(NSOUND, _buffer);
			if((error = alGetError()) != AL_NO_ERROR) {
				printf("Error Generating Buffers: %x", error);
				exit(1);
			}
			
			// Create some OpenAL Source Objects
			alGenSources(NSOUND, _source);
			if(alGetError() != AL_NO_ERROR) 
			{
				printf("Error generating sources! %x\n", error);
				exit(1);
			}
			
		}
	}
	// clear any errors
	alGetError();
	
	int i;
	for(i=0; i<NSOUND; i++){
		_stillPlay[i] = FALSE;
		[self initBuffer:i filename:sound_file[i]];
		[self initSource:i loop:sound_loop[i]];
	}
}

- (void)teardownOpenAL
{
    ALCcontext	*context = NULL;
    ALCdevice	*device = NULL;
	
	// Delete the Sources
    alDeleteSources(NSOUND, _source);
	// Delete the Buffers
    alDeleteBuffers(NSOUND, _buffer);

	free(_source);
	free(_stillPlay);
	free(_buffer);
	
	//Get active context (there can only be one)
    context = alcGetCurrentContext();
    //Get device for active context
    device = alcGetContextsDevice(context);
    //Release context
    alcDestroyContext(context);
    //Close device
    alcCloseDevice(device);
}

#pragma mark Play / Pause

- (void)startSound:(int)i
{
	ALenum error;
	
	//printf("Start!\n");
	// Begin playing our source file
	alSourcePlay(_source[i]);
	if((error = alGetError()) != AL_NO_ERROR) {
		printf("error starting source: %x\n", error);
	} else {
		// Mark our state as playing (the view looks at this)
		self.isPlaying = YES;
		_stillPlay[i] = YES;
	}
}

- (void)stopSound:(int)i
{
	ALenum error;
	
	//printf("Stop!!\n");
	// Stop playing our source file
	alSourceStop(_source[i]);
	if((error = alGetError()) != AL_NO_ERROR) {
		printf("error stopping source: %x\n", error);
	} else {
		// Mark our state as not playing (the view looks at this)
		self.isPlaying = NO;
		_stillPlay[i] = NO;
	}
}

#pragma mark Setters / Getters

- (CGPoint)sourcePos
{
	return _sourcePos;
}

- (void)setSourcePos:(CGPoint)SOURCEPOS
{
	_sourcePos = SOURCEPOS;
	float sourcePosAL[] = {_sourcePos.x, _sourcePos.y, kDefaultDistance};
	// Move our audio source coordinates
	alSourcefv(_source[0], AL_POSITION, sourcePosAL);
}



- (CGPoint)listenerPos
{
	return _listenerPos;
}

- (void)setListenerPos:(CGPoint)LISTENERPOS
{
	_listenerPos = LISTENERPOS;
	float listenerPosAL[] = {_listenerPos.x, _listenerPos.y, 0.};
	// Move our listener coordinates
	alListenerfv(AL_POSITION, listenerPosAL);
}



- (CGFloat)listenerRotation
{
	return _listenerRotation;
}

- (void)setListenerRotation:(CGFloat)radians
{
	_listenerRotation = radians;
	float ori[] = {cos(radians + M_PI_2), sin(radians + M_PI_2), 0., 0., 0., 1.};
	// Set our listener orientation (rotation)
	alListenerfv(AL_ORIENTATION, ori);
}

@end
