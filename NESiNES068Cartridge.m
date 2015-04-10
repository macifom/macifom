//
//  NESiNES068Cartridge.m
//  Macifom
//
//  Created by Auston Stewart on 4/13/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "NESiNES068Cartridge.h"
#import "NESPPUEmulator.h"

@implementation NESiNES068Cartridge

- (void)_switch2KBCHRROMBank:(uint_fast32_t)bank toBank:(uint_fast32_t)index
{
	uint_fast32_t bankCounter;
	uint_fast32_t selected2KBBank = (index & _chrromIndexMask) * (BANK_SIZE_2KB / CHRROM_BANK_SIZE);
	
	// Rebuild CHRROM indices
	for (bankCounter = 0; bankCounter < (BANK_SIZE_2KB / CHRROM_BANK_SIZE); bankCounter++) {
		
		_chrromBankIndices[bankCounter + (bank * BANK_SIZE_2KB / CHRROM_BANK_SIZE)] = selected2KBBank + bankCounter;
	}
}

- (void)_switch16KBPRGROMBank:(uint_fast32_t)bank toBank:(uint_fast32_t)index
{
	uint_fast32_t bankCounter;
	uint_fast32_t selected16KBBank = (index & _prgromIndexMask) * (BANK_SIZE_16KB / PRGROM_BANK_SIZE);
	
	// Establish PRGROM indices
	for (bankCounter = 0; bankCounter < (BANK_SIZE_16KB / PRGROM_BANK_SIZE); bankCounter++) {
		
		_prgromBankIndices[bankCounter + (bank * BANK_SIZE_16KB / PRGROM_BANK_SIZE)] = selected16KBBank + bankCounter;
	}
}

- (void)setInitialROMPointers
{
    [super setInitialROMPointers];
    
    _prgromIndexMask = (_iNesFlags->prgromSize / BANK_SIZE_16KB) - 1;
    _chrromIndexMask = (_iNesFlags->chrromSize / BANK_SIZE_2KB) - 1;
    
    // Fix 0xC000 to the last 16KB Bank
    // [_ppu setMirroringType:NESVerticalMirroring];
    [self _switch16KBPRGROMBank:1 toBank:_prgromIndexMask];
	[self rebuildPRGROMPointers];
}

- (void)writeByte:(uint8_t)byte toPRGROMwithCPUAddress:(uint16_t)address onCycle:(uint_fast32_t)cycle
{
    // Registers:
    // --------------------------
    // Range,Mask:   $8000-FFFF, $F000
    // 
    // $8000:  CHR Reg 0  (2k @ $0000)
    // $9000:  CHR Reg 1  (2k @ $0800)
    // $A000:  CHR Reg 2  (2k @ $1000)
    // $B000:  CHR Reg 3  (2k @ $1800)
    // 
    // $C000:  [.NNN NNNN]  NT-ROM Reg 0
    // $D000:  [.NNN NNNN]  NT-ROM Reg 1
    // $E000:  [...R ...M]  Mirroring (see section below)
    // 
    // $F000:  PRG Reg (16k @ $8000)
    address &= 0xF000;
    
    if (address < 0xC000) {
        
        // Run PPU to current CPU cycle before swapping
        [_ppu runPPUUntilCPUCycle:cycle];
        
        if (address == 0x8000) {
        
            [self _switch2KBCHRROMBank:0 toBank:byte];
        }
        else if (address == 0x9000) {
        
            [self _switch2KBCHRROMBank:1 toBank:byte];
        }
        else if (address == 0xA000) {
        
            [self _switch2KBCHRROMBank:2 toBank:byte];
        }
        else {
        
            [self _switch2KBCHRROMBank:3 toBank:byte];
        }
        [self rebuildCHRROMPointers];
    }
    else if (address == 0xC000) {
        
        NSLog(@"Mapper 68 Cartridge Attempted to switch NT-ROM register 0!");
    }
    else if (address == 0xD000) {
        
        NSLog(@"Mapper 68 Cartridge Attempted to switch NT-ROM register 1!");
    }
    else if (address == 0xE000) {
        
        // Run PPU to current CPU cycle before swapping
        [_ppu runPPUUntilCPUCycle:cycle];
        
        if (byte & 0x10) {
            
            NSLog(@"Mapper 68 Cartridge Attempted to enable built-in NT-ROM!");
        }
        
        switch (byte & 0x3) {
            
            case 0:
                [_ppu setMirroringType:NESVerticalMirroring];
                break;
            case 1:
                [_ppu setMirroringType:NESHorizontalMirroring];
                break;
            case 2:
                [_ppu setMirroringType:NESSingleScreenLowerMirroring];
                break;
            case 3:
                [_ppu setMirroringType:NESSingleScreenUpperMirroring];
                break;
        }
    }
    else {
     
        [self _switch16KBPRGROMBank:0 toBank:byte];
        [self rebuildPRGROMPointers];
    }
}


@end
