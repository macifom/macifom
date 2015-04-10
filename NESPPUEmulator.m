/* NESPPUEmulator.m
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

#import "NESPPUEmulator.h"
#import "NESCartridge.h"

#define NMI_DELAY 6 // The earliest NMI can occur is two CPU cycles after it is triggered - see http://nesdev.parodius.com/bbs/viewtopic.php?t=1892
// FIXME: This delay isn't correct, per Blargg:
/* Based on recent testing, the earliest the NMI can occur is two CPU clocks after the VBL flag is set. 
   So if VBL is set on the next to last clock of an instruction, the NMI will occur after the instruction 
   finishes. If it's set earlier than that clock, the NMI will still occur after that instruction finishes. 
   If it's set later than that clock, it will occur after the next instruction finishes.
 */


static const uint_fast32_t colorPalette[64] = { 0xFF757575, 0xFF271B8F, 0xFF0000AB, 0xFF47009F, 0xFF8F0077, 0xFFAB0013, 0xFFA70000, 0xFF7F0B00,
												0xFF432F00, 0xFF004700, 0xFF005100, 0xFF003F17, 0xFF1B3F5F, 0xFF000000, 0xFF000000, 0xFF000000,
												0xFFBCBCBC, 0xFF0073EF, 0xFF233BEF, 0xFF8300F3, 0xFFBF00BF, 0xFFE7005B, 0xFFDB2B00, 0xFFCB4F0F,
												0xFF8B7300, 0xFF009700, 0xFF00AB00, 0xFF00933B, 0xFF00838B, 0xFF000000, 0xFF000000, 0xFF000000,
												0xFFFFFFFF, 0xFF3FBFFF, 0xFF5F97FF, 0xFFA78BFD, 0xFFF77BFF, 0xFFFF77B7, 0xFFFF7763, 0xFFFF9B3B,
												0xFFF3BF3F, 0xFF83D313, 0xFF4FDF4B, 0xFF58F898, 0xFF00EBDB, 0xFF000000, 0xFF000000, 0xFF000000,
												0xFFFFFFFF, 0xFFABE7FF, 0xFFC7D7FF, 0xFFD7CBFF, 0xFFFFC7FF, 0xFFFFC7DB, 0xFFFFBFB3, 0xFFFFDBAB,
												0xFFFFE7A3, 0xFFE3FFA3, 0xFFABF3BF, 0xFFB3FFCF, 0xFF9FFFF3, 0xFF000000, 0xFF000000, 0xFF000000 };

// Checked 1/3
static inline void incrementVRAMAddressHorizontally(uint16_t *vramAddress) {

	if ((*vramAddress & 0x001F) == 31) {
	
		*vramAddress &= 0xFFE0; // Clear horiztonal scroll
		*vramAddress ^= 0x0400; // Flip bit 10
	}
	
	else (*vramAddress)++;
}

// Checked 1/3
static inline void incrementVRAMAddressVertically(uint16_t *vramAddress) {
	
	unsigned int verticalTileNumber = ((*vramAddress & 0x03E0) / 32);
	
	if (((*vramAddress & 0x7000) / 4096) == 7) {
	
		if (verticalTileNumber == 29) {
		
			*vramAddress &= 0x0C1F; // Clear vertical tile index and fine vertical scroll
			*vramAddress ^= 0x0800; // Flip bit 11
		}
		else if (verticalTileNumber == 31) {
		
			// If we're beyond the normal wrapping range, just clear
			*vramAddress &= 0x0C1F; // Clear vertical tile index and fine vertical scroll
		}
		else {
		
			*vramAddress &= 0x0FFF; // Clear fine vertical scroll
			*vramAddress += 0x0020; // Move to next row of tiles
		}
	}
	else *vramAddress += 0x1000;
}

static inline uint16_t attributeTableIndexForNametableIndex(uint16_t nametableIndex) {
	
	return (nametableIndex & 0xC00) | 0x03C0 | ((nametableIndex / 16) & 0x38) | ((nametableIndex / 4) & 0x7);
}

static inline uint8_t upperColorBitsFromAttributeByte(uint8_t attributeByte, uint16_t nametableIndex) {
	
	return ((attributeByte >> ((nametableIndex & 0x2) | ((nametableIndex >> 4) & 0x4))) & 0x3) << 2;
}

static inline void backupPalettesForRendering(uint8_t *originalPalette, uint8_t *backupPalette) {

	memcpy(backupPalette,originalPalette,sizeof(uint8_t)*32);
	originalPalette[0x4] = originalPalette[0x8] = originalPalette[0xC] = originalPalette[0x10] = originalPalette[0x14] = originalPalette[0x18] = originalPalette[0x1C] = originalPalette[0x0];
}

static inline void restoreBackupPalettes(uint8_t *originalPalette, uint8_t *backupPalette) {
	
	memcpy(originalPalette,backupPalette,sizeof(uint8_t)*32);
}

static inline void generateTileCacheForCHRROMSegment(uint8_t ***tileCache, uint8_t *chrromSegment)
{
	uint_fast16_t tile;
	uint_fast8_t line;
	uint_fast8_t pixel;
	uint_fast8_t indexingPixel;
	uint8_t pixelMask;
	
	for (tile = 0; tile < (CHRROM_BANK_SIZE / 16); tile++) {
		
		for (line = 0; line < 8; line++) {
			
			for (pixel = 0; pixel < 8; pixel++) {
				
				indexingPixel = 7 - pixel;
				pixelMask = 1 << indexingPixel;
				tileCache[tile][line][pixel] = ((chrromSegment[(tile << 4) | line] & pixelMask) >> indexingPixel) | (((chrromSegment[(tile << 4) | (line + 8)] & pixelMask) >> indexingPixel) << 1);
			}
		}
	}
}

static uint16_t applyHorizontalMirroring(uint16_t vramAddress) {

	return (vramAddress & 0x03FF) | ((vramAddress & 0x0800) >> 1);
}

static uint16_t applyVerticalMirroring(uint16_t vramAddress) {
	
	return vramAddress & 0x07FF;
}

static uint16_t applySingleScreenLowerMirroring(uint16_t vramAddress) {
	
	return vramAddress & 0x03FF;
}

static uint16_t applySingleScreenUpperMirroring(uint16_t vramAddress) {
	
	return (vramAddress & 0x03FF) | 0x0400;
}

@implementation NESPPUEmulator

- (void)printAttributeTableIndices
{
	uint16_t nameTableIndex = 0;
	uint8_t entry;
	
	while (nameTableIndex < 2048) {
	
		for (entry = 0; entry < 8; entry++) printf("0x%4.4x, ",attributeTableIndexForNametableIndex(nameTableIndex++));
		printf("\n");
	}
}

