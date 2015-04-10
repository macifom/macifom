//
//  NESVRC2bCartridge.m
//  Macifom
//
//  Created by Auston Stewart on 9/23/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "NESVRC2bCartridge.h"
#import "NESPPUEmulator.h"

@implementation NESVRC2bCartridge

- (void)_switch1KBCHRROMBank:(uint_fast32_t)bank toBank:(uint_fast32_t)index
{
	uint_fast32_t bankCounter;
	uint_fast32_t selected1KBBank = (index & _chrromIndexMask) * BANK_SIZE_1KB / CHRROM_BANK_SIZE;
	
	// Rebuild CHRROM indices
	for (bankCounter = 0; bankCounter < (BANK_SIZE_1KB / CHRROM_BANK_SIZE); bankCounter++) {
		
		_chrromBankIndices[bankCounter + (bank * BANK_SIZE_1KB / CHRROM_BANK_SIZE)] = selected1KBBank + bankCounter;
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

- (void)_switchVRC2CHRROMBankWithByte:(uint8_t)byte andCPUAddress:(uint16_t)address
{
    uint8_t chrromBankToSwitch = (((address - 0xB000) >> 12) * 2) + ((address & 0x2) >> 1);
    
    if (address & 0x1) {
        
        // High nibble
        _vrc2CHRROMBankIndices[chrromBankToSwitch] = (_vrc2CHRROMBankIndices[chrromBankToSwitch] & 0xF) | ((byte & 0xF) << 4);
    }
    else {
        
        // Low nibble
        _vrc2CHRROMBankIndices[chrromBankToSwitch] = (_vrc2CHRROMBankIndices[chrromBankToSwitch] & 0xF0) | (byte & 0xF);
    }
    
    [self _switch1KBCHRROMBank:chrromBankToSwitch toBank:_vrc2CHRROMBankIndices[chrromBankToSwitch]];
}

- (void)writeByte:(uint8_t)byte toPRGROMwithCPUAddress:(uint16_t)address onCycle:(uint_fast32_t)cycle
{		
	if (address < 0x9000) {
        
        if (address < 0x8004) {
            
            // $8000-$8003:  [.... PPPP]   PRG Reg 0 (select 8k @ $8000)
            [self _switch8KBPRGROMBank:0 toBank:byte];
            [self rebuildPRGROMPointers];
        }
    }
    else if (address < 0xA000) {
        
        if (address < 0x9004) {
         
            /* $9000-$9003:  [.... ..MM]   Mirroring:
             %00 = Vert
             %01 = Horz
             %10 = 1ScA
             %11 = 1ScB
             */
            
            // Change mirroring
            switch (byte & 0x3) {
                    
                case 0:
                    [_ppu changeMirroringTypeTo:NESVerticalMirroring onCycle:cycle];
                    break;
                case 1:
                    [_ppu changeMirroringTypeTo:NESHorizontalMirroring onCycle:cycle];
                    break;
                case 2:
                    [_ppu changeMirroringTypeTo:NESSingleScreenLowerMirroring onCycle:cycle];
                    break;
                case 3:
                    [_ppu changeMirroringTypeTo:NESSingleScreenUpperMirroring onCycle:cycle];
                    break;
                default:
                    break;
            }
        }
    }
    else if (address < 0xB000) {
        
        if (address < 0xA004) {
            
            // $A000-$A003:  [.... PPPP]   PRG Reg 1 (select 8k @ $A000)
            [self _switch8KBPRGROMBank:1 toBank:byte];
            [self rebuildPRGROMPointers];
        }
    }
    else {
        
        // $B000-$E003:  [.... CCCC]   CHR Regs (see CHR Setup)
        [_ppu runPPUUntilCPUCycle:cycle];
        [self _switchVRC2CHRROMBankWithByte:byte andCPUAddress:address];
        [self rebuildCHRROMPointers];
    }
}

- (void)setInitialROMPointers
{	
	uint_fast32_t bankCounter;
	uint_fast32_t secondToLast8KBBankIndex = (_iNesFlags->prgromSize - BANK_SIZE_16KB) / PRGROM_BANK_SIZE;
	
	// Establish PRGROM pointers for the first two 8KB banks, which are swappable
	for (bankCounter = 0; bankCounter < (BANK_SIZE_16KB / PRGROM_BANK_SIZE); bankCounter++) {
		
		_prgromBankIndices[bankCounter] = bankCounter;
	}
	
	// Establish PRGROM pointers for the last two 8KB banks, which are fixed
	for (bankCounter = 0; bankCounter < (BANK_SIZE_16KB / PRGROM_BANK_SIZE); bankCounter++) {
		
		_prgromBankIndices[bankCounter + (BANK_SIZE_16KB / PRGROM_BANK_SIZE)] = secondToLast8KBBankIndex + bankCounter;
	}
	[self rebuildPRGROMPointers];
	
    // Establish Initial VRC2 CHRROM Index Registers
	for (bankCounter = 0; bankCounter < (CHRROM_APERTURE_SIZE / BANK_SIZE_1KB); bankCounter++) {
		
		_vrc2CHRROMBankIndices[bankCounter] = bankCounter;
	}
    
	// Establish CHRROM pointers
	for (bankCounter = 0; bankCounter < (CHRROM_APERTURE_SIZE / CHRROM_BANK_SIZE); bankCounter++) {
		
		_chrromBankIndices[bankCounter] = bankCounter;
	}
	[self rebuildCHRROMPointers];
        
    _prgromIndexMask = (_iNesFlags->prgromSize / BANK_SIZE_8KB) - 1;
	_chrromIndexMask = (_iNesFlags->chrromSize / BANK_SIZE_1KB) - 1;
}

@end
