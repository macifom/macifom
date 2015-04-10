//
//  NESiNES184Cartridge.m
//  Macifom
//
//  Created by Auston Stewart on 9/22/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "NESiNES184Cartridge.h"
#import "NESPPUEmulator.h"

@implementation NESiNES184Cartridge

- (void)_switch4KBCHRROMBank:(uint_fast32_t)bank toBank:(uint_fast32_t)index
{
	uint_fast32_t bankCounter;
	uint_fast32_t selected4KBBank = index * BANK_SIZE_4KB / CHRROM_BANK_SIZE;
	    
	// Rebuild CHRROM indices
	for (bankCounter = 0; bankCounter < (BANK_SIZE_4KB / CHRROM_BANK_SIZE); bankCounter++) {
		
		_chrromBankIndices[bankCounter + (bank * BANK_SIZE_4KB / CHRROM_BANK_SIZE)] = selected4KBBank + bankCounter;
	}
}

- (void)writeByte:(uint8_t)byte toWRAMwithCPUAddress:(uint16_t)address onCycle:(uint_fast32_t)cycle
{
    // Registers:
    // --------------------------
    // $6000-7FFF:  [.HHH .LLL]
    // H = Selects 4k CHR @ $1000
    // L = Selects 4k CHR @ $0000
    
    // Run PPU to current CPU cycle before swapping
    [_ppu runPPUUntilCPUCycle:cycle];
    
    // Swap high 4KB CHRROM bank
    [self _switch4KBCHRROMBank:1 toBank:((byte >> 4) & 0x7) & ((_iNesFlags->chrromSize / BANK_SIZE_4KB) - 1)];
    
    // Swap low 4KB CHRROM bank
    [self _switch4KBCHRROMBank:0 toBank:(byte & 0x7) & ((_iNesFlags->chrromSize / BANK_SIZE_4KB) - 1)];
    
    [self rebuildCHRROMPointers];
}

@end
