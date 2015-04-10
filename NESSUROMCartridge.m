/* NESSUROMCartridge.m
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

#import "NESSUROMCartridge.h"


@implementation NESSUROMCartridge

- (uint_fast32_t)_outerPRGROMBankSize
{
	return BANK_SIZE_256KB;
}

- (void)_switch16KBPRGROMBank:(uint_fast32_t)bank toBank:(uint_fast32_t)index
{
	uint_fast32_t bankCounter;
	uint_fast32_t selected16KBBank = index * (BANK_SIZE_16KB / PRGROM_BANK_SIZE);
	
	// Establish PRGROM indices
	for (bankCounter = 0; bankCounter < (BANK_SIZE_16KB / PRGROM_BANK_SIZE); bankCounter++) {
		
		_prgromBankIndices[bankCounter + (bank * BANK_SIZE_16KB / PRGROM_BANK_SIZE)] = _suromPRGROMBankOffset + selected16KBBank + bankCounter;
	}
}

- (void)_switch32KBPRGROMToBank:(uint_fast32_t)index
{
	uint_fast32_t bankCounter;
	uint_fast32_t selected32KBBank = index * (PRGROM_APERTURE_SIZE / PRGROM_BANK_SIZE);
	
	// Establish PRGROM indices
	for (bankCounter = 0; bankCounter < (PRGROM_APERTURE_SIZE / PRGROM_BANK_SIZE); bankCounter++) {
		
		_prgromBankIndices[bankCounter] = _suromPRGROMBankOffset + selected32KBBank + bankCounter;
	}
}

- (void)_setMMC1CHRROMBank0Register:(uint8_t)byte
{
	[super _setMMC1CHRROMBank0Register:byte];
	
	_suromPRGROMBankOffset = (byte & 0x10) ? BANK_SIZE_256KB / PRGROM_BANK_SIZE : 0;
	[self _setMMC1PRGROMBankRegister:_mmc1PRGROMBankRegister]; // Force an update to the PRGROM indices
}

- (void)_setMMC1CHRROMBank1Register:(uint8_t)byte
{
	[super _setMMC1CHRROMBank1Register:byte];
	
	if (_mmc1Switch4KBCHRROMBanks) {
		
		_suromPRGROMBankOffset = (byte & 0x10) ? BANK_SIZE_256KB / PRGROM_BANK_SIZE : 0;
		[self _setMMC1PRGROMBankRegister:_mmc1PRGROMBankRegister]; // Force an update to the PRGROM indices
	}
}

- (void)setInitialROMPointers
{
	_suromPRGROMBankOffset = 0;
	[super setInitialROMPointers];
}

@end