- (uint8_t)_invalidPPURegisterAccessOnCycle:(uint_fast32_t)cycle
{
	NSLog(@"Invalid PPU Read Access");
	
	return 0;
}

- (void)_invalidPPURegisterWriteWithByte:(uint8_t)byte onCycle:(uint_fast32_t)cycle
{
	NSLog(@"Invalid PPU Write Access");
}

- (void)resetPPUstatus
{
	_sprite0HitCycle = 0;
	_sprite0Hit = NO;
	_triggeredNMI = NO;
	_cyclesSinceVINT = 0;
	_lastCycleOverage = 0;
	_shortenPrimingScanline = NO;
	_lastCPUCycle = 0;
	_ppuStatusRegister = 0x80;
	_ppuControlRegister1 = 0;
	_ppuControlRegister2 = 0;
	_VRAMAddress = 0;
	_temporaryVRAMAddress = 0;
	_sprRAMAddress = 0;
	_addressIncrement = 1;
	_fineHorizontalScroll = 0x0;
	_firstWriteOccurred = NO;
	_backgroundEnabled = 0;
	_spritesEnabled = 0;
	_clipSprites = YES;
	_clipBackground = YES;
	_oddFrame = NO;
	_NMIOnVBlank = NO;
	_nameAndAttributeTablesMask = 0;	
	_usingCHRRAM = NO;
	_8x16Sprites = NO;
	_frameEnded = NO;
	
	if (_stateObservingInvocation != nil) [_stateObservingInvocation release];
	_stateObservingInvocation = nil;
	
	// FIXME: I'm not sure what the default for these should actually be
	_spriteTileCacheIndex = 0;
	_backgroundTileCacheIndex = 0;
	
	memset(_playfieldBuffer,0,sizeof(uint8_t)*16);
	memset(_sprRAM,0,sizeof(uint8_t)*256);
	memset(_palettes,0,sizeof(uint8_t)*32);
	memset(_nameAndAttributeTables,0,sizeof(uint8_t)*2048);
	
	if (_tileCache != NULL) {
	
		// FIXME: Invoke method to free tile cache
		_tileCache = NULL;
	}
}

- (id)initWithBuffer:(uint_fast32_t *)buffer;
{
	[super init];
	
	_ppuDebugging = NO;
	_videoBuffer = buffer;
	_playfieldBuffer = (uint8_t *)malloc(sizeof(uint8_t)*16);
	_sprRAM = (uint8_t *)malloc(sizeof(uint8_t)*256);
	_palettes = (uint8_t *)malloc(sizeof(uint8_t)*32);
	_backgroundPalette = _palettes;
	_spritePalette = (_palettes + 0x10);
	_nameAndAttributeTables = (uint8_t *)malloc(sizeof(uint8_t)*2048);
	_tileCache = NULL;
	_observerState = (PPUState *)malloc(sizeof(PPUState));
	_stateObservingInvocation = nil;
	
	[self resetPPUstatus];
	
	_registerReadMethods = (RegisterReadMethod *)malloc(sizeof(uint8_t (*)(id, SEL, uint_fast32_t))*8);
	_registerWriteMethods = (RegisterWriteMethod *)malloc(sizeof(void (*)(id, SEL, uint8_t, uint_fast32_t))*8);
	
	// Readable Registers
	_registerReadMethods[0] = (uint8_t (*)(id, SEL, uint_fast32_t))[self methodForSelector:@selector(_invalidPPURegisterAccessOnCycle:)];
	_registerReadMethods[1] = (uint8_t (*)(id, SEL, uint_fast32_t))[self methodForSelector:@selector(_invalidPPURegisterAccessOnCycle:)];
	_registerReadMethods[2] = (uint8_t (*)(id, SEL, uint_fast32_t))[self methodForSelector:@selector(readFromPPUStatusRegisterOnCycle:)];
	_registerReadMethods[3] = (uint8_t (*)(id, SEL, uint_fast32_t))[self methodForSelector:@selector(_invalidPPURegisterAccessOnCycle:)];
	_registerReadMethods[4] = (uint8_t (*)(id, SEL, uint_fast32_t))[self methodForSelector:@selector(readFromSPRRAMIORegisterOnCycle:)];
	_registerReadMethods[5] = (uint8_t (*)(id, SEL, uint_fast32_t))[self methodForSelector:@selector(_invalidPPURegisterAccessOnCycle:)];
	_registerReadMethods[6] = (uint8_t (*)(id, SEL, uint_fast32_t))[self methodForSelector:@selector(_invalidPPURegisterAccessOnCycle:)];
	_registerReadMethods[7] = (uint8_t (*)(id, SEL, uint_fast32_t))[self methodForSelector:@selector(readFromVRAMIORegisterOnCycle:)];
	
	// Writable Registers
	_registerWriteMethods[0] = (void (*)(id, SEL, uint8_t, uint_fast32_t))[self methodForSelector:@selector(writeToPPUControlRegister1:onCycle:)];
	_registerWriteMethods[1] = (void (*)(id, SEL, uint8_t, uint_fast32_t))[self methodForSelector:@selector(writeToPPUControlRegister2:onCycle:)];
	_registerWriteMethods[2] = (void (*)(id, SEL, uint8_t, uint_fast32_t))[self methodForSelector:@selector(_invalidPPURegisterWriteWithByte:onCycle:)];
	_registerWriteMethods[3] = (void (*)(id, SEL, uint8_t, uint_fast32_t))[self methodForSelector:@selector(writeToSPRRAMAddressRegister:onCycle:)];
	_registerWriteMethods[4] = (void (*)(id, SEL, uint8_t, uint_fast32_t))[self methodForSelector:@selector(writeToSPRRAMIOControlRegister:onCycle:)];
	_registerWriteMethods[5] = (void (*)(id, SEL, uint8_t, uint_fast32_t))[self methodForSelector:@selector(writeToVRAMAddressRegister1:onCycle:)];
	_registerWriteMethods[6] = (void (*)(id, SEL, uint8_t, uint_fast32_t))[self methodForSelector:@selector(writeToVRAMAddressRegister2:onCycle:)];
	_registerWriteMethods[7] = (void (*)(id, SEL, uint8_t, uint_fast32_t))[self methodForSelector:@selector(writeToVRAMIORegister:onCycle:)];

	return self;
}

- (void)toggleDebugging:(BOOL)flag {

	_ppuDebugging = flag;
}

- (void)changeMirroringTypeTo:(NESMirroringType)type onCycle:(uint_fast32_t)cycle
{
	[self runPPUUntilCPUCycle:cycle];
	[self setMirroringType:type];
	// if (_ppuDebugging) NSLog(@"In changeMirroringType method. Switching to mirroring mode %d on PPU scanline %d cycle %d.",type,_cyclesSinceVINT / 341,_cyclesSinceVINT % 341);
}

