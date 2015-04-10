/* NESCartridgeEmulator.h
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
@class NESCartridge;
@class NES6502Interpreter;

typedef struct {
	
	BOOL usesVerticalMirroring;
	BOOL hasTrainer;
	BOOL usesBatteryBackedRAM;
	BOOL usesFourScreenVRAMLayout;
	BOOL isPAL;
	
	NSString *pathToFile;
	uint_fast8_t mapperNumber;
	uint_fast32_t prgromSize;
	uint_fast32_t chrromSize;
	uint_fast8_t numberOf16kbPRGROMBanks;
	uint_fast8_t numberOf8kbCHRROMBanks;
	uint_fast8_t numberOf8kbWRAMBanks;
	
} iNESFlags;

@interface NESCartridgeEmulator : NSObject {
	
	BOOL _romFileDidLoad;
	
	NSString *_lastROMPath;
	NESCartridge *_cartridge;
	NESPPUEmulator *_ppu;
	NES6502Interpreter *_cpu;
	iNESFlags *_lastHeader;
	uint8_t *_prgrom;
	uint8_t *_chrrom;
	uint8_t *_trainer;
}

- (id)initWithPPU:(NESPPUEmulator *)ppuEmulator andCPU:(NES6502Interpreter *)cpuEmulator;
- (NSError *)loadROMFileAtPath:(NSString *)path;
- (NESCartridge *)cartridge;
- (NSString *)mapperDescription;

@end
