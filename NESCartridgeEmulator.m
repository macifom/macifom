/* NESCartridgeEmulator.m
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

#import "NESCartridgeEmulator.h"
#import "NESPPUEmulator.h"
#import "NESUxROMCartridge.h"
#import "NESCNROMCartridge.h"
#import "NESAxROMCartridge.h"
#import "NESSxROMCartridge.h"
#import "NESSUROMCartridge.h"
#import "NESTxROMCartridge.h"
#import "NESVRC2bCartridge.h"
#import "NESVRC2aCartridge.h"
#import "NESVRC1Cartridge.h"
#import "NESiNES068Cartridge.h"
#import "NESiNES184Cartridge.h"

static const char *mapperDescriptions[256] = { "No mapper", "Nintendo MMC1", "UNROM switch", "CNROM switch", "Nintendo MMC3", "Nintendo MMC5", "FFE F4xxx", "AOROM switch",
												"FFE F3xxx", "Nintendo MMC2", "Nintendo MMC4", "ColorDreams", "FFE F6xxx", "CPROM switch", "Unknown Mapper", "100-in-1 switch",
												"Bandai", "FFE F8xxx", "Jaleco SS8806", "Namcot 106", "Nintendo DiskSystem", "Konami VRC4a", "Konami VRC2a", "Konami VRC2b",
												"Konami VRC6", "Konami VRC4b", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper",
												"Irem G-101", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper",
												"Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper",
												"Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper",
												"Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper",
												"Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper",
												"Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "VRC1", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper",
												"Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper",
												"Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper",
												"Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper",
												"Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper",
												"Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper",
												"Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper",
												"Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper",
												"Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper",
												"Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper",
												"Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper",
												"Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper",
												"Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper",
												"Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper",
												"Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper",
												"Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper",
												"Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper",
												"Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper",
												"Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper",
												"Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper",
												"Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper",
												"Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper",
												"Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper", "Unknown Mapper" };

@implementation NESCartridgeEmulator

- (id)initWithPPU:(NESPPUEmulator *)ppuEmulator andCPU:(NES6502Interpreter *)cpuEmulator
{
	[super init];
	
	_cartridge = nil;
	_romFileDidLoad = NO;
	_ppu = ppuEmulator;
	_cpu = cpuEmulator;
	
	return self;
}

- (void)dealloc
{
	[super dealloc];
}

- (NSError *)_createCartridgeInstance
{
	NESCartridge *previousCartridge = _cartridge;
	
	switch (_lastHeader->mapperNumber) {
			
		case 0:
			// NROM
			_cartridge = [[NESCartridge alloc] initWithPrgrom:_prgrom chrrom:_chrrom ppu:_ppu andiNesFlags:_lastHeader];
			break;
		case 1:
			// SxROM
			if (_lastHeader->numberOf16kbPRGROMBanks == 32) {
				
				// Let's try SUROM
				_cartridge = [[NESSUROMCartridge alloc] initWithPrgrom:_prgrom chrrom:_chrrom ppu:_ppu andiNesFlags:_lastHeader];
			}
			else _cartridge = [[NESSxROMCartridge alloc] initWithPrgrom:_prgrom chrrom:_chrrom ppu:_ppu andiNesFlags:_lastHeader];
			break;
		case 2:
			// UxROM
			_cartridge = [[NESUxROMCartridge alloc] initWithPrgrom:_prgrom chrrom:_chrrom ppu:_ppu andiNesFlags:_lastHeader];
			break;
		case 3:
			// CNROM
			_cartridge = [[NESCNROMCartridge alloc] initWithPrgrom:_prgrom chrrom:_chrrom ppu:_ppu andiNesFlags:_lastHeader];
			break;
		case 4:
			// TxROM
			_cartridge = [[NESTxROMCartridge alloc] initWithPrgrom:_prgrom chrrom:_chrrom ppu:_ppu cpu:_cpu andiNesFlags:_lastHeader];
			break;
		case 7:
			// AxROM
			_cartridge = [[NESAxROMCartridge alloc] initWithPrgrom:_prgrom chrrom:_chrrom ppu:_ppu andiNesFlags:_lastHeader];
			break;
        case 22:
            // VRC2a
            _cartridge = [[NESVRC2aCartridge alloc] initWithPrgrom:_prgrom chrrom:_chrrom ppu:_ppu andiNesFlags:_lastHeader];
            break;
        case 23:
            // VRC2b
            _cartridge = [[NESVRC2bCartridge alloc] initWithPrgrom:_prgrom chrrom:_chrrom ppu:_ppu andiNesFlags:_lastHeader];
            break;
        case 68:
            // iNES Mapper 068
            _cartridge = [[NESiNES068Cartridge alloc] initWithPrgrom:_prgrom chrrom:_chrrom ppu:_ppu andiNesFlags:_lastHeader];
            break;
        case 75:
            // VRC1
            _cartridge = [[NESVRC1Cartridge alloc] initWithPrgrom:_prgrom chrrom:_chrrom ppu:_ppu andiNesFlags:_lastHeader];
            break;
        case 184:
            // iNES Mapper 184 Sunsoft
            _cartridge = [[NESiNES184Cartridge alloc] initWithPrgrom:_prgrom chrrom:_chrrom ppu:_ppu andiNesFlags:_lastHeader];
            break;
		default:
			return [NSError errorWithDomain:@"NESMapperErrorDomain" code:11 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Unsupported iNES Mapper",NSLocalizedDescriptionKey,[NSString stringWithFormat:@"Macifom was unable to load the selected file as it specifies an unsupported iNES mapper: %@",[self mapperDescription]],NSLocalizedRecoverySuggestionErrorKey,nil]];
			break;
	}
	
	if (previousCartridge != nil) [previousCartridge release];
	
	return nil;
}

- (NSError *)_loadiNESROMOptions:(NSData *)header
{
	if ([header length] < 16) {
	
		return [NSError errorWithDomain:@"NESFileErrorDomain" code:4 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"iNES file is corrupt.",NSLocalizedDescriptionKey,@"Macifom was unable to parse the selected file as the iNES header is corrupt.",NSLocalizedRecoverySuggestionErrorKey,nil]];
	}
	
	uint8_t lowerOptionsByte = *((uint8_t *)[header bytes]+6);
	uint8_t higherOptionsByte = *((uint8_t *)[header bytes]+7);
	uint8_t ramBanksByte = *((uint8_t *)[header bytes]+8);
	uint8_t videoModeByte = *((uint8_t *)[header bytes]+9);
	uint8_t count, highBytesSum = 0;
	
	// Detect headers with junk in bytes 9-15 and zero out bytes 7 and higher, assuming earlier iNES format
	for (count = 10; count < 16; count++) highBytesSum += *((uint8_t *)[header bytes]+count);
	if (highBytesSum != 0) {
	
		higherOptionsByte = 0;
		ramBanksByte = 1; // Let's assume that this is in the earlier iNES format and 1kB of RAM is implied
		videoModeByte = 0;
	}
		
	_lastHeader->numberOf16kbPRGROMBanks = *((uint_fast8_t *)[header bytes]+4);
	_lastHeader->numberOf8kbCHRROMBanks = *((uint_fast8_t *)[header bytes]+5);
	_lastHeader->numberOf8kbWRAMBanks = ramBanksByte; // Fayzullin's docs say to assume 1x8kB RAM when zero to account for earlier format
	_lastHeader->usesVerticalMirroring = (lowerOptionsByte & 1) ? YES : NO;
	_lastHeader->usesBatteryBackedRAM = (lowerOptionsByte & (1 << 1)) ? YES : NO;
	_lastHeader->hasTrainer = (lowerOptionsByte & (1 << 2)) ? YES : NO;
	_lastHeader->usesFourScreenVRAMLayout = (lowerOptionsByte & (1 << 3)) ? YES : NO;
	_lastHeader->isPAL = videoModeByte ? YES : NO;
	_lastHeader->mapperNumber = ((lowerOptionsByte & 0xF0) >> 4) + (higherOptionsByte & 0xF0);
	
	return nil;
}

- (NSError *)_loadiNESFileAtPath:(NSString *)path
{
	// uint_fast8_t bank;
	NSData *rom;
	// NSData *savedSram;
	NSError *propagatedError = nil;
	NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:path];
	
	if (fileHandle == nil) {
		
		return [NSError errorWithDomain:@"NESFileErrorDomain" code:1 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"File could not be opened.",NSLocalizedDescriptionKey,@"Macifom was unable to open the file selected.",NSLocalizedRecoverySuggestionErrorKey,path,NSFilePathErrorKey,nil]];
	}
	
	NSData *header = [fileHandle readDataOfLength:16]; // Attempt to load 16 byte iNES Header
	
	// File format validation, must be iNES
	// Should check if the file is 4 chars long, need to figure out fourth char in header format
	if ((*((const char *)[header bytes]) != 'N') || (*((const char *)[header bytes]+1) != 'E') || (*((const char *)[header bytes]+2) != 'S')) {
	
		return [NSError errorWithDomain:@"NESFileErrorDomain" code:2 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"File is not in iNES format.",NSLocalizedDescriptionKey,@"Macifom was unable to parse the selected file as it does not appear to be in iNES format.",NSLocalizedRecoverySuggestionErrorKey,path,NSFilePathErrorKey,nil]];
	}
	
	// Blast existing memory
	//[self clearROMdata];
	
	// Create new header struct
	_lastHeader = (iNESFlags *)malloc(sizeof(iNESFlags));
	
	// Store path to rom
	_lastHeader->pathToFile = [[NSString alloc] initWithString:path];
	
	// Load ROM Options
	if (nil != (propagatedError = [self _loadiNESROMOptions:header])) {
	
		return propagatedError;
	}
	
	// Recent research has shown that trainers are exceedingly rare, we'll just read if present
	if (_lastHeader->hasTrainer) {
	
		if (_trainer == NULL) _trainer = (uint8_t *)malloc(sizeof(uint8_t)*512);
		NSData *trainer = [fileHandle readDataOfLength:512];
		[trainer getBytes:_trainer];
	}
	
	// Extract PRGROM Banks
	_prgrom = (uint8_t *)malloc(sizeof(uint8_t) * _lastHeader->numberOf16kbPRGROMBanks * BANK_SIZE_16KB);
	rom = [fileHandle readDataOfLength:(_lastHeader->numberOf16kbPRGROMBanks * BANK_SIZE_16KB)];
	if ([rom length] != (_lastHeader->numberOf16kbPRGROMBanks * BANK_SIZE_16KB)) {
		
		free(_prgrom);
		_prgrom = NULL;
		return [NSError errorWithDomain:@"NESFileErrorDomain" code:3 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"ROM data could not be extracted.",NSLocalizedDescriptionKey,@"Macifom was unable to extract the ROM data from the selected file. This is likely due to file corruption or inaccurate header information.",NSLocalizedRecoverySuggestionErrorKey,path,NSFilePathErrorKey,nil]];
	}
	else {
	
		_lastHeader->prgromSize = [rom length];
		[rom getBytes:_prgrom];
	}
	 
	// Extract CHRROM Banks
	if (_lastHeader->numberOf8kbCHRROMBanks) {
		
		_chrrom = (uint8_t *)malloc(sizeof(uint8_t) * _lastHeader->numberOf8kbCHRROMBanks * BANK_SIZE_8KB);
		rom = [fileHandle readDataOfLength:(_lastHeader->numberOf8kbCHRROMBanks * BANK_SIZE_8KB)];
		if ([rom length] != (_lastHeader->numberOf8kbCHRROMBanks * BANK_SIZE_8KB)) {
		
			free(_chrrom);
			_chrrom = NULL;
			return [NSError errorWithDomain:@"NESFileErrorDomain" code:3 userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"ROM data could not be extracted.",NSLocalizedDescriptionKey,@"Macifom was unable to extract the ROM data from the selected file. This is likely due to file corruption or inaccurate header information.",NSLocalizedRecoverySuggestionErrorKey,path,NSFilePathErrorKey,nil]];
		}
		else {
		
			_lastHeader->chrromSize = [rom length];
			[rom getBytes:_chrrom];
		}
	}
	else {
	
		_lastHeader->chrromSize = 0;
		_chrrom = NULL;
	}
	
	// Close ROM file
	[fileHandle closeFile];
		
	// Load appropriate cartridge class for mapper number
	propagatedError = [self _createCartridgeInstance];

	return propagatedError;
}

- (NSError *)loadROMFileAtPath:(NSString *)path
{
	NSError *propagatedError = nil;
	
	// Right now, only iNES format is supported
	_romFileDidLoad = NO;
	propagatedError = [self _loadiNESFileAtPath:path];
	if (propagatedError == nil) _romFileDidLoad = YES;
	// FIXME: else clean up partially-loaded rom junk
	
	return propagatedError;
}

- (NESCartridge *)cartridge
{
	return _cartridge;
}

- (NSString *)mapperDescription
{
	return [NSString stringWithCString:mapperDescriptions[_lastHeader->mapperNumber] encoding:NSASCIIStringEncoding];
}

@end