// Checked 1/4
- (void)setMirroringType:(NESMirroringType)type
{
	// NSLog(@"In setMirroringType method.");
	
	switch (type) {
			
		case NESHorizontalMirroring:
			_nameTableMirroring = (uint16_t (*)(uint16_t))applyHorizontalMirroring;
			// NSLog(@"Setting Horizontal Mirroring Mode.");
			break;
		case NESVerticalMirroring:
			_nameTableMirroring = (uint16_t (*)(uint16_t))applyVerticalMirroring;
			// NSLog(@"Setting Vertical Mirroring Mode.");
			break;
		case NESSingleScreenLowerMirroring:
			_nameTableMirroring = (uint16_t (*)(uint16_t))applySingleScreenLowerMirroring;
			// NSLog(@"Setting Single Screen Lower Mirroring Mode.");
			break;
		case NESSingleScreenUpperMirroring:
			_nameTableMirroring = (uint16_t (*)(uint16_t))applySingleScreenUpperMirroring;
			// NSLog(@"Setting Single Screen Upper Mirroring Mode.");
			break;
		default:
			NSLog(@"Warning: Setting unknown mirroring type!");
			break;
	}
}

- (void)cacheCHRROM:(uint8_t *)chrrom length:(uint_fast32_t)size bankIndices:(uint_fast32_t *)indices isWritable:(BOOL)isWritable
{
	uint_fast32_t bankIndex, tileIndex, lineIndex;
	_tileCache = (uint8_t ****)malloc(sizeof(uint8_t***) * (size / CHRROM_BANK_SIZE));
	
	for (bankIndex = 0; bankIndex < (size / CHRROM_BANK_SIZE); bankIndex++) {
		
		// 16 bytes per 8x8 tile
		_tileCache[bankIndex] = (uint8_t ***)malloc(sizeof(uint8_t**) * (CHRROM_BANK_SIZE / 16));
		
		for (tileIndex = 0; tileIndex < (CHRROM_BANK_SIZE / 16); tileIndex++) {
			
			_tileCache[bankIndex][tileIndex] = (uint8_t **)malloc(sizeof(uint8_t *) * 8);
			
			for (lineIndex = 0; lineIndex < 8; lineIndex++) {
				
				_tileCache[bankIndex][tileIndex][lineIndex] = (uint8_t *)malloc(sizeof(uint8_t) * 8);
			}
		}
		
		generateTileCacheForCHRROMSegment(_tileCache[bankIndex],chrrom + (bankIndex * CHRROM_BANK_SIZE));
	}
	
	_chrrom = chrrom;
	_chrromBankIndices = indices;
	
	if (isWritable) {
		
		_usingCHRRAM = YES;
		_chrramWriteHistory = (BOOL *)malloc(sizeof(BOOL) * (size / CHRROM_BANK_SIZE));
		
		for (bankIndex = 0; bankIndex < (size / CHRROM_BANK_SIZE); bankIndex++) {
				
			_chrramWriteHistory[bankIndex] = NO;
		}
	}
}

- (void)_notifyStateObserver
{
	_observerState->controlRegister1 = _ppuControlRegister1;
	_observerState->controlRegister2 = _ppuControlRegister2;
	_observerState->statusRegister = _ppuStatusRegister;
	_observerState->cycle = _cyclesSinceVINT;

	[_stateObservingInvocation invoke];
}

- (void)_preloadTilesForScanline
{
	uint8_t tileIndex;
	uint_fast32_t bankIndex;
	uint8_t verticalTileOffset;
	uint8_t pixelCounter;
	uint8_t	tileAttributes;
	uint8_t tileUpperColorBits;
	uint16_t nameTableOffset;
	uint8_t tileLowerColorBits;
	
	// Fetch first tile in the scanline
	// Fetch the attribute byte
	nameTableOffset = _nameTableMirroring(_VRAMAddress);
	tileIndex = _nameAndAttributeTables[nameTableOffset];
	bankIndex = _chrromBankIndices[_backgroundTileCacheIndex + (tileIndex / (CHRROM_BANK_SIZE / 16))];
	tileIndex &= ((CHRROM_BANK_SIZE / 16) - 1);
	tileAttributes = _nameAndAttributeTables[attributeTableIndexForNametableIndex(nameTableOffset)];
	tileUpperColorBits = upperColorBitsFromAttributeByte(tileAttributes, nameTableOffset);
	verticalTileOffset = (_VRAMAddress & 0x7000) / 4096;
	
	for (pixelCounter = 0; pixelCounter < 8; pixelCounter++) {
		
		tileLowerColorBits = _tileCache[bankIndex][tileIndex][verticalTileOffset][pixelCounter];
		_playfieldBuffer[pixelCounter] = tileLowerColorBits ? (tileLowerColorBits | tileUpperColorBits) : 0;
	}
	
	// Increment the VRAM address one tile to the right
	incrementVRAMAddressHorizontally(&_VRAMAddress); 
	
	// Fetch the second tile in the scanline
	// Fetch the attribute byte
	nameTableOffset = _nameTableMirroring(_VRAMAddress);
	tileIndex = _nameAndAttributeTables[nameTableOffset];
	bankIndex = _chrromBankIndices[_backgroundTileCacheIndex + (tileIndex / (CHRROM_BANK_SIZE / 16))];
	tileIndex &= ((CHRROM_BANK_SIZE / 16) - 1);
	tileAttributes = _nameAndAttributeTables[attributeTableIndexForNametableIndex(nameTableOffset)];
	tileUpperColorBits = upperColorBitsFromAttributeByte(tileAttributes, nameTableOffset);
	
	for (pixelCounter = 0; pixelCounter < 8; pixelCounter++) {
		
		tileLowerColorBits = _tileCache[bankIndex][tileIndex][verticalTileOffset][pixelCounter];
		_playfieldBuffer[pixelCounter + 8] = tileLowerColorBits ? (tileLowerColorBits | tileUpperColorBits) : 0;
	}
	
	// Increment the VRAM address one tile to the right
	incrementVRAMAddressHorizontally(&_VRAMAddress); 	
}

- (void)_findInRangeSprites:(uint_fast8_t)scanline
{
	uint_fast32_t sprRAMIndex;
	
	_numberOfSpritesOnScanline = 0;
	
	for (sprRAMIndex = 0; sprRAMIndex < 256; sprRAMIndex += 4) {
	
		// FIXME: If it turns out that sprites on scanline 0 have Y coords of 0xFF then I'll need to add back (uint8_t) to make sure the addition overflows.
		if ((scanline >= (_sprRAM[sprRAMIndex] + 1)) && ((scanline - (_sprRAM[sprRAMIndex] + 1)) < (_8x16Sprites ? 16 : 8))) {
		
			if (_numberOfSpritesOnScanline == 8) {
				
				// Set flag on 9th in range object found
				_ppuStatusRegister |= 0x20;
				break;
			}
			_spritesOnCurrentScanline[_numberOfSpritesOnScanline++] = sprRAMIndex;
		}
	}
}

