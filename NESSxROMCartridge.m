/*  NESSNROMCartridge.m
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

#import "NESSxROMCartridge.h"
#import "NESPPUEmulator.h"

@implementation NESSxROMCartridge

- (uint_fast32_t)_outerPRGROMBankSize
{
	return _iNesFlags->prgromSize;
}

- (void)_switch4KBCHRROMBank:(uint_fast32_t)bank toBank:(uint_fast32_t)index
{
	uint_fast32_t bankCounter;
	uint_fast32_t selected4KBBank = index * BANK_SIZE_4KB / CHRROM_BANK_SIZE;
	
	// Rebuild CHRROM indices
	for (bankCounter = 0; bankCounter < (BANK_SIZE_4KB / CHRROM_BANK_SIZE); bankCounter++) {
		
		_chrromBankIndices[bankCounter + (bank * BANK_SIZE_4KB / CHRROM_BANK_SIZE)] = selected4KBBank + bankCounter;
	}
}

- (void)_switch8KBCHRROMToBank:(uint_fast32_t)index
{
	uint_fast32_t bankCounter;
	uint_fast32_t selected8KBBank = index * BANK_SIZE_8KB / CHRROM_BANK_SIZE;
	
	// Rebuild CHRROM indices
	for (bankCounter = 0; bankCounter < (CHRROM_APERTURE_SIZE / CHRROM_BANK_SIZE); bankCounter++) {
		
		_chrromBankIndices[bankCounter] = selected8KBBank + bankCounter;
	}
}

- (void)_switch16KBPRGROMBank:(uint_fast32_t)bank toBank:(uint_fast32_t)index
{
	uint_fast32_t bankCounter;
	uint_fast32_t selected16KBBank = index * (BANK_SIZE_16KB / PRGROM_BANK_SIZE);
	
	// Establish PRGROM indices
	for (bankCounter = 0; bankCounter < (BANK_SIZE_16KB / PRGROM_BANK_SIZE); bankCounter++) {
		
		_prgromBankIndices[bankCounter + (bank * BANK_SIZE_16KB / PRGROM_BANK_SIZE)] = selected16KBBank + bankCounter;
	}
}

- (void)_switch32KBPRGROMToBank:(uint_fast32_t)index
{
	uint_fast32_t bankCounter;
	uint_fast32_t selected32KBBank = index * (PRGROM_APERTURE_SIZE / PRGROM_BANK_SIZE);
	
	// Establish PRGROM indices
	for (bankCounter = 0; bankCounter < (PRGROM_APERTURE_SIZE / PRGROM_BANK_SIZE); bankCounter++) {
		
		_prgromBankIndices[bankCounter] = selected32KBBank + bankCounter;
	}
}

- (void)_setMMC1CHRROMBank0Register:(uint8_t)byte
{
	// NSLog(@"MMC1: Setting CHRROM Bank 0 register to 0x%2x.",byte);
	
	// CHRROM 4KB Bank 0 Swap
	if (_mmc1Switch4KBCHRROMBanks) {
		
		// NSLog(@"MMC1 Attempting 4KB CHRROM Bank 0 Swap.");
		[self _switch4KBCHRROMBank:0 toBank:(_usesCHRRAM ? byte & 1 : byte)];
	}
	else {
		
		if (!_usesCHRRAM) {
			
			[self _switch8KBCHRROMToBank:byte >> 1];
		}
		else {
			
			// FIXME: I don't think this is supported, unless there are MMC1 games with more than 8KB of CHRRAM.
			// NSLog(@"MMC1: CHRRAM Game Attempted to Switch CHRROM Bank 0!");
		}
	}
	
	_mmc1CHRROMBank0Register = byte;
	
	[self rebuildCHRROMPointers];
}

- (void)_setMMC1CHRROMBank1Register:(uint8_t)byte
{
	// NSLog(@"MMC1: Setting CHRROM Bank 1 register to 0x%2x.",byte);
	
	// CHRRROM 4KB Bank 1 Swap
	if (_mmc1Switch4KBCHRROMBanks) {
		
		// NSLog(@"MMC1 Attempting 4KB CHRROM Bank 1 Swap.");
		[self _switch4KBCHRROMBank:1 toBank:(_usesCHRRAM ? byte & 1 : byte)];
	}
	
	_mmc1CHRROMBank1Register = byte;
	
	[self rebuildCHRROMPointers];
}

- (void)_setMMC1PRGROMBankRegister:(uint8_t)byte
{
	// NSLog(@"MMC1: Setting PRGROM Bank register to 0x%2x.",byte);
	
	// PRGROM Bank Swap
	if (_mmc1Switch16KBPRGROMBanks) {
		
		if (_mmc1SwitchFirst16KBBank) {
			
			[self _switch16KBPRGROMBank:0 toBank:byte & 0xF];
			[self _switch16KBPRGROMBank:1 toBank:(([self _outerPRGROMBankSize] - BANK_SIZE_16KB) / BANK_SIZE_16KB)];

		}
		else {
			
			[self _switch16KBPRGROMBank:0 toBank:0];
			[self _switch16KBPRGROMBank:1 toBank:byte & 0xF];
		}
	}
	else {
		
		// PRGROM 32KB Swap
		[self _switch32KBPRGROMToBank:byte & 0xE];
	}
	
	// FIXME: Bit 4 (0x10) Toggles PRGRAM on MMC1B and MMC1C (0: enabled; 1: disabled; ignored on MMC1A)
	_mmc1PRGROMBankRegister = byte;
	
	[self rebuildPRGROMPointers];
}

- (void)_setMMC1ControlRegister:(uint8_t)byte onCycle:(uint_fast32_t)cycle
{
	// NSLog(@"MMC1: Setting control register to 0x%2x.",byte);
	
	// Set Mirroring Mode
	switch (byte & 0x3) {
			
		case 0:
			// Single-Screen Mirroring (Lower Bank)
			// NSLog(@"MMC1 Switcing to Single-Screen (Lower Bank) Mirroring Mode");
			[_ppu changeMirroringTypeTo:NESSingleScreenLowerMirroring onCycle:cycle];
			break;
		case 1:
			// Single-Screen Mirroring (Upper Bank)
			[_ppu changeMirroringTypeTo:NESSingleScreenUpperMirroring onCycle:cycle];
			break;
		case 2:
			// Vertical Mirroring
			// NSLog(@"MMC1 Switcing to Vertical Mirroring Mode");
			[_ppu changeMirroringTypeTo:NESVerticalMirroring onCycle:cycle];
			break;
		case 3:
			// Horizontal Mirroring
			// NSLog(@"MMC1 Switcing to Horizontal Mirroring Mode");
			[_ppu changeMirroringTypeTo:NESHorizontalMirroring onCycle:cycle];
			break;
	}
	
	// PRGROM Bank Switing Mode
	_mmc1Switch16KBPRGROMBanks = (byte & 0x8) ? YES : NO;
	/*
	 if (_mmc1Switch16KBPRGROMBanks) NSLog(@"MMC1 Using 16KB PRGROM Banks");
	 else NSLog(@"MMC1 Using 32KB PRGROM Banks"); 
	 */
	_mmc1SwitchFirst16KBBank = (byte & 0x4) ? YES : NO;
	/*
	 if (_mmc1SwitchFirst16KBBank) NSLog(@"MMC1 Will Switch Lower PRGROM Bank in 16KB Bank Mode");
	 else NSLog(@"MMC1 Will Switch Upper PRGROM Bank in 16KB Bank Mode");
	 */
	
	// CHRROM Bank Switching Mode
	_mmc1Switch4KBCHRROMBanks = (byte & 0x10) ? YES : NO;
	/*
	 if (_mmc1Switch4KBCHRROMBanks) NSLog(@"MMC1 Using 4KB CHRROM Banks");
	 else NSLog(@"MMC1 Using 8KB CHRROM Banks");
	 */
	
	// Store the current values
	_mmc1ControlRegister = byte;
	
	// Reset all pointers to reflect the changed settings
	[self _setMMC1CHRROMBank0Register:_mmc1CHRROMBank0Register];
	[self _setMMC1CHRROMBank1Register:_mmc1CHRROMBank1Register];
	[self _setMMC1PRGROMBankRegister:_mmc1PRGROMBankRegister];
}

