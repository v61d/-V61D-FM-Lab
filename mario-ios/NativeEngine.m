// SPDX-License-Identifier: GPL-2.0-or-later
#import "NativeEngine.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#include <stdatomic.h>
#include "libretro.h"
#include "NativeInput.h"

#define RING_SAMPLES 32768
static int16_t audioRing[RING_SAMPLES];
static _Atomic unsigned audioRead, audioWrite;
static _Atomic float audioVolume;
static NativeEngine *engine;
static NSMutableDictionary<NSString *,NSString *> *variables;
static NSString *saveDirectory;
static enum retro_pixel_format pixelFormat = RETRO_PIXEL_FORMAT_0RGB1555;
static NativeInput inputs;
static BOOL variablesChanged;
static NSMutableArray<NSDictionary *> *optionSpecs;


@interface NativeEngine () {
    CADisplayLink *_displayLink;
    AudioQueueRef _audioQueue;
    BOOL _loaded;
    double _lastTime, _accumulator, _frameRate;
    NSData *_rom;
    NSString *_romPath;
    UIImage *_lastFrame;
    NSMutableArray<NSData *> *_rewindStates;
    unsigned _rewindCounter, _renderedCount, _emulatedCount;
    double _metricsStart, _renderedFPS, _emulatedFPS, _frameMilliseconds;
    double _sampleRate, _aspectRatio;
}
- (void)tick:(CADisplayLink *)link;
- (void)configureAudio:(double)rate;
- (void)receiveFrame:(CGImageRef)frame;
- (void)updateAV:(const struct retro_system_av_info *)info;
- (void)updateGeometry:(const struct retro_game_geometry *)geometry;
@end

