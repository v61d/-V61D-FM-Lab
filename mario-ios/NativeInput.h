// SPDX-License-Identifier: GPL-2.0-or-later
#ifndef V61D_NATIVE_INPUT_H
#define V61D_NATIVE_INPUT_H
#include <stdint.h>
#include <stdbool.h>
#include <string.h>
typedef struct {uint16_t sources[4];unsigned releaseFrames;} NativeInput;
static inline uint16_t NativeInputHeld(const NativeInput *input){return input->sources[0]|input->sources[1]|input->sources[2]|input->sources[3];}
static inline void NativeInputClear(NativeInput *input){memset(input,0,sizeof(*input));}
static inline void NativeInputSet(NativeInput *input,unsigned button,bool pressed,unsigned source,bool autoRun){
 if(button>=16||source>=4)return;uint16_t bit=1u<<button;bool prior=(NativeInputHeld(input)&bit)!=0;
 if(pressed)input->sources[source]|=bit;else input->sources[source]&=~bit;
 if(autoRun&&button==0&&!prior&&(NativeInputHeld(input)&bit))input->releaseFrames=2;
}
static inline uint16_t NativeInputMask(const NativeInput *input,bool autoRun){uint16_t held=NativeInputHeld(input);if(autoRun){held&=~1u;if(!input->releaseFrames)held|=1u;}return held;}
static inline void NativeInputFrame(NativeInput *input){if(input->releaseFrames)input->releaseFrames--;}
#endif
