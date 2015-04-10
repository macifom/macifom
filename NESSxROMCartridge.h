/*  NESSNROMCartridge.h
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
#import "NESCartridge.h"

@interface NESSxROMCartridge : NESCartridge {

	BOOL _mmc1Switch16KBPRGROMBanks;
	BOOL _mmc1SwitchFirst16KBBank;
	BOOL _mmc1Switch4KBCHRROMBanks;

	uint8_t _mmc1ControlRegister;
	uint8_t _mmc1CHRROMBank0Register;
	uint8_t _mmc1CHRROMBank1Register;
	uint8_t _mmc1PRGROMBankRegister;
	uint_fast8_t _serialWriteCounter;
	uint8_t _register;
}

- (void)_setMMC1PRGROMBankRegister:(uint8_t)byte;
- (void)_setMMC1CHRROMBank1Register:(uint8_t)byte;
- (void)_setMMC1CHRROMBank0Register:(uint8_t)byte;

@end
