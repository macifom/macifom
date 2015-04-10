/*  NESTxROMCartridge.m
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

#import "NESTxROMCartridge.h"
#import "NES6502Interpreter.h"

#define IRQ_DELAY 6

@implementation NESTxROMCartridge

- (id)initWithPrgrom:(uint8_t *)prgrom chrrom:(uint8_t *)chrrom ppu:(NESPPUEmulator *)ppu cpu:(NES6502Interpreter *)cpu andiNesFlags:(iNESFlags *)flags
{
	[super initWithPrgrom:prgrom chrrom:chrrom ppu:ppu andiNesFlags:flags];
	
	_cpu = cpu;
	
	return self;
}

- (void)_switch1KBCHRROMBank:(uint_fast32_t)bank toBank:(uint_fast32_t)index
{
	uint_fast32_t bankCounter;
	uint_fast32_t selected1KBBank = (index & _chrromIndexMask) * BANK_SIZE_1KB / CHRROM_BANK_SIZE;
	
	// Rebuild CHRROM indices
	for (bankCounter = 0; bankCounter < (BANK_SIZE_1KB / CHRROM_BANK_SIZE); bankCounter++) {
		
		_chrromBankIndices[bankCounter + (bank * BANK_SIZE_1KB / CHRROM_BANK_SIZE)] = selected1KBBank + bankCounter;
	}
}

- (void)_switch2KBCHRROMBank:(uint_fast32_t)bank toBank:(uint_fast32_t)index
{
	uint_fast32_t bankCounter;
	uint_fast32_t selected2KBBank = (index & _chrromIndexMask) * BANK_SIZE_1KB / CHRROM_BANK_SIZE;
	
	// Rebuild CHRROM indices
	for (bankCounter = 0; bankCounter < (BANK_SIZE_2KB / CHRROM_BANK_SIZE); bankCounter++) {
		
		_chrromBankIndices[bankCounter + (bank * BANK_SIZE_2KB / CHRROM_BANK_SIZE)] = (selected2KBBank + bankCounter) & _chrromIndexMask;
	}
}

- (void)_switch8KBPRGROMBank:(uint_fast32_t)bank toBank:(uint_fast32_t)index
{
	uint_fast32_t bankCounter;
	uint_fast32_t selected8KBBank = (index & _prgromIndexMask) * (BANK_SIZE_8KB / PRGROM_BANK_SIZE);
	
	// Establish PRGROM indices
	for (bankCounter = 0; bankCounter < (BANK_SIZE_8KB / PRGROM_BANK_SIZE); bankCounter++) {
		
		_prgromBankIndices[bankCounter + (bank * BANK_SIZE_8KB / PRGROM_BANK_SIZE)] = selected8KBBank + bankCounter;
	}
}

- (void)_updateCHRROMBankForRegister:(uint8_t)reg
{
	switch (reg) {
			
		case 0:
			// Select 2 KB CHR bank at PPU $0000-$07FF (or $1000-$17FF)
			[self _switch2KBCHRROMBank:(_mmc3LowCHRROMIn1kbBanks ? 2 : 0) toBank:_mmc3BankRegisters[0]];
			break;
		case 1:
			// Select 2 KB CHR bank at PPU $0800-$0FFF (or $1800-$1FFF)
			[self _switch2KBCHRROMBank:(_mmc3LowCHRROMIn1kbBanks ? 3 : 1) toBank:_mmc3BankRegisters[1]];
		case 2:
			// Select 1 KB CHR bank at PPU $1000-$13FF (or $0000-$03FF)
			[self _switch1KBCHRROMBank:(_mmc3LowCHRROMIn1kbBanks ? 0 : 4) toBank:_mmc3BankRegisters[2]];
			break;
		case 3:	
			// Select 1 KB CHR bank at PPU $1400-$17FF (or $0400-$07FF)
			[self _switch1KBCHRROMBank:(_mmc3LowCHRROMIn1kbBanks ? 1 : 5) toBank:_mmc3BankRegisters[3]];
			break;
		case 4:
			// Select 1 KB CHR bank at PPU $1800-$1BFF (or $0800-$0BFF)
			[self _switch1KBCHRROMBank:(_mmc3LowCHRROMIn1kbBanks ? 2 : 6) toBank:_mmc3BankRegisters[4]];
			break;
		case 5:
			// Select 1 KB CHR bank at PPU $1C00-$1FFF (or $0C00-$0FFF)
			[self _switch1KBCHRROMBank:(_mmc3LowCHRROMIn1kbBanks ? 3 : 7) toBank:_mmc3BankRegisters[5]];
			break;
		default:
			break;
	}	
}

- (void)_updatePRGROMBankForRegister:(uint8_t)reg
{
	switch (reg) {
	
		case 6:
			// Select 8 KB PRG bank at $8000-$9FFF (or $C000-$DFFF)
			[self _switch8KBPRGROMBank:(_mmc3HighPRGROMSwappable ? 2 : 0) toBank:_mmc3BankRegisters[6]];
			break;
		case 7:
			// Select 8 KB PRG bank at $A000-$BFFF
			[self _switch8KBPRGROMBank:1 toBank:_mmc3BankRegisters[7]];
			break;
		default:
			break;
	}
}

- (void)_updateCHRROMBanks
{
	uint_fast32_t registerIndex;
	
	for (registerIndex = 0; registerIndex < 6; registerIndex++) {
	
		[self _updateCHRROMBankForRegister:registerIndex];
	}
}

- (void)_updatePRGROMBanks
{
	[self _updateCHRROMBankForRegister:6];
	[self _updateCHRROMBankForRegister:7];
	
	// Either 0x8000-0x9FFF or 0xC000-0xDFFF is fixed to second-to-last 8KB PRGROM bank
	[self _switch8KBPRGROMBank:(_mmc3HighPRGROMSwappable ? 0 : 2) toBank:((_iNesFlags->prgromSize - BANK_SIZE_16KB) / BANK_SIZE_8KB)];
}

- (void)_catchUpScanlineCounter:(uint_fast32_t)ppuCycle
{
	uint_fast32_t ppuStartingCycle, startingCyclesSincePrimingScanline, endingCyclesSincePrimingScanline, scanlineStartingCycle, scanlineEndingCycle;
	uint_fast32_t a12Raises = 0;
	uint8_t startingScanline, endingScanline;
	// uint8_t startingCounter = _mmc3IRQCounter;
	BOOL shortenPrimingScanline = [_ppu shortenPrimingScanline];
	
	ppuStartingCycle = _lastPPUCycle;
	
	if (ppuCycle < ppuStartingCycle) {
	
		// We must be on the previous frame
		[self _catchUpScanlineCounter:(shortenPrimingScanline ? CYCLES_IN_FRAME_SHORT : CYCLES_IN_FRAME_NORMAL)];
		ppuStartingCycle = _lastPPUCycle = 0;
	}
	
	if (_mmc3A12NormalOscillation) {
		
		if ((ppuStartingCycle < (CYCLES_OF_VBLANK + 260)) && (ppuCycle >= (CYCLES_OF_VBLANK + 260))) {
	
			a12Raises++;
		}
	
		if (ppuCycle > (shortenPrimingScanline ? CYCLES_BEFORE_RENDERING_SHORT : CYCLES_BEFORE_RENDERING_NORMAL)) {
	
			if (ppuStartingCycle < (shortenPrimingScanline ? CYCLES_BEFORE_RENDERING_SHORT : CYCLES_BEFORE_RENDERING_NORMAL)) {
			
				ppuStartingCycle = (shortenPrimingScanline ? CYCLES_BEFORE_RENDERING_SHORT : CYCLES_BEFORE_RENDERING_NORMAL);
			}
				
			startingCyclesSincePrimingScanline = ppuStartingCycle - (shortenPrimingScanline ? CYCLES_BEFORE_RENDERING_SHORT : CYCLES_BEFORE_RENDERING_NORMAL);
			endingCyclesSincePrimingScanline = ppuCycle - (shortenPrimingScanline ? CYCLES_BEFORE_RENDERING_SHORT : CYCLES_BEFORE_RENDERING_NORMAL);
			startingScanline = startingCyclesSincePrimingScanline / CYCLES_IN_SCANLINE_NORMAL;
			endingScanline = endingCyclesSincePrimingScanline / CYCLES_IN_SCANLINE_NORMAL;
			scanlineStartingCycle = startingCyclesSincePrimingScanline % CYCLES_IN_SCANLINE_NORMAL;
			scanlineEndingCycle = endingCyclesSincePrimingScanline % CYCLES_IN_SCANLINE_NORMAL;
		
			// Add a raise if we pass the beginning of sprite access in the starting scanline
			if ((scanlineStartingCycle < 260) && ((scanlineEndingCycle >= 260) || (endingScanline > startingScanline))) {
			
				a12Raises++;
			}
		
			if (endingScanline > startingScanline) {
		
				// If we end on a different scanline and pass the beginning of sprite access there
				if (scanlineEndingCycle >= 260) a12Raises++;
			
				// Add for all sprite access in the intervening scanlines
				a12Raises += endingScanline - startingScanline - 1;
			}
		}
		// NSLog(@"Catching up scanline counter from PPU cycle %d to %d. %d A12 raises occurred.",_lastPPUCycle,ppuCycle,a12Raises);
	
		// Reload counter if the flag is set and at least one A12 rising edge occurred
		if (_mmc3ReloadIRQCounter && a12Raises) {

			a12Raises--;
			_mmc3ReloadIRQCounter = NO;
			_mmc3IRQCounter = _mmc3IRQCounterReloadValue;
			// FIXME: An IRQ could also be caught here if starting counter is non-zero and reload is zero
		}
	
		// Check to see if the counter reached zero
		if (a12Raises > _mmc3IRQCounter) {
		
			_mmc3IRQCounter = _mmc3IRQCounterReloadValue - ((a12Raises - 1) - _mmc3IRQCounter);
			// if (startingCounter) NSLog(@"MMC3 IRQ occurred during catch-up.");
		}
		else _mmc3IRQCounter -= a12Raises;
	}
	// else  NSLog(@"MMC3 IRQ catch-up routine aborted as A12 oscillation is atypical.");
	// if (_mmc3IRQCounter < 0) NSLog(@"MMC3 IRQ Counter less than zero!");
	// Set the last PPU cycle
	// NSLog(@"MMC3 IRQ counter value is %d.",_mmc3IRQCounter);
	
	_lastPPUCycle = ppuCycle;
}

- (uint_fast32_t)_cpuCyclesBeforeIRQ
{
	uint_fast32_t ppuCycle, cyclesToAdd, scanlineCycle, cyclesPastPrimingScanline, a12RaisesBeforeIRQ, ppuCyclesBeforeIRQ, counter;
	// int_fast32_t estimatedIRQCyclePastPriming;
	BOOL shortenPrimingScanline = [_ppu shortenPrimingScanline];
	
	if (_mmc3IRQEnabled && _mmc3A12NormalOscillation) {
				
		if (_mmc3ReloadIRQCounter || (_mmc3IRQCounter == 0)) {
		
			// Non-zero counter will be reset to zero
			if (_mmc3IRQCounterReloadValue == 0) {
			
				if (_mmc3IRQCounter > 0) a12RaisesBeforeIRQ = 1; // Will IRQ on the next raise
				else return 0xFFFFFFFF; // If the counter is zero and we reload zero there'll be no IRQ
			}
			else {
				
				// Counter will reset and count down from non-zero to zero
				a12RaisesBeforeIRQ = _mmc3IRQCounterReloadValue + 1;
			}
		}
		else {
		
			// Counter will count down from non-zero to zero
			a12RaisesBeforeIRQ = _mmc3IRQCounter;
		}
		
		// Determine PPU cycles before next IRQ
		ppuCyclesBeforeIRQ = 0;
		ppuCycle = _lastPPUCycle;
		
		for (counter = 0; counter < a12RaisesBeforeIRQ; counter++) {
			
			if (ppuCycle < (CYCLES_OF_VBLANK + 260)) {
			
				ppuCyclesBeforeIRQ += (CYCLES_OF_VBLANK + 260) - ppuCycle;
				ppuCycle = CYCLES_OF_VBLANK + 260;
			}
			else if (ppuCycle >= (shortenPrimingScanline ? 88919 : 88920)) {
			
				ppuCyclesBeforeIRQ += ((shortenPrimingScanline ? CYCLES_IN_FRAME_SHORT : CYCLES_IN_FRAME_NORMAL) - ppuCycle) + CYCLES_OF_VBLANK + 260;
				ppuCycle = CYCLES_OF_VBLANK + 260;
				shortenPrimingScanline = !shortenPrimingScanline;
			}
			else {
			
				// Figure out the odd/even frame timing in the priming scanline
				if (ppuCycle < (shortenPrimingScanline ? CYCLES_BEFORE_RENDERING_SHORT : CYCLES_BEFORE_RENDERING_NORMAL)) {
				
					ppuCyclesBeforeIRQ += (shortenPrimingScanline ? CYCLES_BEFORE_RENDERING_SHORT : CYCLES_BEFORE_RENDERING_NORMAL) - ppuCycle;
					ppuCycle = shortenPrimingScanline ? CYCLES_BEFORE_RENDERING_SHORT : CYCLES_BEFORE_RENDERING_NORMAL;
				}
				
				cyclesPastPrimingScanline = ppuCycle - (shortenPrimingScanline ? CYCLES_BEFORE_RENDERING_SHORT : CYCLES_BEFORE_RENDERING_NORMAL);
				scanlineCycle = cyclesPastPrimingScanline % 341;
				
				if (scanlineCycle < 260) cyclesToAdd = 260 - scanlineCycle;
				else cyclesToAdd = 260 + (341 - scanlineCycle);
				
				ppuCycle += cyclesToAdd;
				ppuCyclesBeforeIRQ += cyclesToAdd;
			}
		}
	} else return 0xffffffff; // Perhaps sometime in the distant future, but not this frame
	
	// estimatedIRQCyclePastPriming = (((_lastPPUCycle + ppuCyclesBeforeIRQ) % (shortenPrimingScanline ? CYCLES_IN_FRAME_SHORT : CYCLES_IN_FRAME_NORMAL)) - (shortenPrimingScanline ? CYCLES_BEFORE_RENDERING_SHORT : CYCLES_BEFORE_RENDERING_NORMAL));
	// NSLog(@"Next MMC3 IRQ expected to occur on PPU Scanline %d Cycle %d.",estimatedIRQCyclePastPriming / 341,estimatedIRQCyclePastPriming % 341);
	ppuCyclesBeforeIRQ += IRQ_DELAY; // FIXME: This actually needs to be accounted for in the CPU interpreter
	
	return (ppuCyclesBeforeIRQ / 3) + (ppuCyclesBeforeIRQ % 3 ? 1 : 0);
}

- (void)ppuStateChanged:(PPUState *)state
{
	BOOL newA12OscillationState;
	
	// NSLog(@"Notified of new PPU state.");
	
	// 1. Catch-up MMC3 Scanline Counter
	[self _catchUpScanlineCounter:state->cycle];
	
	// FIXME: Doesn't take into consideration 8x16 sprites!
	
	// If PPU is on (i.e. background or sprite rendering enabled and sprites and background and loaded from upper and lower banks, respectively
	newA12OscillationState = (((state->controlRegister2 & 0x8) || (state->controlRegister2 & 0x10)) && 
		(state->controlRegister1 & 0x8) && !(state->controlRegister1 & 0x10));
	
	// 2. See what changed in PPU status (e.g. Is A12 oscillation normal?)
	if (_mmc3A12NormalOscillation != newA12OscillationState) {
	
		// NSLog(@"PPU has changed A12 oscillation pattern to %@.",newA12OscillationState ? @"normal" : @"irregular");
		_mmc3A12NormalOscillation = newA12OscillationState;
		[_cpu setNextIRQ:[self _cpuCyclesBeforeIRQ]];
	}
}

- (void)servicedInterruptOnCycle:(uint_fast32_t)cycle
{
	[_ppu runPPUUntilCPUCycle:cycle];
	[self _catchUpScanlineCounter:[_ppu cyclesSinceVINT]];
	[_cpu setNextIRQ:[self _cpuCyclesBeforeIRQ]];
}

- (void)writeByte:(uint8_t)byte toPRGROMwithCPUAddress:(uint16_t)address onCycle:(uint_fast32_t)cycle
{
	BOOL oldCHRROMBankConfiguration;
	BOOL oldPRGROMBankConfiguration;
	
	if (address < 0xA000) {
	
		// 0x8000 - 0x9FFF: Bank Select / Bank Data
		if (address & 0x1) {
			
			// Bank Data
			_mmc3BankRegisters[_bankRegisterToUpdate] = byte;
			
			if (_bankRegisterToUpdate < 6) {
			
				// CHRROM Bank Update
				[_ppu runPPUUntilCPUCycle:cycle];
				[self _updateCHRROMBankForRegister:_bankRegisterToUpdate];
				[self rebuildCHRROMPointers];
			}
			else {
				
				// PRGROM Bank update
				[self _updatePRGROMBankForRegister:_bankRegisterToUpdate];
				[self rebuildPRGROMPointers];
			}
		}
		else {
			
			// Bank Select
			_bankRegisterToUpdate = byte & 0x7;
			
			oldCHRROMBankConfiguration = _mmc3LowCHRROMIn1kbBanks;
			oldPRGROMBankConfiguration = _mmc3HighPRGROMSwappable;
			
			_mmc3LowCHRROMIn1kbBanks = (byte & 0x80 ? YES : NO);
			_mmc3HighPRGROMSwappable = (byte & 0x40 ? YES : NO);
			
			if (_mmc3LowCHRROMIn1kbBanks != oldCHRROMBankConfiguration) {
			
				[_ppu runPPUUntilCPUCycle:cycle];
				[self _updateCHRROMBanks];
				[self rebuildCHRROMPointers];
			}
			
			if (_mmc3HighPRGROMSwappable != oldPRGROMBankConfiguration) {
				
				[self _updatePRGROMBanks];
				[self rebuildPRGROMPointers];
			}
		}
	}
	else if (address < 0xC000) {
		
		// 0xA000 - 0xBFFF: Mirroring / WRAM Protect
		if (address & 0x1) {
			
			// WRAM Protect
			_mmc3WRAMChipEnable = (byte & 0x80 ? YES : NO);
			_mmc3WRAMWriteDisable = (byte & 0x40 ? YES : NO);
		}
		else {
			
			// Mirroring
			[_ppu changeMirroringTypeTo:(byte & 0x1 ? NESHorizontalMirroring : NESVerticalMirroring) onCycle:cycle];
		}
	}
	else if (address < 0xE000) {
		
		// 0xC000 - 0xDFFF: IRQ Latch / IRQ Reload
		if (address & 0x1) {
			
			// IRQ Reload
			// Writing any value to this register sets the MMC3 IRQ counter to reload on the next A12 rising edge (rather than decrement)
			// NSLog(@"IRQ Reload enabled on CPU cycle %d.",cycle);
			// 1. Run PPU
			[_ppu runPPUUntilCPUCycle:cycle];
			// 2. Catch-up MMC3 Scanline Counter
			[self _catchUpScanlineCounter:[_ppu cyclesSinceVINT]];
			// 3. Apply value
			_mmc3ReloadIRQCounter = YES;
			// 4. Determine CPU cycles before next IRQ
			[_cpu setNextIRQ:[self _cpuCyclesBeforeIRQ]];
		}
		else {
			
			// IRQ Latch
			// NSLog(@"IRQ Latch set to %d on CPU cycle %d.",byte,cycle);
			// 1. Run PPU
			[_ppu runPPUUntilCPUCycle:cycle];
			// 2. Catch-up MMC3 Scanline Counter
			[self _catchUpScanlineCounter:[_ppu cyclesSinceVINT]];
			// 3. Apply value
			_mmc3IRQCounterReloadValue = byte;
			// 4. Determine CPU cycles before next IRQ
			[_cpu setNextIRQ:[self _cpuCyclesBeforeIRQ]];
		}
	}
	else {
		
		// 0xE000 - 0xFFFF: IRQ Disable / IRQ Enable
		if (address & 0x1) {
			
			// IRQ Enable
			// NSLog(@"IRQ enabled on CPU cycle %d.",cycle);
			// 1. Run PPU
			[_ppu runPPUUntilCPUCycle:cycle];
			// 2. Catch-up MMC3 Scanline Counter
			[self _catchUpScanlineCounter:[_ppu cyclesSinceVINT]];
			// 3. Apply value
			_mmc3IRQEnabled = YES;
			// 4. Determine CPU cycles before next IRQ
			[_cpu setNextIRQ:[self _cpuCyclesBeforeIRQ]];
		}
		else {
			
			// IRQ Disable
			// Writing any value to this register will disable MMC3 interrupts AND acknowledge any pending interrupts.
			// NSLog(@"IRQ disabled on CPU cycle %d.",cycle);
			// 1. Run PPU
			[_ppu runPPUUntilCPUCycle:cycle];
			// 2. Catch-up MMC3 Scanline Counter
			[self _catchUpScanlineCounter:[_ppu cyclesSinceVINT]];
			// 3. Apply value
			_mmc3IRQEnabled = NO;
			// 4. As this acknowledges any pending interrupts, set to no pending interrupt
			[_cpu setNextIRQ:[self _cpuCyclesBeforeIRQ]];
		}
	}
}

- (void)setInitialROMPointers
{	
	uint_fast32_t registerIndex;
		
	_mmc3IRQEnabled = NO;
	_mmc3ReloadIRQCounter = NO;
	_mmc3HighPRGROMSwappable = NO;
	_mmc3LowCHRROMIn1kbBanks = NO;
	_mmc3WRAMWriteDisable = NO;
	_mmc3WRAMChipEnable = NO;
	
	_lastPPUCycle = 0;
	_mmc3IRQCounter = 0;
	_mmc3IRQCounterReloadValue = 0;
	_mmc3A12NormalOscillation = NO;
	_bankRegisterToUpdate = 0;
	_prgromIndexMask = (_iNesFlags->prgromSize / BANK_SIZE_8KB) - 1;
	_chrromIndexMask = (_iNesFlags->chrromSize / BANK_SIZE_1KB) - 1;
		
	for (registerIndex = 0; registerIndex < 8; registerIndex++) {
			
		_mmc3BankRegisters[registerIndex] = 0;
	}
	
	// CPU $E000-$FFFF: 8 KB PRG ROM bank, fixed to the last bank
	[self _switch8KBPRGROMBank:3 toBank:((_iNesFlags->prgromSize - BANK_SIZE_8KB) / BANK_SIZE_8KB)];
	[self _updatePRGROMBanks];
	[self rebuildPRGROMPointers];
	
	[self _updateCHRROMBanks];
	[self rebuildCHRROMPointers];
	
	// Listen to PPU state changes that could affect A12 oscillation
	[_ppu observeStateForTarget:self andSelector:@selector(ppuStateChanged:)];
}

@end