static NSString *S(const char *s) { return s ? [NSString stringWithUTF8String:s] : @""; }
static void addOption(const char *key, const char *label, const char *info, const char *category, const struct retro_core_option_value *values, const char *initial) {
    NSMutableArray *choices=[NSMutableArray new];
    for(unsigned i=0;i<RETRO_NUM_CORE_OPTION_VALUES_MAX && values[i].value;i++)
        [choices addObject:@{@"value":S(values[i].value),@"label":values[i].label?S(values[i].label):S(values[i].value)}];
    NSString *k=S(key), *d=S(initial); if(!d.length)d=choices.firstObject[@"value"]?:@"";
    if([k hasPrefix:@"fceumm_overscan_"])d=@"0";
    NSDictionary *saved=[NSUserDefaults.standardUserDefaults dictionaryForKey:@"core.options"];
    NSString *value=saved[k];if(![[choices valueForKey:@"value"] containsObject:value])value=d;
    variables[k]=value;
    [optionSpecs addObject:@{@"key":k,@"label":S(label),@"info":S(info),@"category":S(category),@"values":choices,@"default":d}];
}
static bool environment(unsigned command, void *data) {
    switch (command) {
        case RETRO_ENVIRONMENT_GET_CAN_DUPE: *(bool *)data = true; return true;
        case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT: {
            enum retro_pixel_format f = *(enum retro_pixel_format *)data;
            if (f > RETRO_PIXEL_FORMAT_RGB565) return false;
            pixelFormat = f; return true;
        }
        case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY:
        case RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY:
            *(const char **)data = saveDirectory.UTF8String; return true;
        case RETRO_ENVIRONMENT_GET_CORE_OPTIONS_VERSION: *(unsigned *)data = 2; return true;
        case RETRO_ENVIRONMENT_SET_CORE_OPTIONS_V2_INTL:
        case RETRO_ENVIRONMENT_SET_CORE_OPTIONS_V2: {
            const struct retro_core_options_v2 *options=command==RETRO_ENVIRONMENT_SET_CORE_OPTIONS_V2?data:((struct retro_core_options_v2_intl *)data)->us;
            [optionSpecs removeAllObjects];
            for(const struct retro_core_option_v2_definition *d=options->definitions;d&&d->key;d++)addOption(d->key,d->desc,d->info,d->category_key,d->values,d->default_value);
            return true;
        }
        case RETRO_ENVIRONMENT_SET_CORE_OPTIONS_DISPLAY: return true;
        case RETRO_ENVIRONMENT_SET_CORE_OPTIONS_UPDATE_DISPLAY_CALLBACK: return true;
        case RETRO_ENVIRONMENT_SET_SYSTEM_AV_INFO: [engine updateAV:data];return true;
        case RETRO_ENVIRONMENT_SET_VARIABLES: {
            const struct retro_variable *v = data;
            for (; v && v->key; v++) {
                NSString *key = @(v->key), *description = @(v->value);
                NSString *options = [[description componentsSeparatedByString:@"; "] lastObject];
                variables[key] = [[options componentsSeparatedByString:@"|"] firstObject];
                if ([key hasPrefix:@"fceumm_overscan_"]) variables[key] = @"0";
            }
            return true;
        }
        case RETRO_ENVIRONMENT_GET_VARIABLE: {
            struct retro_variable *v = data;
            v->value = [variables[@(v->key)] UTF8String]; return v->value != NULL;
        }
        case RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE: *(bool *)data = variablesChanged; variablesChanged=NO; return true;
        case RETRO_ENVIRONMENT_GET_INPUT_BITMASKS: return true;
        case RETRO_ENVIRONMENT_SET_GEOMETRY: [engine updateGeometry:data];return true;
        case RETRO_ENVIRONMENT_SET_SUPPORT_NO_GAME:
        case RETRO_ENVIRONMENT_SET_INPUT_DESCRIPTORS:
        case RETRO_ENVIRONMENT_SET_CONTROLLER_INFO:
        case RETRO_ENVIRONMENT_SET_PERFORMANCE_LEVEL: return true;
        default: return false;
    }
}
static void inputPoll(void) {}
static int16_t inputState(unsigned port, unsigned device, unsigned index, unsigned id) {
    if (port || device != RETRO_DEVICE_JOYPAD || index) return 0;
    uint16_t value=NativeInputMask(&inputs,engine.autoRun);
    if (id == RETRO_DEVICE_ID_JOYPAD_MASK) return (int16_t)value;
    return id < 16 && (value & (1u << id)) ? 1 : 0;
}
static size_t audioBatch(const int16_t *samples, size_t frames) {
    if(engine.rewinding || fabs(engine.speed-1)>0.01)return frames;
    unsigned write = atomic_load_explicit(&audioWrite, memory_order_relaxed);
    unsigned read = atomic_load_explicit(&audioRead, memory_order_acquire);
    unsigned count = (unsigned)MIN(frames * 2, (RING_SAMPLES - 1) - (write - read));
    count &= ~1u;
    for (unsigned i = 0; i < count; i++) audioRing[(write + i) % RING_SAMPLES] = samples[i];
    atomic_store_explicit(&audioWrite, write + count, memory_order_release);
    return frames;
}
static void audioSample(int16_t left, int16_t right) { int16_t pair[] = {left,right}; audioBatch(pair,1); }
static void queueOutput(void *context, AudioQueueRef queue, AudioQueueBufferRef buffer) {
    unsigned read = atomic_load_explicit(&audioRead, memory_order_relaxed);
    unsigned write = atomic_load_explicit(&audioWrite, memory_order_acquire);
    unsigned count = buffer->mAudioDataBytesCapacity / sizeof(int16_t);
    int16_t *output = buffer->mAudioData;
    float gain = atomic_load(&audioVolume);
    unsigned available = MIN(write - read, count);
    for (unsigned i = 0; i < available; i++) output[i] = (int16_t)(audioRing[(read + i) % RING_SAMPLES] * gain);
    memset(output + available, 0, (count - available) * sizeof(int16_t));
    atomic_store_explicit(&audioRead, read + available, memory_order_release);
    buffer->mAudioDataByteSize = count * sizeof(int16_t);
    AudioQueueEnqueueBuffer(queue, buffer, 0, NULL);
}
static void video(const void *pixels, unsigned width, unsigned height, size_t pitch) {
    if (!pixels || !width || !height || width > 1024 || height > 1024) return;
    NSMutableData *rgba = [NSMutableData dataWithLength:width * height * 4];
    uint32_t *target = rgba.mutableBytes;
    for (unsigned y = 0; y < height; y++) {
        const uint8_t *row = (const uint8_t *)pixels + pitch * y;
        for (unsigned x = 0; x < width; x++) {
            uint32_t p;
            if (pixelFormat == RETRO_PIXEL_FORMAT_XRGB8888) {
                p = ((const uint32_t *)row)[x] | 0xff000000;
            } else {
                unsigned value = ((const uint16_t *)row)[x];
                unsigned r = pixelFormat == RETRO_PIXEL_FORMAT_RGB565 ? (value >> 11) & 31 : (value >> 10) & 31;
                unsigned g = pixelFormat == RETRO_PIXEL_FORMAT_RGB565 ? (value >> 5) & 63 : (value >> 5) & 31;
                unsigned b = value & 31;
                r = (r << 3) | (r >> 2); b = (b << 3) | (b >> 2);
                g = pixelFormat == RETRO_PIXEL_FORMAT_RGB565 ? (g << 2) | (g >> 4) : (g << 3) | (g >> 2);
                p = 0xff000000 | (r << 16) | (g << 8) | b;
            }
            target[y * width + x] = p;
        }
    }
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)rgba);
    CGColorSpaceRef color = CGColorSpaceCreateDeviceRGB();
    CGImageRef image = CGImageCreate(width,height,8,32,width * 4,color,kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipFirst,provider,NULL,false,kCGRenderingIntentDefault);
    [engine receiveFrame:image];
    CGImageRelease(image); CGColorSpaceRelease(color); CGDataProviderRelease(provider);
}