- (void)_drawScanlinesStoppingOnCycle:(uint_fast32_t)endingCycle
{
	uint_fast32_t bankIndex;
	uint_fast8_t tileIndex;
	uint_fast8_t tileCounter;
	uint_fast8_t currentScanline;
	uint_fast8_t scanlinePixelCounter;
	uint_fast8_t verticalTileOffset;
	uint_fast8_t pixelCounter;
	int spritePixelIndex;
	int spritePixelIncrement;
	int spriteCounter;
	uint_fast8_t tileAttributes;
	uint_fast8_t tileUpperColorBits;
	uint_fast8_t tileLowerColorBits;
	uint_fast16_t nameTableOffset;
	uint_fast8_t sprRAMIndex;
	uint_fast8_t spriteVerticalOffset;
	uint_fast8_t spriteHorizontalOffset;
	uint_fast32_t spriteVideoBufferOffset;
	uint_fast8_t spritePixelsToDraw;
	uint_fast8_t spriteLowerColorBits;
	uint_fast8_t spriteUpperColorBits;
	uint_fast32_t spritePriorityMask;
	uint_fast32_t bgOpacityMask;
	uint_fast32_t pixelMask;
	uint_fast32_t pixelLockArray[256];
	uint_fast8_t bgOpacityBuffer[256];
	uint_fast32_t cyclesPastPrimingScanline, scanlineStartingCycle, scanlineEndingCycle;
	
	// NSLog(@"In drawScanlines method. Drawing from %d to %d.",start,stop);
	
	// If CHRRAM writes have occurred, regenerate the pattern table tile caches prior to rendering
	if (_usingCHRRAM) {
	
		for (bankIndex = 0; bankIndex < (CHRROM_APERTURE_SIZE / CHRROM_BANK_SIZE); bankIndex++) {
			
			if (_chrramWriteHistory[bankIndex]) {
			
				generateTileCacheForCHRROMSegment(_tileCache[bankIndex],_chrrom + (_chrromBankIndices[bankIndex] * CHRROM_BANK_SIZE));
				_chrramWriteHistory[bankIndex] = NO;
			}
		}
	}
	
	// for (scanlineCounter = startingScanline; scanlineCounter < endingScanline; scanlineCounter++)
	while ((endingCycle > _cyclesSinceVINT) && (_cyclesSinceVINT < (_shortenPrimingScanline ? 89000 : 89001)))
	{
		// Determine current scanline
		cyclesPastPrimingScanline = _cyclesSinceVINT - (_shortenPrimingScanline ? CYCLES_BEFORE_RENDERING_SHORT : CYCLES_BEFORE_RENDERING_NORMAL);
		currentScanline = cyclesPastPrimingScanline / CYCLES_IN_SCANLINE_NORMAL;
		
		// Determine starting cycle for scanline (we'll only render if zero)
		scanlineStartingCycle = cyclesPastPrimingScanline % CYCLES_IN_SCANLINE_NORMAL;
			
		// Determine ending cycle for scanline (will only increment registers if greater than 255)
		scanlineEndingCycle = (_cyclesSinceVINT + (CYCLES_IN_SCANLINE_NORMAL - scanlineStartingCycle)) <= endingCycle ? CYCLES_IN_SCANLINE_NORMAL : endingCycle - _cyclesSinceVINT + scanlineStartingCycle;
			
		if (scanlineStartingCycle == 0) {
				
			// Set video buffer index
			_videoBufferIndex = currentScanline * 256;
			
			if (_backgroundEnabled) {
				
				// Initialize Scanline Pixel Counter
				scanlinePixelCounter = 0;
			
				// Get Vertical Tile Offset
				verticalTileOffset = (_VRAMAddress & 0x7000) / 4096;
		
				// Draw first two cached tiles
				// FIXME: It might be faster to do the colorPalette indexing elsewhere and then memcpy here
				for (pixelCounter = _fineHorizontalScroll; pixelCounter < 16; pixelCounter++) {
			
					// Fill first 8 pixels with black if background clipping is enabled
					if (_clipBackground && (scanlinePixelCounter < 8)) {
						
						_videoBuffer[_videoBufferIndex++] = 0;
						bgOpacityBuffer[scanlinePixelCounter++] = 0;
					}
					else {
						
						_videoBuffer[_videoBufferIndex++] = colorPalette[_backgroundPalette[_playfieldBuffer[pixelCounter]]];
						bgOpacityBuffer[scanlinePixelCounter++] = _playfieldBuffer[pixelCounter] & 0x3;
					}
				}
		
				for (tileCounter = 0; tileCounter < 30; tileCounter++) {
			
					nameTableOffset = _nameTableMirroring(_VRAMAddress);
					tileIndex = _nameAndAttributeTables[nameTableOffset];
					bankIndex = _chrromBankIndices[_backgroundTileCacheIndex + (tileIndex / (CHRROM_BANK_SIZE / 16))];
					tileIndex &= ((CHRROM_BANK_SIZE / 16) - 1);
					tileAttributes = _nameAndAttributeTables[attributeTableIndexForNametableIndex(nameTableOffset)];
					tileUpperColorBits = upperColorBitsFromAttributeByte(tileAttributes, nameTableOffset);
					// NSLog(@"Loading Tile Cache. VRAMAddress: 0x%4.4x NameTableOffset: %d TileIndex: %d VerticalTileOffset: %d",_VRAMAddress,nameTableOffset,tileIndex,verticalTileOffset);
			
					for (pixelCounter = 0; pixelCounter < 8; pixelCounter++) {
	
						tileLowerColorBits = _tileCache[bankIndex][tileIndex][verticalTileOffset][pixelCounter];
						// Profiling shows that this trinary doesn't affect performance compared to an optimized palette
						_videoBuffer[_videoBufferIndex++] = colorPalette[_backgroundPalette[tileLowerColorBits ? (tileLowerColorBits | tileUpperColorBits) : 0]];
						bgOpacityBuffer[scanlinePixelCounter++] = tileLowerColorBits;
					
						// if (_videoBufferIndex > 65535) NSLog(@"Video buffer has overrun!");
					}
			
					// Increment the VRAM address one tile to the right
					incrementVRAMAddressHorizontally(&_VRAMAddress);
				}
			
				// Draw the 33rd title if necessary
				nameTableOffset = _nameTableMirroring(_VRAMAddress);
				tileIndex = _nameAndAttributeTables[nameTableOffset];
				bankIndex = _chrromBankIndices[_backgroundTileCacheIndex + (tileIndex / (CHRROM_BANK_SIZE / 16))];
				tileIndex &= ((CHRROM_BANK_SIZE / 16) - 1);
				tileAttributes = _nameAndAttributeTables[attributeTableIndexForNametableIndex(nameTableOffset)];
				tileUpperColorBits = upperColorBitsFromAttributeByte(tileAttributes, nameTableOffset);
			
				for (pixelCounter = 0; pixelCounter < _fineHorizontalScroll; pixelCounter++) {
			
					tileLowerColorBits = _tileCache[bankIndex][tileIndex][verticalTileOffset][pixelCounter];
					_videoBuffer[_videoBufferIndex++] = colorPalette[_backgroundPalette[tileLowerColorBits ? (tileLowerColorBits | tileUpperColorBits) : 0]];
					bgOpacityBuffer[scanlinePixelCounter++] = tileLowerColorBits;
				}
				
				// Increment the VRAM address one tile to the right
				incrementVRAMAddressHorizontally(&_VRAMAddress);
			}
			else {
				
				if (_spritesEnabled) {
				
					// If background is off but sprites are on, simulate the first 31 tile fetches
					for (tileCounter = 0; tileCounter < 31; tileCounter++) incrementVRAMAddressHorizontally(&_VRAMAddress);
				}
				
				bzero(bgOpacityBuffer,sizeof(uint_fast8_t)*256);
				bzero(_videoBuffer + _videoBufferIndex,sizeof(uint_fast32_t)*256);
				_videoBufferIndex += 256;
			}
			
			if (_spritesEnabled) {
				
				// Clear the pixel locks and draw sprites
				bzero(pixelLockArray,sizeof(uint_fast32_t)*256);
			
				for (spriteCounter = 0; spriteCounter < _numberOfSpritesOnScanline; spriteCounter++) {
			
					sprRAMIndex = _spritesOnCurrentScanline[spriteCounter];
					spriteVerticalOffset = (_sprRAM[sprRAMIndex + 2] & 0x80 ? (_8x16Sprites ? 15 : 7) - (((_videoBufferIndex / 256) - 1) - (_sprRAM[sprRAMIndex] + 1)) : ((_videoBufferIndex / 256) - 1) - (_sprRAM[sprRAMIndex] + 1));
					// FIXME: If it turns out that sprites on scanline 0 have Y coords of 0xFF then I'll need to add back (uint8_t) to make sure the addition overflows.
					tileIndex = _8x16Sprites ? ((_sprRAM[sprRAMIndex + 1] & 0xFE) + (spriteVerticalOffset / 8)) : _sprRAM[sprRAMIndex + 1];
					bankIndex = _chrromBankIndices[(_8x16Sprites ? ((_sprRAM[sprRAMIndex + 1] & 0x1) ? (BANK_SIZE_4KB / CHRROM_BANK_SIZE) : 0) : _spriteTileCacheIndex) + (tileIndex / (CHRROM_BANK_SIZE / 16))];
					tileIndex &= ((CHRROM_BANK_SIZE / 16) - 1);
					spriteVerticalOffset &= 0x7;
					spriteHorizontalOffset = _sprRAM[sprRAMIndex + 3];
					spriteVideoBufferOffset = _videoBufferIndex - 256 + spriteHorizontalOffset;
					spritePixelsToDraw = spriteHorizontalOffset < 249 ? 8 : 256 - spriteHorizontalOffset;
					spriteUpperColorBits = (_sprRAM[sprRAMIndex + 2] & 0x3) * 4;
					spritePriorityMask = 0xFFFFFFFF * ((_sprRAM[sprRAMIndex + 2] & 0x20) / 32);
				
					// Check for horizontal flip
					if (_sprRAM[sprRAMIndex + 2] & 0x40) {
				
						spritePixelIncrement = -1;
						spritePixelIndex = 7;
					}
					else {
					
						spritePixelIncrement = 1;
						spritePixelIndex = 0;
					}
								
					// Draw Sprite Pixels
					for (pixelCounter = 0; pixelCounter < spritePixelsToDraw; pixelCounter++) {
					
						spriteLowerColorBits = _tileCache[bankIndex][tileIndex][spriteVerticalOffset][spritePixelIndex];
						
						if (spriteLowerColorBits && ((spriteHorizontalOffset + pixelCounter > 7) || !_clipSprites)) {
					
							// Check for sprite 0 hit
							if ((sprRAMIndex == 0) && bgOpacityBuffer[spriteHorizontalOffset + pixelCounter] && (spriteHorizontalOffset + pixelCounter != 255)) {
								
								if (!_sprite0Hit) {
									
									_sprite0Hit = YES;
									_sprite0HitCycle = spriteHorizontalOffset + pixelCounter;
									// NSLog(@"Sprite 0 hit on pixel %d of scanline %d.",spriteHorizontalOffset + pixelCounter,currentScanline);
								}
							}
							
							bgOpacityMask = (bgOpacityBuffer[spriteHorizontalOffset + pixelCounter] ? 0xFFFFFFFF : 0x00000000);
							pixelMask = (spritePriorityMask & bgOpacityMask) | pixelLockArray[spriteHorizontalOffset + pixelCounter];
							_videoBuffer[spriteVideoBufferOffset + pixelCounter] &= pixelMask;
							_videoBuffer[spriteVideoBufferOffset + pixelCounter] |= colorPalette[_spritePalette[spriteLowerColorBits | spriteUpperColorBits]] & ~pixelMask;
							pixelLockArray[spriteHorizontalOffset + pixelCounter] = 0xFFFFFFFF;
						}
					
						spritePixelIndex += spritePixelIncrement;
					}
				}
			}
		}

		if (_sprite0Hit) {
			
			if ((scanlineStartingCycle <= _sprite0HitCycle) && (scanlineEndingCycle > _sprite0HitCycle)) {
				
				_ppuStatusRegister |= 0x40;
				_sprite0Hit = NO; // Reset internal sprite 0 hit flag
			}
		}
		
		if (_backgroundEnabled || _spritesEnabled) {

			if ((scanlineStartingCycle <= 251) && (scanlineEndingCycle > 251)) {
			
				// Cycle 251, increment VRAM Address vertically
				// Increment the VRAM address vertically	
				incrementVRAMAddressVertically(&_VRAMAddress);
			
				// Simulate the 32nd tile fetch on cycle 251 following vertical increment
				incrementVRAMAddressHorizontally(&_VRAMAddress);
			}	
		
			if ((scanlineStartingCycle <= 257) && (scanlineEndingCycle > 257)) {
			
				[self _findInRangeSprites:currentScanline + 1]; // Prime in-range object cache (should be finished at this time)
				// On cycle 257, reset horizontal components of VRAM address
				_VRAMAddress &= 0xFBE0; // clear bit 10 and horizontal scroll
				_VRAMAddress |= _temporaryVRAMAddress & 0x041F; // OR in those bits from the temporary address
			}
			
			if ((scanlineStartingCycle <= 319) && (scanlineEndingCycle > 319)) {
			
				// Final two tile accesses are performed on cycles 319 and 327, repsectively
				// WAS: scanlineEndingCycle == CYCLES_IN_SCANLINE_NORMAL
				// FIXME: I'm not certain if these things should only occur if the background and sprites are enabled
				[self _preloadTilesForScanline];
			}
		}
			
		_cyclesSinceVINT += scanlineEndingCycle - scanlineStartingCycle;
	}
}

