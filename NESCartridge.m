/*  NESCartridge.m
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

#import "NESCartridge.h"
#import "NESPPUEmulator.h"

@implementation NESCartridge

- (void)rebuildPRGROMPointers
{
	uint_fast32_t bankCounter;
	
	// Establish PRGROM pointers
	for (bankCounter = 0; bankCounter < (PRGROM_APERTURE_SIZE / PRGROM_BANK_SIZE); bankCounter++) {
		
		_prgromBankPointers[bankCounter] = _prgrom + (_prgromBankIndices[bankCounter] * PRGROM_BANK_SIZE);
	}
}

- (void)rebuildCHRROMPointers
{
	uint_fast32_t bankCounter;
	
	// Establish CHRROM pointers for the first 4KB bank
	for (bankCounter = 0; bankCounter < (CHRROM_APERTURE_SIZE / CHRROM_BANK_SIZE); bankCounter++) {
		
		_chrromBankPointers[bankCounter] = _chrrom + (_chrromBankIndices[bankCounter] * CHRROM_BANK_SIZE);
	}
}

- (id)initWithPrgrom:(uint8_t *)prgrom chrrom:(uint8_t *)chrrom ppu:(NESPPUEmulator *)ppu andiNesFlags:(iNESFlags *)flags;
{
	NSData *savedSram;
	
	[super init];
	
	_prgrom = prgrom;
	_chrrom = chrrom;
	_ppu = ppu; // Non-retained reference to the PPU
	_iNesFlags = flags;
	_prgromBankPointers = (uint8_t **)malloc(sizeof(uint8_t *)*(PRGROM_APERTURE_SIZE / PRGROM_BANK_SIZE));
	_chrromBankPointers = (uint8_t **)malloc(sizeof(uint8_t *)*(CHRROM_APERTURE_SIZE / CHRROM_BANK_SIZE));
	if (_iNesFlags->chrromSize) {
		
		_usesCHRRAM = NO;
	}
	else {
	
		_chrrom = (uint8_t *)malloc(sizeof(uint8_t)*CHRROM_APERTURE_SIZE);
		bzero(_chrrom,sizeof(uint8_t)*CHRROM_APERTURE_SIZE);
		_iNesFlags->chrromSize = CHRROM_APERTURE_SIZE;
		_usesCHRRAM = YES;
	}
	
	_prgromBankIndices = (uint_fast32_t *)malloc(sizeof(uint_fast32_t)*(PRGROM_APERTURE_SIZE / PRGROM_BANK_SIZE));
	_chrromBankIndices = (uint_fast32_t *)malloc(sizeof(uint_fast32_t)*(CHRROM_APERTURE_SIZE / CHRROM_BANK_SIZE));
	_wram = (uint8_t *)malloc(sizeof(uint8_t)*WRAM_SIZE);
	
	// Load stored WRAM data, if present
	if (_iNesFlags->usesBatteryBackedRAM) {
		
		savedSram = [NSData dataWithContentsOfFile:[NSString stringWithFormat:@"%@.sav",[_iNesFlags->pathToFile stringByDeletingPathExtension]]];
		if (savedSram) {
			
			[savedSram getBytes:_wram length:WRAM_SIZE];
		}
	}
	
	return self;
}

- (void)dealloc
{
	free(_prgromBankPointers);
	free(_chrromBankPointers);
	free(_prgromBankIndices);
	free(_chrromBankIndices);
	free(_prgrom);
	free(_chrrom);
	free(_wram);
	[_iNesFlags->pathToFile release];
	free(_iNesFlags);
	
	[super dealloc];
}

- (uint8_t *)wram
{
	return _wram;
}

- (iNESFlags *)iNesFlags
{
	return _iNesFlags;
}

- (uint8_t **)prgromBankPointers
{
	return _prgromBankPointers;
}

- (uint8_t **)chrromBankPointers
{
	return _chrromBankPointers;
}

- (uint_fast32_t *)chrromBankIndices
{
	return _chrromBankIndices;
}

- (void)writeByte:(uint8_t)byte toWRAMwithCPUAddress:(uint16_t)address onCycle:(uint_fast32_t)cycle
{
	_wram[address & (WRAM_SIZE - 1)] = byte;
}

- (void)writeByte:(uint8_t)byte toPRGROMwithCPUAddress:(uint16_t)address onCycle:(uint_fast32_t)cycle
{
	
}

- (void)configureInitialPPUState
{
	if (_iNesFlags->usesVerticalMirroring) [_ppu setMirroringType:NESVerticalMirroring];
	else [_ppu setMirroringType:NESHorizontalMirroring];
	// FIXME: I'm not properly handling single-nametable mirroring here
	
	[_ppu cacheCHRROM:_chrrom length:_iNesFlags->chrromSize bankIndices:_chrromBankIndices isWritable:_usesCHRRAM];
}

- (void)setInitialROMPointers
{
	uint_fast32_t bankCounter;
	
	// NROM has either 16KB or 32KB of PRGROM, which is not swappable
	uint_fast32_t numberOfBanks = _iNesFlags->prgromSize / PRGROM_BANK_SIZE;
	
	// Establish PRGROM indices
	for (bankCounter = 0; bankCounter < (PRGROM_APERTURE_SIZE / PRGROM_BANK_SIZE); bankCounter++) {
		
		_prgromBankIndices[bankCounter] = bankCounter % numberOfBanks;
	}
	[self rebuildPRGROMPointers];

	// NROM has 8KB of CHRROM, which is not swappable
	// Establish CHRROM indices
	for (bankCounter = 0; bankCounter < (CHRROM_APERTURE_SIZE / CHRROM_BANK_SIZE); bankCounter++) {
		
		_chrromBankIndices[bankCounter] = bankCounter;
	}
	[self rebuildCHRROMPointers];
}

- (BOOL)writeWRAMToDisk
{
	NSData *sramData;
	
	if (_iNesFlags->usesBatteryBackedRAM) {
		
		sramData = [NSData dataWithBytes:_wram length:WRAM_SIZE];
		return [sramData writeToFile:[NSString stringWithFormat:@"%@.sav",[_iNesFlags->pathToFile stringByDeletingPathExtension]] atomically:NO];
	}
	
	return NO;
}

- (void)servicedInterruptOnCycle:(uint_fast32_t)cycle;
{
	
}

@end
