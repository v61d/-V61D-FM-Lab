// SPDX-License-Identifier: GPL-2.0-or-later
#include "NativeInput.h"
#include <assert.h>
#include <stdio.h>
int main(void){NativeInput i={0};
 assert(NativeInputMask(&i,true)&1);assert(!(NativeInputMask(&i,false)&1));
 NativeInputSet(&i,8,true,0,true);NativeInputSet(&i,8,true,1,true);NativeInputSet(&i,8,false,0,true);assert(NativeInputMask(&i,true)&(1u<<8));NativeInputSet(&i,8,false,1,true);assert(!(NativeInputMask(&i,true)&(1u<<8)));
 NativeInputSet(&i,0,true,0,true);assert(!(NativeInputMask(&i,true)&1));NativeInputFrame(&i);assert(!(NativeInputMask(&i,true)&1));NativeInputSet(&i,0,true,0,true);assert(i.releaseFrames==1);NativeInputFrame(&i);assert(NativeInputMask(&i,true)&1);
 NativeInputSet(&i,0,false,0,true);NativeInputSet(&i,0,true,2,true);assert(i.releaseFrames==2);NativeInputFrame(&i);NativeInputFrame(&i);assert(NativeInputMask(&i,true)&1);
 NativeInputSet(&i,4,true,1,false);NativeInputSet(&i,5,true,2,false);assert((NativeInputMask(&i,false)&((1u<<4)|(1u<<5)))==((1u<<4)|(1u<<5)));
 NativeInputSet(&i,17,true,9,true);NativeInputClear(&i);assert(NativeInputHeld(&i)==0&&i.releaseFrames==0);
 puts("PASS: mixed touch/controller/keyboard ownership, autorun, two-frame fire pulse, rapid re-press and pause clear");return 0;}