@implementation NativeEngine
- (instancetype)init {
    if ((self = [super init])) { _paused = YES; _autoRun = YES; _volume = 0.5; _speed=1; _rewindStates=[NSMutableArray new]; atomic_store(&audioVolume,0.5); }
    return self;
}
- (double)frameRate { return _frameRate; }
- (double)aspectRatio{return _aspectRatio>0?_aspectRatio:256.0/240.0;}
- (double)renderedFPS{return _renderedFPS;}
- (double)emulatedFPS{return _emulatedFPS;}
- (double)frameMilliseconds{return _frameMilliseconds;}
- (UIImage *)lastFrame{return _lastFrame;}
- (NSArray *)coreOptions{return [optionSpecs copy];}
- (NSString *)coreValue:(NSString *)key{return variables[key];}
- (void)setCoreValue:(NSString *)value key:(NSString *)key{
    NSDictionary *spec=nil;for(NSDictionary *d in optionSpecs)if([d[@"key"] isEqual:key])spec=d;
    if(![[spec[@"values"] valueForKey:@"value"] containsObject:value])return;
    variables[key]=value;variablesChanged=YES;
    [NSUserDefaults.standardUserDefaults setObject:[variables copy] forKey:@"core.options"];
}
- (void)resetCoreOptions{for(NSDictionary *d in optionSpecs)variables[d[@"key"]]=d[@"default"];variablesChanged=YES;[NSUserDefaults.standardUserDefaults removeObjectForKey:@"core.options"];}
- (void)receiveFrame:(CGImageRef)frame{_lastFrame=[UIImage imageWithCGImage:frame];}
- (void)updateGeometry:(const struct retro_game_geometry *)g{_aspectRatio=g->aspect_ratio>0?g->aspect_ratio:(double)g->base_width/g->base_height;}
- (void)updateAV:(const struct retro_system_av_info *)info{[self updateGeometry:&info->geometry];_frameRate=info->timing.fps;if(_audioQueue&&fabs(_sampleRate-info->timing.sample_rate)>1)[self configureAudio:info->timing.sample_rate];}
- (void)setPerformanceMode:(NSInteger)value{_performanceMode=value;_displayLink.preferredFramesPerSecond=value==2?30:(value==1?UIScreen.mainScreen.maximumFramesPerSecond:60);}
- (void)setRewindEnabled:(BOOL)value{_rewindEnabled=value;[_rewindStates removeAllObjects];_rewinding=NO;}
- (void)releaseInputs{NativeInputClear(&inputs);}
- (void)setCheats:(NSArray *)cheats{retro_cheat_reset();unsigned index=0;for(NSDictionary *c in cheats)if([c[@"enabled"] boolValue])retro_cheat_set(index++,true,[c[@"code"] UTF8String]);}