- (uint_fast32_t)cyclesSinceVINT {
	
	return _cyclesSinceVINT;
}

- (void)resetCPUCycleCounter {

	_frameEnded = NO;
	_lastCPUCycle = 0;
	_lastCycleOverage = _cyclesSinceVINT;
	// NSLog(@"PPU will start on cycle %d this frame.",_lastCycleOverage);
	[self _notifyStateObserver];
}

- (BOOL)triggeredNMI {
	
	return _triggeredNMI;
}

- (BOOL)completePrimingScanlineStoppingOnCycle:(uint_fast32_t)cycle
{	
	// NSLog(@"In completePrimingScanlineStoppingOnCycle method. Initial VRAM Address is 0x%4.4x",_VRAMAddress);
	
	uint_fast32_t scanlineStartingCycle, scanlineEndingCycle;
	scanlineStartingCycle = _cyclesSinceVINT - CYCLES_OF_VBLANK;
	scanlineEndingCycle = (cycle >= (_shortenPrimingScanline ? CYCLES_BEFORE_RENDERING_SHORT : CYCLES_BEFORE_RENDERING_NORMAL)) ? (_shortenPrimingScanline ? CYCLES_IN_SCANLINE_SHORT : CYCLES_IN_SCANLINE_NORMAL) : cycle - _cyclesSinceVINT + scanlineStartingCycle;
	
	if (_backgroundEnabled || _spritesEnabled) {
	
		// On clock 257
		if ((scanlineStartingCycle <= 257) && (scanlineEndingCycle > 257)) {

			[self _findInRangeSprites:0];
			// FIXME: Should vertical reset occur as well?
			// FIXME: Should Horizontal reset occur at all?
			// _VRAMAddress &= 0xFBE0; // clear bit 10 and horizontal scroll
			// _VRAMAddress |= _temporaryVRAMAddress & 0x041F; // OR in those bits from the temporary address
		}
		
		// On clock 304
		if ((scanlineStartingCycle <= 304) && (scanlineEndingCycle > 304)) {
	
			// NSLog(@"Copying temporary VRAM address to VRAM address: 0x%4.4x",_temporaryVRAMAddress);
			_VRAMAddress = _temporaryVRAMAddress;
		}
		
		if ((scanlineStartingCycle <= 319) && (scanlineEndingCycle > 319)) {
			
			// First two tile accesses occur on cycles 319 and 327, respectively
			[self _preloadTilesForScanline];
		}
	}
	
	_cyclesSinceVINT += scanlineEndingCycle - scanlineStartingCycle;
	
	if (_cyclesSinceVINT == (_shortenPrimingScanline ? CYCLES_BEFORE_RENDERING_SHORT : CYCLES_BEFORE_RENDERING_NORMAL)) return YES;
	
	return NO;
}

