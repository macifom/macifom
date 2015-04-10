/*  NESAxROMCartridge.m
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

#import "NESAxROMCartridge.h"
#import "NESPPUEmulator.h"

@implementation NESAxROMCartridge

- (void)writeByte:(uint8_t)byte toPRGROMwithCPUAddress:(uint16_t)address onCycle:(uint_fast32_t)cycle
{		
	uint_fast32_t bankCounter;
	
	// AxROM switches 32KB PRGROM banks
	uint_fast32_t selected32KprgromBank = (byte & 0x7) * BANK_SIZE_32KB / PRGROM_BANK_SIZE;
	
	// Rebuild PRGROM pointers
	for (bankCounter = 0; bankCounter < (PRGROM_APERTURE_SIZE / PRGROM_BANK_SIZE); bankCounter++) {
		
		_prgromBankIndices[bankCounter] = selected32KprgromBank + bankCounter;
	}
	[self rebuildPRGROMPointers];
	
	// AxROM also changes the single-screen mirroring mode
	if (byte & 0x10) [_ppu changeMirroringTypeTo:NESSingleScreenUpperMirroring onCycle:cycle];
	else [_ppu changeMirroringTypeTo:NESSingleScreenLowerMirroring onCycle:cycle];
}

- (void)configureInitialPPUState
{
	[super configureInitialPPUState];
	[_ppu setMirroringType:NESSingleScreenLowerMirroring];
}

@end
