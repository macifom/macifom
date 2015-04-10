//
//  NESiNES068Cartridge.h
//  Macifom
//
//  Created by Auston Stewart on 4/13/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NESCartridge.h"

@interface NESiNES068Cartridge : NESCartridge
{
    uint8_t _prgromIndexMask;
	uint8_t _chrromIndexMask;
}
@end
