//
//  NESVRC1Cartridge.h
//  Macifom
//
//  Created by Auston Stewart on 9/25/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NESCartridge.h"

@interface NESVRC1Cartridge : NESCartridge {
    
    uint8_t _prgromIndexMask;
	uint8_t _chrromIndexMask;
    uint8_t _vrc1CHRROMRegister0;
    uint8_t _vrc1CHRROMRegister1;
}

@end