- (void)runPPU:(uint_fast32_t)cycles
{
	uint_fast32_t endingCycle = _cyclesSinceVINT + cycles;	
	// NSLog(@"In runPPUUntilCPUCycle method.");
		
	if (endingCycle < CYCLES_OF_VBLANK) {
		
		_cyclesSinceVINT = endingCycle; // Just add cycles if we're still in VBLANK
		return;
	}
	else if (_cyclesSinceVINT < (_shortenPrimingScanline ? CYCLES_BEFORE_RENDERING_SHORT : CYCLES_BEFORE_RENDERING_NORMAL)) {
	
		if (_cyclesSinceVINT < CYCLES_OF_VBLANK) {
		
			// If we're just coming out of VBLANK, clear flags and bring to current cycle
			_cyclesSinceVINT = CYCLES_OF_VBLANK;
			_ppuStatusRegister &= 0x1F; // Clear the Object Overflow, Sprite 0 Hit and VBLANK flags
		}
		
		if (![self completePrimingScanlineStoppingOnCycle:endingCycle]) return;
	}
		
	[self _drawScanlinesStoppingOnCycle:endingCycle];
	
	if (endingCycle >= (_shortenPrimingScanline ? CYCLES_IN_FRAME_SHORT : CYCLES_IN_FRAME_NORMAL)) {
							
		_cyclesSinceVINT = (_shortenPrimingScanline ? endingCycle - CYCLES_IN_FRAME_SHORT : endingCycle - CYCLES_IN_FRAME_NORMAL); // Set such that we're at the end of the frame
		_ppuStatusRegister |= 0x80; // Set VLBANK flag
		_frameEnded = YES; // Indicate frame has ended
		_triggeredNMI = _NMIOnVBlank;
		_oddFrame = !_oddFrame; // Toggle odd frame switch
		
		// if (_cyclesSinceVINT >= CYCLES_OF_VBLANK) NSLog(@"Frame ended past next VBLANK!");
	}
	else {
	
		// Add cycles if we're beyond the rendered scanlines but not at end of frame
		_cyclesSinceVINT = endingCycle;
	}
}

- (BOOL)runPPUUntilCPUCycle:(uint_fast32_t)cycle
{	
	uint_fast32_t cyclesToRun;
	
	if (cycle > _lastCPUCycle) {
		
		cyclesToRun = cycle - _lastCPUCycle;
		_lastCPUCycle = cycle;
		
		[self runPPU:cyclesToRun * 3];
	}
	
	return _frameEnded;
}

- (void)writeByte:(uint8_t)byte toPPUAddress:(uint16_t)address onCycle:(uint_fast32_t)cycle
{
	// NSLog(@"In writeBytetoPPUAddress. Writing 0x%2.2x to 0x%4.4x.",byte,address);
	
	uint16_t effectiveAddress = address & 0x3FFF;
	
	if (effectiveAddress >= 0x3F00) {
		
		// Palette write
		effectiveAddress &= 0x1F;
		if (effectiveAddress & 0x3) {
			
			_palettes[effectiveAddress] = byte & 0x3F;
		}
		else {
		
			// Writing the mirrored transparent color
			_palettes[(effectiveAddress & 0xF) | 0x10] = _palettes[effectiveAddress & 0xF] = byte & 0x3F;
		}
	}
	else if (effectiveAddress >= 0x2000) {
		
		// Name or attribute table write
		_nameAndAttributeTables[_nameTableMirroring(effectiveAddress)] = byte;
	}
	else {
	
		if (_usingCHRRAM) {
			
			_chrrom[(_chrromBankIndices[effectiveAddress / CHRROM_BANK_SIZE] * CHRROM_BANK_SIZE) + (effectiveAddress & (CHRROM_BANK_SIZE - 1))] = byte;
			_chrramWriteHistory[effectiveAddress / CHRROM_BANK_SIZE] = YES;
		}
	}
}

