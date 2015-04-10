/*  NESTxROMCartridge.h
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
#import "NESCartridge.h"
#import "NESPPUEmulator.h"

@class NES6502Interpreter;

@interface NESTxROMCartridge : NESCartridge {

	BOOL _mmc3IRQEnabled;
	BOOL _mmc3ReloadIRQCounter;
	BOOL _mmc3A12NormalOscillation;
	BOOL _mmc3HighPRGROMSwappable;
	BOOL _mmc3LowCHRROMIn1kbBanks;
	BOOL _mmc3WRAMWriteDisable;
	BOOL _mmc3WRAMChipEnable;
	
	uint8_t _prgromIndexMask;
	uint8_t _chrromIndexMask;
	uint8_t _mmc3BankRegisters[8];
	uint8_t _mmc3IRQCounter;
	uint8_t _mmc3IRQCounterReloadValue;
	uint8_t _bankRegisterToUpdate;
	
	uint_fast32_t _lastPPUCycle;
	
	NES6502Interpreter *_cpu;
}

- (id)initWithPrgrom:(uint8_t *)prgrom chrrom:(uint8_t *)chrrom ppu:(NESPPUEmulator *)ppu cpu:(NES6502Interpreter *)cpu andiNesFlags:(iNESFlags *)flags;
- (void)ppuStateChanged:(PPUState *)state;

@end