- (void)setVolume:(float)value { _volume = MAX(0,MIN(1,value)); atomic_store(&audioVolume,_volume); }
- (BOOL)loadROM:(NSString *)path error:(NSError **)error {
    engine = self; [self releaseInputs];
    variables = [NSMutableDictionary new]; optionSpecs=[NSMutableArray new]; variablesChanged=NO;
    saveDirectory = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES).firstObject;
    _romPath=[path copy];_rom = [NSData dataWithContentsOfFile:path];
    if (!_rom.length) { if (error) *error = [NSError errorWithDomain:@"V61DMario" code:1 userInfo:@{NSLocalizedDescriptionKey:@"ملف اللعبة غير متاح"}]; return NO; }
    retro_set_environment(environment); retro_set_video_refresh(video);
    retro_set_audio_sample(audioSample); retro_set_audio_sample_batch(audioBatch);
    retro_set_input_poll(inputPoll); retro_set_input_state(inputState);
    retro_init();
    struct retro_game_info game = {path.UTF8String,_rom.bytes,_rom.length,NULL};
    if (!retro_load_game(&game)) { retro_deinit(); if(error)*error=[NSError errorWithDomain:@"V61DMario" code:2 userInfo:@{NSLocalizedDescriptionKey:@"تعذّر تشغيل اللعبة"}]; return NO; }
    _loaded = YES;
    retro_set_controller_port_device(0, RETRO_DEVICE_JOYPAD);
    struct retro_system_av_info info; retro_get_system_av_info(&info);
    _frameRate = info.timing.fps > 0 ? info.timing.fps : 60.0988;[self updateGeometry:&info.geometry];
    [self configureAudio:info.timing.sample_rate];
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
    _displayLink.preferredFramesPerSecond = _performanceMode==2?30:(_performanceMode==1?UIScreen.mainScreen.maximumFramesPerSecond:60);
    _displayLink.paused = YES;
    [_displayLink addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    return YES;
}
- (void)setPaused:(BOOL)paused {
    _paused = paused; _displayLink.paused = paused; _lastTime = 0; _accumulator = 0;
    if (paused) {
        [self releaseInputs]; _rewinding=NO; _metricsStart=0;_renderedCount=_emulatedCount=0;
        if (_audioQueue) AudioQueuePause(_audioQueue);
    } else if (_audioQueue) AudioQueueStart(_audioQueue,NULL);
}
- (void)configureAudio:(double)rate{
    if(_audioQueue){AudioQueueStop(_audioQueue,true);AudioQueueDispose(_audioQueue,true);_audioQueue=NULL;}
    atomic_store(&audioRead,0);atomic_store(&audioWrite,0);_sampleRate=rate;
    AVAudioSession *session = AVAudioSession.sharedInstance;
    [session setCategory:AVAudioSessionCategoryPlayback error:nil];
    [session setPreferredIOBufferDuration:0.01 error:nil];
    [session setActive:YES error:nil];
    AudioStreamBasicDescription format = {0};
    format.mSampleRate = rate;
    format.mFormatID = kAudioFormatLinearPCM;
    format.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    format.mBytesPerPacket = format.mBytesPerFrame = 4;
    format.mFramesPerPacket = 1; format.mChannelsPerFrame = 2; format.mBitsPerChannel = 16;
    OSStatus status = AudioQueueNewOutput(&format,queueOutput,NULL,NULL,NULL,0,&_audioQueue);
    if (status == noErr) {
        for (int i=0;i<3;i++) { AudioQueueBufferRef buffer; if (AudioQueueAllocateBuffer(_audioQueue,2048,&buffer)==noErr) queueOutput(NULL,_audioQueue,buffer); }
    }
    if(!_paused&&_audioQueue)AudioQueueStart(_audioQueue,NULL);
}
- (void)tick:(CADisplayLink *)link {
    if (!_loaded || _paused) return;
    if (!_lastTime) _lastTime=link.timestamp;
    if(!_metricsStart)_metricsStart=link.timestamp;
    _accumulator+=MIN(link.timestamp-_lastTime,0.1)*MAX(0.1,MIN(10,_speed));_lastTime=link.timestamp;
    unsigned frames=0;double begin=CACurrentMediaTime();
    if(_rewinding&&_rewindEnabled&&_rewindStates.count){
        NSData *state=_rewindStates.lastObject;[_rewindStates removeLastObject];retro_unserialize(state.bytes,state.length);retro_run();frames=1;_accumulator=0;
    }else if(!_rewinding){
        while(_accumulator>=1.0/_frameRate&&frames<60){
            _accumulator-=1.0/_frameRate;retro_run();frames++;NativeInputFrame(&inputs);
            if(_rewindEnabled&&++_rewindCounter>=6){_rewindCounter=0;NSData *state=[self saveState];if(state)[_rewindStates addObject:state];if(_rewindStates.count>150)[_rewindStates removeObjectAtIndex:0];}
        }
    }
    if(frames){_emulatedCount+=frames;_renderedCount++;_frameMilliseconds=(CACurrentMediaTime()-begin)*1000/frames;if(self.videoFrame&&_lastFrame)self.videoFrame(_lastFrame.CGImage);}
    double elapsed=link.timestamp-_metricsStart;
    if(elapsed>=1){_renderedFPS=_renderedCount/elapsed;_emulatedFPS=_emulatedCount/elapsed;_renderedCount=_emulatedCount=0;_metricsStart=link.timestamp;}
}
- (void)setButton:(unsigned)button pressed:(BOOL)pressed{[self setButton:button pressed:pressed source:0];}
- (void)setButton:(unsigned)button pressed:(BOOL)pressed source:(unsigned)source{
    if(_paused||button>=16||source>=4)return;
    NativeInputSet(&inputs,button,pressed,source,_autoRun);
}
- (NSData *)saveState {
    if (!_loaded) return nil;
    NSMutableData *state = [NSMutableData dataWithLength:retro_serialize_size()];
    return state.length && retro_serialize(state.mutableBytes,state.length) ? state : nil;
}
- (BOOL)restoreState:(NSData *)data {
    if (!_loaded || data.length != retro_serialize_size()) return NO;
    BOOL success = retro_unserialize(data.bytes,data.length);
    if (success) { [self releaseInputs]; [_rewindStates removeAllObjects]; _accumulator = 0; _lastTime = 0; }
    return success;
}
- (void)advanceFrame{if(!_loaded||!_paused)return;retro_run();NativeInputFrame(&inputs);if(self.videoFrame&&_lastFrame)self.videoFrame(_lastFrame.CGImage);}
- (void)reset {
    if(_loaded){retro_unload_game();struct retro_game_info game={_romPath.UTF8String,_rom.bytes,_rom.length,NULL};_loaded=retro_load_game(&game);retro_set_controller_port_device(0,RETRO_DEVICE_JOYPAD);struct retro_system_av_info info;retro_get_system_av_info(&info);[self updateAV:&info];}
    [self releaseInputs];[_rewindStates removeAllObjects];_accumulator=_lastTime=0;
}
@end
