/*
 *  NESAPUEmulator.h
 *
 * Copyright (c) 2010 Auston Stewart
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * 
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudio.h>
#import <AudioToolbox/AudioToolbox.h>
#include "nes_apu/Nes_Apu.h"
#include "nes_apu/Blip_Buffer.h"

#define NUM_BUFFERS 3

@class NES6502Interpreter;

typedef uint8_t (*CPUMemoryReadPointer)(id, SEL, uint16_t);

typedef struct {
	NES6502Interpreter *cpuInterpreter;
	CPUMemoryReadPointer memoryReadFunction;
} NESMemoryReader;

typedef struct {
    AudioStreamBasicDescription   dataFormat;
    AudioQueueRef                 queue;
    AudioQueueBufferRef           buffers[NUM_BUFFERS];
    UInt32                        bufferByteSize;
    UInt32                        numPacketsToRead;
	SInt64						  packetsToPlay;
    BOOL                          isRunning;
	Blip_Buffer* blipBuffer;
} NESAPUState;

static void HandleOutputBuffer (
								void                 *aqData,
								AudioQueueRef        inAQ,
								AudioQueueBufferRef  inBuffer
);

@interface NESAPUEmulator : NSObject {
	
	Nes_Apu *nesAPU;
	Blip_Buffer *blipBuffer;
	NESAPUState *nesAPUState;
	
	blip_time_t time;
	uint_fast32_t _lastCPUCycle;
	uint8_t _apuStatus;
}

- (void)beginAPUPlayback;
- (void)stopAPUPlayback;

// Set function for APU to call when it needs to read memory (DMC samples)
-(void)setDMCReadObject:(NES6502Interpreter *)cpu;

// Set output sample rate
- (BOOL)setOutputSampleRate:(long)rate;

// Write to register (0x4000-0x4017, except 0x4014 and 0x4016)
- (void)writeByte:(uint8_t)byte toAPUFromCPUAddress:(uint16_t)address onCycle:(uint_fast32_t)cycle;

// Read from status register at 0x4015
- (uint8_t)readAPUStatusOnCycle:(uint_fast32_t)cycle;

// End a 1/60 sound frame
- (double)endFrameOnCycle:(uint_fast32_t)cycle;

// Number of samples in buffer
- (long)numberOfBufferedSamples;

- (void)clearBuffer;

- (void)pause;
- (void)resume;

// Save/load snapshot of emulation state
- (void)saveSnapshot;
- (void)loadSnapshot;

- (int)pendingDMCReadsOnCycle:(uint_fast32_t)cycle;
- (void)runAPUUntilCPUCycle:(uint_fast32_t)cycle;

@end