- (uint8_t)readByteFromCPUAddress:(uint16_t)address onCycle:(uint_fast32_t)cycle
{	
	return _registerReadMethods[address & 0x7](self,@selector(_invalidPPURegisterAccessOnCycle:),cycle);
}

- (void)writeByte:(uint8_t)byte toPPUFromCPUAddress:(uint16_t)address onCycle:(uint_fast32_t)cycle
{	
	_registerWriteMethods[address & 0x7](self,@selector(_invalidPPURegisterWriteWithByte:onCycle:),byte,cycle);
}

// 0x2000
//
- (void)writeToPPUControlRegister1:(uint8_t)byte onCycle:(uint_fast32_t)cycle
{
	[self runPPUUntilCPUCycle:cycle];
	// if (_ppuDebugging) NSLog(@"In writeToPPUControlRegister1 (0x2000) method. Writing 0x%2.2x on PPU scanline %d cycle %d.",byte,_cyclesSinceVINT / 341,_cyclesSinceVINT % 341);
	
	_ppuControlRegister1 = byte;
	_temporaryVRAMAddress &= 0x73FF; // Clear bits 10 and 11 (X and Y nametable selection)
	_temporaryVRAMAddress |= (byte & 0x3) << 10; // Put selected nametables into temporary PPU address
	_addressIncrement = (_ppuControlRegister1 & 0x4) ? 32 : 1; // Increment on write to $2007 by 32 if true
	_spriteTileCacheIndex = (_ppuControlRegister1 & 0x8) ? BANK_SIZE_4KB / CHRROM_BANK_SIZE : 0;
	_backgroundTileCacheIndex = (_ppuControlRegister1 & 0x10) ? BANK_SIZE_4KB / CHRROM_BANK_SIZE : 0;
	_8x16Sprites = (_ppuControlRegister1 & 0x20) ? YES : NO;
	_NMIOnVBlank = (_ppuControlRegister1 & 0x80) ? YES : NO;
	
	if (_stateObservingInvocation != nil) [self _notifyStateObserver];
}

// 0x2001
//
- (void)writeToPPUControlRegister2:(uint8_t)byte onCycle:(uint_fast32_t)cycle
{
	[self runPPUUntilCPUCycle:cycle];
	// if (_ppuDebugging) NSLog(@"In writeToPPUControlRegister2 (0x2001) method. Writing 0x%2.2x on PPU scanline %d cycle %d.",byte,_cyclesSinceVINT / 341,_cyclesSinceVINT % 341);
	
	_ppuControlRegister2 = byte;
	
	_monochrome = _ppuControlRegister2 & 0x1;
	_clipBackground = _ppuControlRegister2 & 0x2 ? NO : YES;
	_clipSprites = _ppuControlRegister2 & 0x4 ? NO : YES;
	_backgroundEnabled = _ppuControlRegister2 & 0x8 ? YES : NO;
	_spritesEnabled = _ppuControlRegister2 & 0x10 ? YES : NO;
	_colorIntensity = _ppuControlRegister2 & 0xE0; // Top three bits are color intensity
	
	if (_stateObservingInvocation != nil) [self _notifyStateObserver];
}

// 2005
// Checked 1/4
- (void)writeToVRAMAddressRegister1:(uint8_t)byte onCycle:(uint_fast32_t)cycle
{
	[self runPPUUntilCPUCycle:cycle];
	
	if (_firstWriteOccurred) {
	
		// the word of loopy:
		// 2005 second write:
		// t:0000001111100000=d:11111000
		// t:0111000000000000=d:00000111
		
		_temporaryVRAMAddress &= 0x7C1F;
		_temporaryVRAMAddress |= (byte & 0xF8) << 2; // OR in upper five bytes of operand as the vertical scroll
		_temporaryVRAMAddress &= 0xFFF; // Clear bits 12-14
		_temporaryVRAMAddress |= (byte & 0x7) << 12; // OR in the bits from the operand as the fine vertical scroll
		
		_firstWriteOccurred = NO; // Set toggle
		// if (_ppuDebugging) NSLog(@"In writeToVRAMAddressRegister1 (0x2005) method (second write). Writing 0x%2.2x on PPU scanline %d cycle %d.",byte,_cyclesSinceVINT / 341,_cyclesSinceVINT % 341);
	}
	else {
	
		// thus spake loopy:
		// 2005 first write:
		// t:0000000000011111=d:11111000
		// x=d:00000111
		
		_temporaryVRAMAddress &= 0x7FE0; // Clear lower five bytes
		_temporaryVRAMAddress |= (byte / 8); // OR in upper five bytes of operand as the horizontal scroll
		_fineHorizontalScroll = byte & 0x7; // Lower three bits represent the fine horizontal scroll value (0-7)
		
		_firstWriteOccurred = YES; // Reset toggle
		// if (_ppuDebugging) NSLog(@"In writeToVRAMAddressRegister1 (0x2005) method (first write). Writing 0x%2.2x on PPU scanline %d cycle %d.",byte,_cyclesSinceVINT / 341,_cyclesSinceVINT % 341);
	}
}

// 2006
// Checked 1/4
- (void)writeToVRAMAddressRegister2:(uint8_t)byte onCycle:(uint_fast32_t)cycle
{
	[self runPPUUntilCPUCycle:cycle];

	// 2006 first write:
	// t:0011111100000000=d:00111111
	// t:1100000000000000=0
	// 2006 second write:
	// t:0000000011111111=d:11111111
	// v=t
	
	if (_firstWriteOccurred) {
		
		// Second write ors in low byte
		_temporaryVRAMAddress &= 0xFF00; // Clear lower byte
		_temporaryVRAMAddress |= byte; // OR in lower byte
		_VRAMAddress = _temporaryVRAMAddress; // Copy temporary VRAM address to real VRAM address
		
		_firstWriteOccurred = NO; // Reset toggle
		// if (_ppuDebugging) NSLog(@"In writeToVRAMAddressRegister2 (0x2006) method (second write). Writing 0x%2.2x on scanline %d cycle %d.",byte,_cyclesSinceVINT / 341,_cyclesSinceVINT % 341);
	}
	else {
	
		// First write ors in high byte
		_temporaryVRAMAddress &= 0x00FF; // Clear upper byte
		_temporaryVRAMAddress |= ((byte & 0x3F) << 8); // OR in lower 6 bits as first six of upper byte
		
		_firstWriteOccurred = YES; // Set toggle
		// if (_ppuDebugging) NSLog(@"In writeToVRAMAddressRegister2 (0x2006) method (first write). Writing 0x%2.2x on scanline %d cycle %d.",byte,_cyclesSinceVINT / 341,_cyclesSinceVINT % 341);
	}
}

