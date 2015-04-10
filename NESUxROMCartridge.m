/*  NESUxROMCartridge.m
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

#import "NESUxROMCartridge.h"

@implementation NESUxROMCartridge

- (void)writeByte:(uint8_t)byte toPRGROMwithCPUAddress:(uint16_t)address onCycle:(uint_fast32_t)cycle
{	
	uint_fast32_t bankCounter;
	uint_fast32_t first16KprgromBank = (byte & (_iNesFlags->prgromSize > (BANK_SIZE_16KB * 8) ? 0xF : 0x7)) * (BANK_SIZE_16KB / PRGROM_BANK_SIZE);
	
	// Rebuild PRGROM pointers for the first 16KB
	for (bankCounter = 0; bankCounter < (BANK_SIZE_16KB / PRGROM_BANK_SIZE); bankCounter++) {
		
		_prgromBankIndices[bankCounter] = first16KprgromBank + bankCounter;
	}
	[self rebuildPRGROMPointers];
}

- (void)setInitialROMPointers
{	
	uint_fast32_t bankCounter;
	uint_fast32_t last16KBBankIndex = (_iNesFlags->prgromSize - BANK_SIZE_16KB) / PRGROM_BANK_SIZE;
	
	// Establish PRGROM pointers for the first 16KB bank, which is swappable
	for (bankCounter = 0; bankCounter < (BANK_SIZE_16KB / PRGROM_BANK_SIZE); bankCounter++) {
		
		_prgromBankIndices[bankCounter] = bankCounter;
	}
	
	// Establish PRGROM pointers for the last 16KB bank, which is fixed
	for (bankCounter = 0; bankCounter < (BANK_SIZE_16KB / PRGROM_BANK_SIZE); bankCounter++) {
		
		_prgromBankIndices[bankCounter + (BANK_SIZE_16KB / PRGROM_BANK_SIZE)] = last16KBBankIndex + bankCounter;
	}
	[self rebuildPRGROMPointers];
	
	// Establish CHRROM pointers
	for (bankCounter = 0; bankCounter < (CHRROM_APERTURE_SIZE / CHRROM_BANK_SIZE); bankCounter++) {
		
		_chrromBankIndices[bankCounter] = bankCounter;
	}
	[self rebuildCHRROMPointers];
}

@end
