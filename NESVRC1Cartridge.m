//
//  NESVRC1Cartridge.m
//  Macifom
//
//  Created by Auston Stewart on 9/25/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "NESVRC1Cartridge.h"
#import "NESPPUEmulator.h"

@implementation NESVRC1Cartridge

- (void)_switch4KBCHRROMBank:(uint_fast32_t)bank toBank:(uint_fast32_t)index
{
	uint_fast32_t bankCounter;
	uint_fast32_t selected4KBBank = (index & _chrromIndexMask) * BANK_SIZE_4KB / CHRROM_BANK_SIZE;
	
	// Rebuild CHRROM indices
	for (bankCounter = 0; bankCounter < (BANK_SIZE_4KB / CHRROM_BANK_SIZE); bankCounter++) {
		
		_chrromBankIndices[bankCounter + (bank * BANK_SIZE_4KB / CHRROM_BANK_SIZE)] = selected4KBBank + bankCounter;
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

- (void)writeByte:(uint8_t)byte toPRGROMwithCPUAddress:(uint16_t)address onCycle:(uint_fast32_t)cycle
{		
	if (address < 0x9000) {
        
        if (address < 0x8004) {
            
            // $8000:  [.... PPPP]   PRG Reg 0 (8k @ $8000)
            [self _switch8KBPRGROMBank:0 toBank:byte & 0xF];
            [self rebuildPRGROMPointers];
        }
    }
    else if (address < 0xA000) {
        
        /*
         $9000:  [.... .BAM]   Mirroring, CHR reg high bits
         M = Mirroring (0=Vert, 1=Horz)
         A = High bit of CHR Reg 0
         B = High bit of CHR Reg 1
         */
            
        // Change mirroring
        if (byte & 0x1) [_ppu changeMirroringTypeTo:NESHorizontalMirroring onCycle:cycle];
        else [_ppu changeMirroringTypeTo:NESVerticalMirroring onCycle:cycle];
    
        _vrc1CHRROMRegister0 = (_vrc1CHRROMRegister0 & 0xF) | ((byte & 0x2) << 3);
        _vrc1CHRROMRegister1 = (_vrc1CHRROMRegister1 & 0xF) | ((byte & 0x4) << 2);
        
        [self _switch4KBCHRROMBank:0 toBank:_vrc1CHRROMRegister0];
        [self _switch4KBCHRROMBank:1 toBank:_vrc1CHRROMRegister1];
        [self rebuildCHRROMPointers];
    }
    else if (address < 0xB000) {
        
        // $A000:  [.... PPPP]   PRG Reg 1 (8k @ $A000)
        [self _switch8KBPRGROMBank:1 toBank:byte & 0xF];
        [self rebuildPRGROMPointers];
    }
    else if ((address < 0xD000) && (address >= 0xC000)) {
        
        // $C000:  [.... PPPP]   PRG Reg 2 (8k @ $C000)
        [self _switch8KBPRGROMBank:2 toBank:byte & 0xF];
        [self rebuildPRGROMPointers];
    }
    else if ((address < 0xF000) && (address >= 0xE000)) {
        
        // $E000:  [.... CCCC]   Low 4 bits of CHR Reg 0 (4k @ $0000)
        _vrc1CHRROMRegister0 = (_vrc1CHRROMRegister0 & 0x10) | (byte & 0xF);
        [self _switch4KBCHRROMBank:0 toBank:_vrc1CHRROMRegister0];
        [self rebuildCHRROMPointers];
    }    
    else {
        
        // $F000:  [.... CCCC]   Low 4 bits of CHR Reg 1 (4k @ $1000)
        _vrc1CHRROMRegister1 = (_vrc1CHRROMRegister1 & 0x10) | (byte & 0xF);
        [self _switch4KBCHRROMBank:1 toBank:_vrc1CHRROMRegister1];
        [self rebuildCHRROMPointers];
    }
}

- (void)setInitialROMPointers
{	
	uint_fast32_t bankCounter;
	uint_fast32_t last8KBBankIndex = (_iNesFlags->prgromSize - BANK_SIZE_8KB) / PRGROM_BANK_SIZE;
	
	// Establish PRGROM pointers for the first three 8KB banks, which are swappable
	for (bankCounter = 0; bankCounter < (BANK_SIZE_8KB / PRGROM_BANK_SIZE); bankCounter++) {
		
		_prgromBankIndices[bankCounter] = bankCounter;
	}
	
	// Establish PRGROM pointers for the last 8KB bank, which is fixed
	for (bankCounter = 0; bankCounter < (BANK_SIZE_8KB / PRGROM_BANK_SIZE); bankCounter++) {
		
		_prgromBankIndices[bankCounter + ((BANK_SIZE_16KB + BANK_SIZE_8KB) / PRGROM_BANK_SIZE)] = last8KBBankIndex + bankCounter;
	}
	[self rebuildPRGROMPointers];
	
    // Establish Initial VRC1 CHRROM Index Registers
	_vrc1CHRROMRegister0 = 0;
    _vrc1CHRROMRegister1 = 0;
    
	// Establish CHRROM pointers
	for (bankCounter = 0; bankCounter < (BANK_SIZE_4KB / CHRROM_BANK_SIZE); bankCounter++) {
		
		_chrromBankIndices[bankCounter] = bankCounter;
	}
    for (bankCounter = 0; bankCounter < (BANK_SIZE_4KB / CHRROM_BANK_SIZE); bankCounter++) {
		
		_chrromBankIndices[bankCounter + (BANK_SIZE_4KB / CHRROM_BANK_SIZE)] = bankCounter;
	}
	[self rebuildCHRROMPointers];
    
    _prgromIndexMask = (_iNesFlags->prgromSize / BANK_SIZE_8KB) - 1;
	_chrromIndexMask = (_iNesFlags->chrromSize / BANK_SIZE_4KB) - 1;
}

@end
