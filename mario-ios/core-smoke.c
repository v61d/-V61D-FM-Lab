// SPDX-License-Identifier: GPL-2.0-or-later
#include "libretro.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>
#include <stdint.h>
static uint16_t buttons;
static unsigned videos,audioFrames;
static uint64_t frameHash;
static struct retro_variable defaults[256];
static char values[256][128];
static unsigned count;
static bool environment(unsigned cmd,void *data){
 switch(cmd){
 case RETRO_ENVIRONMENT_GET_CAN_DUPE:*(bool *)data=true;return true;
 case RETRO_ENVIRONMENT_SET_PIXEL_FORMAT:return true;
 case RETRO_ENVIRONMENT_GET_CORE_OPTIONS_VERSION:*(unsigned *)data=0;return true;
 case RETRO_ENVIRONMENT_SET_VARIABLES:{const struct retro_variable *v=data;count=0;for(;v&&v->key&&count<256;v++,count++){defaults[count].key=v->key;const char *p=strstr(v->value,"; ");p=p?p+2:v->value;size_t n=strcspn(p,"|");if(n>127)n=127;memcpy(values[count],p,n);values[count][n]=0;if(!strncmp(v->key,"fceumm_overscan_",16))strcpy(values[count],"0");}return true;}
 case RETRO_ENVIRONMENT_GET_VARIABLE:{struct retro_variable *v=data;for(unsigned i=0;i<count;i++)if(!strcmp(v->key,defaults[i].key)){v->value=values[i];return true;}return false;}
 case RETRO_ENVIRONMENT_GET_VARIABLE_UPDATE:*(bool *)data=false;return true;
 case RETRO_ENVIRONMENT_GET_SYSTEM_DIRECTORY:case RETRO_ENVIRONMENT_GET_SAVE_DIRECTORY:*(const char **)data="/tmp";return true;
 case RETRO_ENVIRONMENT_GET_INPUT_BITMASKS:return true;
 default:return false;}}
static void video(const void *p,unsigned w,unsigned h,size_t pitch){if(!p)return;assert(w>0&&w<=1024&&h>0&&h<=1024);videos++;frameHash=1469598103934665603ull;for(unsigned y=0;y<h;y++){const unsigned char *row=(const unsigned char *)p+y*pitch;for(size_t x=0;x<w*4;x++)frameHash=(frameHash^row[x])*1099511628211ull;}}
static size_t audio(const int16_t *p,size_t n){audioFrames+=(unsigned)n;return n;}
static void sample(int16_t l,int16_t r){audioFrames++;}
static void poll(void){}
static int16_t input(unsigned port,unsigned dev,unsigned index,unsigned id){if(port||dev!=RETRO_DEVICE_JOYPAD)return 0;return id==RETRO_DEVICE_ID_JOYPAD_MASK?(int16_t)buttons:((buttons>>id)&1);}
int main(int argc,char **argv){assert(argc==2);FILE *f=fopen(argv[1],"rb");assert(f);fseek(f,0,SEEK_END);size_t size=ftell(f);rewind(f);void *rom=malloc(size);assert(fread(rom,1,size,f)==size);fclose(f);
 retro_set_environment(environment);retro_set_video_refresh(video);retro_set_audio_sample(sample);retro_set_audio_sample_batch(audio);retro_set_input_poll(poll);retro_set_input_state(input);retro_init();struct retro_game_info game={argv[1],rom,size,NULL};assert(retro_load_game(&game));retro_set_controller_port_device(0,RETRO_DEVICE_JOYPAD);struct retro_system_av_info av;retro_get_system_av_info(&av);assert(av.timing.fps>59&&av.timing.fps<61);assert(av.timing.sample_rate>20000);
 for(int i=0;i<120;i++)retro_run();buttons=1u<<RETRO_DEVICE_ID_JOYPAD_START;retro_run();buttons=0;for(int i=0;i<100;i++)retro_run();buttons=(1u<<RETRO_DEVICE_ID_JOYPAD_RIGHT)|(1u<<RETRO_DEVICE_ID_JOYPAD_B);for(int i=0;i<30;i++)retro_run();
 size_t n=retro_serialize_size();assert(n>0);void *state=malloc(n);assert(retro_serialize(state,n));for(int i=0;i<30;i++)retro_run();uint64_t expected=frameHash;assert(retro_unserialize(state,n));for(int i=0;i<30;i++)retro_run();assert(frameHash==expected);assert(videos>=300&&audioFrames>100000);printf("PASS: NES ROM, %u video frames, %u audio frames, %.5f fps, deterministic save/restore (%zu bytes)\n",videos,audioFrames,av.timing.fps,n);retro_unload_game();retro_deinit();free(rom);free(state);return 0;}