- (uint8_t)readFromVRAMIORegisterOnCycle:(uint_fast32_t)cycle
{
	uint8_t valueToReturn = _bufferedVRAMRead;
	uint16_t effectiveAddress = _VRAMAddress & 0x3FFF; // addresses above 0x3FFF are mirrored
	
	if (effectiveAddress < 0x2000) {
	
		_bufferedVRAMRead = _chrrom[(_chrromBankIndices[effectiveAddress / CHRROM_BANK_SIZE] * CHRROM_BANK_SIZE) + (effectiveAddress & (CHRROM_BANK_SIZE - 1))];
	}
	else if (effectiveAddress < 0x3F00) { 
		
		// Name or Attribute Table Read
		_bufferedVRAMRead = _nameAndAttributeTables[_nameTableMirroring(effectiveAddress)];
	}
	else { 
		
		// Palette Read (Unbuffered)
		_bufferedVRAMRead = _nameAndAttributeTables[_nameTableMirroring(effectiveAddress)]; // 0x3000 mirrors 0x2000
		valueToReturn = _palettes[effectiveAddress & 0x1F]; // modulo 32 as there are 32 entries
	}
	
	_VRAMAddress += _addressIncrement; // Increment VRAM address by either 1 or 32 depending on bit 2 of 0x2000
	
	// NSLog(@"In readFromVRAMIORegisterOnCycle (0x2007) method. Returning 0x%2.2x.",valueToReturn);
	
	return valueToReturn;
}

- (void)writeToVRAMIORegister:(uint8_t)byte onCycle:(uint_fast32_t)cycle
{
	// NSLog(@"In writeToVRAMIORegisteronCycle method. Writing %2.2x to %4.4x.",byte,_VRAMAddress);
	
	[self writeByte:byte toPPUAddress:_VRAMAddress onCycle:cycle];
	
	_VRAMAddress += _addressIncrement; // Increment VRAM address by either 1 or 32 depending on bit 2 of 0x2000
}

- (void)DMAtransferToSPRRAM:(uint8_t *)bytes onCycle:(uint_fast32_t)cycle
{
	// if (_ppuDebugging) NSLog(@"In DMAtransferToSPRRAM:onCycle: method on scanline %d cycle %d.",_cyclesSinceVINT / 341,_cyclesSinceVINT % 3);
	int copyIndex;
	uint8_t sprRAMIndex = _sprRAMAddress;
	
	for (copyIndex = 0; copyIndex < 256; copyIndex++) {
	
		_sprRAM[sprRAMIndex++] = bytes[copyIndex];
	}
	// FIXME: This is incrementing the SPRRAM address. I'm not entirely sure that's correct.
}

- (void)writeToSPRRAMAddressRegister:(uint8_t)byte onCycle:(uint_fast32_t)cycle
{
	// NSLog(@"In writeToSPRRAMAddressRegister:onCycle: method. Writing 0x%2.2x.",byte);
	
	_sprRAMAddress = byte;
}

- (void)writeToSPRRAMIOControlRegister:(uint8_t)byte onCycle:(uint_fast32_t)cycle
{
	// NSLog(@"In writeToSPRRAMIOControlRegister:onCycle: method. Writing 0x%2.2x.",byte);
	
	_sprRAM[_sprRAMAddress] = byte;
	
	_sprRAMAddress++; // Increment SPRRAM Address on write
}

- (uint8_t)readFromSPRRAMIORegisterOnCycle:(uint_fast32_t)cycle
{
	// NSLog(@"In readFromSPRRAMIOControlRegister:onCycle: method.");
	
	return _sprRAM[_sprRAMAddress];
}

// 0x2002
- (uint8_t)readFromPPUStatusRegisterOnCycle:(uint_fast32_t)cycle
{
	uint8_t valueToReturn;
	
	[self runPPUUntilCPUCycle:cycle];
	
	// Suppress NMI if reading on the same cycle it was tripped
	if (_cyclesSinceVINT == 0) {
		
		_triggeredNMI = NO;
		valueToReturn = _ppuStatusRegister & 0x7F;
	}
	else valueToReturn = _ppuStatusRegister;
	
	_firstWriteOccurred = NO; // Reset 0x2005 / 0x2006 read toggle
	_ppuStatusRegister &= 0x7F; // Clear the VBLANK flag

	// if (_ppuDebugging) NSLog(@"In readFromPPUStatusRegisterOnCycle: method. Returning 0x%2.2x on scanline %d cycle %d.",valueToReturn,_cyclesSinceVINT / 341,_cyclesSinceVINT % 341);
	
	return valueToReturn;
}

- (uint_fast32_t)cpuCyclesUntilPrimingScanline
{
	uint_fast32_t remainingCycles = CYCLES_OF_VBLANK - _lastCycleOverage;
	return (remainingCycles / 3) + ((remainingCycles % 3) == 0 ? 0 : 1); 
}

- (BOOL)shortenPrimingScanline
{
	// NOTE: This may be inacurrate if called before the end of VBLANK as rendering could be disabled prior to the priming scanline.
	return (_backgroundEnabled || _spritesEnabled) && _oddFrame;
}

/* cpuCyclesUntilVblank
 * NOTE: This should only be called immediately after VBLANK to ensure toggling of background and sprite rendering is accounted for!
 */
- (uint_fast32_t)cpuCyclesUntilVblank
{
	uint_fast32_t remainingCycles;
	
	_shortenPrimingScanline = (_backgroundEnabled || _spritesEnabled) && _oddFrame;
	remainingCycles = (_shortenPrimingScanline ? CYCLES_IN_FRAME_SHORT : CYCLES_IN_FRAME_NORMAL) - _lastCycleOverage + NMI_DELAY;
	
	// NSLog(@"Rendering %@, background is %@.",(_oddFrame ? @"odd frame" : @"even frame"),(_backgroundEnabled ? @"enabled" : @"disabled"));
	return (remainingCycles / 3) + ((remainingCycles % 3) == 0 ? 0 : 1); 
}

- (void)observeStateForTarget:(id)target andSelector:(SEL)selector
{
	NSMethodSignature *signature;
		
	if (_stateObservingInvocation != nil) {
		
		[_stateObservingInvocation release];
		_stateObservingInvocation = nil;
	}
	
	if (target != nil) {
		
		signature = [target methodSignatureForSelector:selector];
		_stateObservingInvocation = [[NSInvocation invocationWithMethodSignature:signature] retain];
		[_stateObservingInvocation setTarget:target];
		[_stateObservingInvocation setSelector:selector];
		[_stateObservingInvocation setArgument:&_observerState atIndex:2];
	}
}

@end
