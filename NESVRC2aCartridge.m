//
//  NESVRC2aCartridge.m
//  Macifom
//
//  Created by Auston Stewart on 9/24/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "NESVRC2aCartridge.h"

@implementation NESVRC2aCartridge

- (void)_switchVRC2CHRROMBankWithByte:(uint8_t)byte andCPUAddress:(uint16_t)address
{
    uint8_t chrromBankToSwitch = (((address - 0xB000) >> 12) * 2) + (address & 0x1);
    
    if (address & 0x2) {
        
        // High nibble
        _vrc2CHRROMBankIndices[chrromBankToSwitch] = (_vrc2CHRROMBankIndices[chrromBankToSwitch] & 0xF) | ((byte & 0xF) << 4);
    }
    else {
        
        // Low nibble
        _vrc2CHRROMBankIndices[chrromBankToSwitch] = (_vrc2CHRROMBankIndices[chrromBankToSwitch] & 0xF0) | (byte & 0xF);
    }
    
    [self _switch1KBCHRROMBank:chrromBankToSwitch toBank:(_vrc2CHRROMBankIndices[chrromBankToSwitch] >> 1)];
}

@end