- (void)writeByte:(uint8_t)byte toPRGROMwithCPUAddress:(uint16_t)address onCycle:(uint_fast32_t)cycle
{	
	if (byte & 0x80) {
		
		// NSLog(@"MMC1 Mapper Reset Triggered");
		[self _setMMC1ControlRegister:(_mmc1ControlRegister | 0xC) onCycle:cycle];
		_register = 0;
		_serialWriteCounter = 0;
	}
	else {
		
		_register |= ((byte & 0x1) << _serialWriteCounter++); // OR in next serial bit
		
		// NSLog(@"MMC1: Bit %d written to address 0x%4x on write #%d.",byte & 0x1,address,_serialWriteCounter);
		// Commit a change on the 5th Write
		if (_serialWriteCounter == 5) {
			
			// NSLog(@"MMC1: 5th write has occurred, setting register.");
			if (address < 0xA000) {
				
				// Control Register Write
				[self _setMMC1ControlRegister:_register onCycle:cycle];
			}
			else if (address < 0xC000) {
				
				[_ppu runPPUUntilCPUCycle:cycle];
				[self _setMMC1CHRROMBank0Register:_register];
			}
			else if (address < 0xE000) {
				
				[_ppu runPPUUntilCPUCycle:cycle];
				[self _setMMC1CHRROMBank1Register:_register];
			}
			else {
				
				[self _setMMC1PRGROMBankRegister:_register];
			}
			
			_register = 0;
			_serialWriteCounter = 0;
		}
	}	
}

- (void)setInitialROMPointers
{		
	_serialWriteCounter = 0;
	_register = 0;
	_mmc1ControlRegister = 0;
	_mmc1CHRROMBank0Register = 0;
	_mmc1CHRROMBank1Register = 0;
	_mmc1PRGROMBankRegister = 0;
	_mmc1Switch16KBPRGROMBanks = YES;
	_mmc1SwitchFirst16KBBank = YES;
	_mmc1Switch4KBCHRROMBanks = NO;
	
	[self _switch16KBPRGROMBank:0 toBank:0];
	[self _switch16KBPRGROMBank:1 toBank:(([self _outerPRGROMBankSize] - BANK_SIZE_16KB) / BANK_SIZE_16KB)];
	[self rebuildPRGROMPointers];
	
	[self _switch8KBCHRROMToBank:0];
	[self rebuildCHRROMPointers];
}

@end
