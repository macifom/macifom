//
/*  NESCartridge.h
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
#import "NESCartridgeEmulator.h"

#define BANK_SIZE_256KB 262144
#define BANK_SIZE_32KB 32768
#define BANK_SIZE_16KB 16384
#define BANK_SIZE_8KB 8192
#define BANK_SIZE_4KB 4096
#define BANK_SIZE_2KB 2048
#define BANK_SIZE_1KB 1024
#define PRGROM_APERTURE_SIZE 32768
#define CHRROM_APERTURE_SIZE 8192
#define PRGROM_BANK_SIZE 8192
#define CHRROM_BANK_SIZE 1024
#define WRAM_SIZE 8192

@class NESPPUEmulator;

@interface NESCartridge : NSObject {

	uint8_t **_prgromBankPointers;
	uint8_t **_chrromBankPointers;
	uint_fast32_t *_prgromBankIndices;
	uint_fast32_t *_chrromBankIndices;
	uint8_t *_prgrom;
	uint8_t	*_chrrom;
	uint8_t *_wram;
	BOOL _usesCHRRAM;
	
	NESPPUEmulator *_ppu;
	iNESFlags *_iNesFlags;
}

- (id)initWithPrgrom:(uint8_t *)prgrom chrrom:(uint8_t *)chrrom ppu:(NESPPUEmulator *)ppu andiNesFlags:(iNESFlags *)flags;
- (uint8_t **)prgromBankPointers;
- (uint8_t **)chrromBankPointers;
- (uint_fast32_t *)chrromBankIndices;
- (void)rebuildPRGROMPointers;
- (void)rebuildCHRROMPointers;
- (uint8_t *)wram;
- (iNESFlags *)iNesFlags;
- (void)writeByte:(uint8_t)byte toWRAMwithCPUAddress:(uint16_t)address onCycle:(uint_fast32_t)cycle;
- (void)writeByte:(uint8_t)byte toPRGROMwithCPUAddress:(uint16_t)address onCycle:(uint_fast32_t)cycle;
- (void)configureInitialPPUState;
- (void)setInitialROMPointers;
- (BOOL)writeWRAMToDisk;
- (void)servicedInterruptOnCycle:(uint_fast32_t)cycle;

@end
