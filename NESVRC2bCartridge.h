//
//  NESVRC2bCartridge.h
//  Macifom
//
//  Created by Auston Stewart on 9/23/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NESCartridge.h"

@interface NESVRC2bCartridge : NESCartridge {
    
    uint8_t _prgromIndexMask;
	uint8_t _chrromIndexMask;
    uint8_t _vrc2CHRROMBankIndices[8];
}

- (void)_switch1KBCHRROMBank:(uint_fast32_t)bank toBank:(uint_fast32_t)index;

@end
