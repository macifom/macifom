/* NES6502Interpreter.h
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

@class NESPPUEmulator;
@class NESAPUEmulator;
@class NESCartridge;

typedef struct cpuregs {
	
	uint8_t accumulator;
	uint8_t indexRegisterX;
	uint8_t indexRegisterY;
	uint16_t programCounter;
	uint8_t stackPointer;
	
	uint8_t statusCarry;
	uint8_t statusZero;
	uint8_t statusIRQDisable;
	uint8_t statusDecimal;
	uint8_t statusBreak;
	uint8_t statusOverflow;
	uint8_t statusNegative;
	uint_fast32_t cycle;
	
} CPURegisters;

typedef void (*StandardOpPointer)(CPURegisters *,uint8_t);
typedef uint8_t (*WriteOpPointer)(CPURegisters *,uint8_t);
typedef void (*OperationMethodPointer)(id, SEL, uint8_t);

@interface NES6502Interpreter : NSObject {

	CPURegisters *_cpuRegisters;
	uint_fast32_t _nextIRQ;
	
	uint8_t *_zeroPage;
	uint8_t *_stack;
	uint8_t *_cpuRAM;
	
	uint8_t **_prgromBankPointers;
	uint8_t *_wram;
	
	uint16_t breakPoint;
	BOOL _irq;
	BOOL _encounteredUnsupportedOpcode;
	BOOL _encounteredBreakpoint;
	
	StandardOpPointer *_standardOperations;
	WriteOpPointer *_writeOperations;
	OperationMethodPointer *_operationMethods;
	SEL *_operationSelectors;
	uint8_t (*_readByteFromCPUAddressSpace)(id, SEL, uint16_t);
	
	NESCartridge *cartridge;
	NESPPUEmulator *ppu;
	NESAPUEmulator *apu;
	
	uint_fast32_t *_controllers;
	uint8_t _controller0ReadIndex;
	uint8_t _controller1ReadIndex;
}

- (id)initWithPPU:(NESPPUEmulator *)ppuEmu andAPU:(NESAPUEmulator *)apuEmu;
- (void)setCartridge:(NESCartridge *)cart;
- (void)reset;
- (void)resetCPUCycleCounter;
- (uint_fast32_t)executeUntilCycle:(uint_fast32_t)cycle;
- (uint_fast32_t)executeUntilCycleWithBreak:(uint_fast32_t)cycle;
- (uint16_t)breakPoint;
- (void)setBreakPoint:(uint16_t)counter;
- (uint8_t)currentOpcode;
- (CPURegisters *)cpuRegisters;
- (uint8_t)readByteFromCPUAddressSpace:(uint16_t)address;
- (uint16_t)readAddressFromCPUAddressSpace:(uint16_t)address;
- (void)writeByte:(uint8_t)byte toCPUAddress:(uint16_t)address;
- (uint_fast32_t)interpretOpcode;
- (void)setProgramCounter:(uint16_t)jump;
- (void)_performNonMaskableInterrupt;
- (void)setData:(uint_fast32_t)data forController:(int)index;
- (void)stealCycles:(uint_fast32_t)cycles;
- (void)setNextIRQ:(uint_fast32_t)cycles;

@property(nonatomic) BOOL encounteredBreakpoint;

@end
