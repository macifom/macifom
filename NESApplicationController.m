/* NESApplicationController.m
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

#import "NESApplicationController.h"
#import "NESPlayfieldView.h"
#import "NESAPUEmulator.h"
#import "NESPPUEmulator.h"
#import "NESCartridgeEmulator.h"
#import "NES6502Interpreter.h"
#import "NESControllerInterface.h"
#import "NESCartridge.h"

static const char *instructionNames[256] = { "BRK", "ORA", "$02", "$03", "$04", "ORA", "ASL", "$07",
"PHP", "ORA", "ASL", "$0B", "$0C", "ORA", "ASL", "$0F",
"BPL", "ORA", "$12", "$13", "$14", "ORA", "ASL", "$17",
"CLC", "ORA", "$1A", "$1B", "$1C", "ORA", "ASL", "$1F",
"JSR", "AND", "$22", "$23", "BIT", "AND", "ROL", "$27",
"PLP", "AND", "ROL", "$2B", "BIT", "AND", "ROL", "$2F",
"BMI", "AND", "$32", "$33", "$34", "AND", "ROL", "$37",
"SEC", "AND", "$3A", "$3B", "$3C", "AND", "ROL", "$3F",
"RTI", "EOR", "$42", "$43", "ADC", "EOR", "LSR", "$47",
"PHA", "EOR", "LSR", "$4B", "JMP", "EOR", "LSR", "$4F",
"BVC", "EOR", "$52", "$53", "$54", "EOR", "LSR", "$57",
"CLI", "EOR", "$5A", "$5B", "$5C", "EOR", "LSR", "$5F",
"RTS", "ADC", "$62", "$63", "$64", "ADC", "ROR", "$67",
"PLA", "ADC", "ROR", "$6B", "JMP", "ADC", "ROR", "$6F",
"BVS", "ADC", "$72", "$73", "$74", "ADC", "ROR", "$77",
"SEI", "ADC", "$7A", "$7B", "$7C", "ADC", "ROR", "$7F",
"$80", "STA", "$82", "$83", "STY", "STA", "STX", "$87",
"DEY", "$89", "TXA", "$8B", "STY", "STA", "STX", "$8F",
"BCC", "STA", "$92", "$93", "STY", "STA", "STX", "$97",
"TYA", "STA", "TXS", "$9B", "$9C", "STA", "$9E", "$9F",
"LDY", "LDA", "LDX", "$A3", "LDY", "LDA", "LDX", "$A7",
"TAY", "LDA", "TAX", "$AB", "LDY", "LDA", "LDX", "$AF",
"BCS", "LDA", "$B2", "$B3", "LDY", "LDA", "LDX", "$B7",
"CLV", "LDA", "TSX", "$BB", "LDY", "LDA", "LDX", "$BF",
"CPY", "CMP", "$C2", "$C3", "CPY", "CMP", "DEC", "$C7",
"INY", "CMP", "DEX", "$CB", "CPY", "CMP", "DEC", "$CF",
"BNE", "CMP", "$D2", "$D3", "$D4", "CMP", "DEC", "$D7",
"CLD", "CMP", "$DA", "$DB", "$DC", "CMP", "DEC", "$DF",
"CPX", "SBC", "$E2", "$E3", "CPX", "SBC", "INC", "$E7",
"INX", "SBC", "NOP", "$EB", "CPX", "SBC", "INC", "$EF",
"BEQ", "SBC", "$F2", "$F3", "$F4", "SBC", "INC", "$F7",
"SED", "SBC", "$FA", "$FB", "$FC", "SBC", "INC", "$FF" };

static const uint8_t instructionArguments[256] = { 0, 1, 0, 0, 0, 1, 1, 0, 
0, 1, 0, 0, 0, 2, 2, 0,
1, 1, 0, 0, 0, 1, 1, 0,
0, 2, 0, 0, 0, 2, 2, 0,
2, 1, 0, 0, 1, 1, 1, 0, 
0, 1, 0, 0, 2, 2, 2, 0,
1, 1, 0, 0, 0, 1, 1, 0,
0, 2, 0, 0, 0, 2, 2, 0,
0, 1, 0, 0, 1, 1, 1, 0,
0, 1, 0, 0, 2, 2, 2, 0,
1, 1, 0, 0, 0, 1, 1, 0,
0, 2, 0, 0, 0, 2, 2, 0,
0, 1, 0, 0, 0, 1, 1, 0,
0, 1, 0, 0, 2, 2, 2, 0,
1, 1, 0, 0, 0, 1, 1, 0,
0, 2, 0, 0, 0, 2, 2, 0,
0, 1, 0, 0, 1, 1, 1, 0,
0, 0, 0, 0, 2, 2, 2, 0,
1, 1, 0, 0, 1, 1, 1, 0,
0, 2, 0, 0, 0, 2, 0, 0,
1, 1, 1, 0, 1, 1, 1, 0,
0, 1, 0, 0, 2, 2, 2, 0,
1, 1, 0, 0, 1, 1, 1, 0,
0, 2, 0, 0, 2, 2, 2, 0,
1, 1, 0, 0, 1, 1, 1, 0,
0, 1, 0, 0, 2, 2, 2, 0,
1, 1, 0, 0, 0, 1, 1, 0,
0, 2, 0, 0, 0, 2, 2, 0,
1, 1, 0, 0, 1, 1, 1, 0,
0, 1, 0, 0, 2, 2, 2, 0,
1, 1, 0, 0, 0, 1, 1, 0,
0, 2, 0, 0, 0, 2, 2, 0 };

static const char *instructionDescriptions[256] = { "Break (Implied)", "ORA Indirect,X", "Invalid Opcode $02", "Invalid Opcode $03", "Invalid Opcode $04", "ORA Zero Page", "ASL Zero Page", "Invalid Opcode $07",
"Push Processor Status", "ORA Immediate", "ASL Accumulator (Implied)", "Invalid Opcode $0B", "Invalid Opcode $0C", "ORA Absolute", "ASL Absolute", "Invalid Opcode $0F",
"Branch on Positive", "ORA Indirect,Y", "Invalid Opcode $12", "Invalid Opcode $13", "Invalid Opcode $14", "ORA Zero Page,X", "ASL Zero Page,X", "Invalid Opcode $17",
"Clear Carry", "ORA Absolute,Y", "Invalid Opcode $1A", "Invalid Opcode $1B", "Invalid Opcode $1C", "ORA Absolute,X", "ASL Absolute,X", "Invalid Opcode $1F",
"Jump to Subroutine", "AND Indirect,X", "Invalid Opcode $22", "Invalid Opcode $23", "BIT Zero Page", "AND Zero Page", "ROL Zero Page", "Invalid Opcode $27",
"Pull Processor Status", "AND Immediate", "ROL Accumulator", "Invalid Opcode $2B", "BIT Absolute", "AND Absolute", "ROL Absolute", "Invalid Opcode $2F",
"Branch on Negative", "AND Indirect,Y", "Invalid Opcode $32", "Invalid Opcode $33", "Invalid Opcode $34", "AND Zero Page,X", "ROL Zero Page,X", "Invalid Opcode $37",
"Set Carry", "AND Absolute,Y", "Invalid Opcode $3A", "Invalid Opcode $3B", "Invalid Opcode $3C", "AND Absolute,X", "ROL Absolute,X", "Invalid Opcode $3F",
"Return from Interrupt", "EOR Indirect,X", "Invalid Opcode $42", "Invalid Opcode $43", "ADC Immediate", "EOR Zero Page", "LSR Zero Page", "Invalid Opcode $47",
"Push Accumulator", "EOR Immediate", "LSR Accumulator", "Invalid Opcode $4B", "Jump Absolute", "EOR Absolute", "LSR Absolute", "Invalid Opcode $4F",
"Branch on Overflow Clear", "EOR Indirect,Y", "Invalid Opcode $52", "Invalid Opcode $53", "Invalid Opcode $54", "EOR Zero Page,X", "LSR Zero Page,X", "Invalid Opcode $57",
"Clear Interrupt", "EOR Absolute,Y", "Invalid Opcode $5A", "Invalid Opcode $5B", "Invalid Opcode $5C", "EOR Absolute,X", "LSR Absolute,X", "Invalid Opcode $5F",
"Return from Subroutine", "ADC Indirect,X", "Invalid Opcode $62", "Invalid Opcode $63", "Invalid Opcode $64", "ADC Zero Page", "ROR Zero Page", "Invalid Opcode $67",
"Pull Accumulator", "ADC Immediate", "ROR Accumulator", "Invalid Opcode $6B", "Jump Indirect", "ADC Absolute", "ROR Absolute", "Invalid Opcode $6F",
"Branch on Overflow Set", "ADC Indirect,Y", "Invalid Opcode $72", "Invalid Opcode $73", "Invalid Opcode $74", "ADC Zero Page,X", "ROR Zero Page,X", "Invalid Opcode $77",
"Set Interrupt", "ADC Absolute,Y", "Invalid Opcode $7A", "Invalid Opcode $7B", "Invalid Opcode $7C", "ADC Absolute,X", "ROR Absolute,X", "Invalid Opcode $7F",
"Invalid Opcode $80", "STA Indirect,X", "Invalid Opcode $82", "Invalid Opcode $83", "STY Zero Page", "STA Zero Page", "STX Zero Page", "Invalid Opcode $87",
"Decrement Y", "Invalid Opcode $89", "Transfer X to Accumulator", "Invalid Opcode $8B", "STY Absolute", "STA Absolute", "STX Absolute", "Invalid Opcode $8F",
"Branch on Carry Clear", "STA Indirect,Y", "Invalid Opcode $92", "Invalid Opcode $93", "STY Zero Page,X", "STA Zero Page,X", "STX Zero Page,Y", "Invalid Opcode $97",
"Transfer Y to Accumulator", "STA Absolute,Y", "Transfer X to Stack Pointer", "Invalid Opcode $9B", "Invalid Opcode $9C", "STA Absolute,X", "Invalid Opcode $9E", "Invalid Opcode $9F",
"LDY Immediate", "LDA Indirect,X", "LDX Immediate", "Invalid Opcode $A3", "LDY Zero Page", "LDA Zero Page", "LDX Zero Page", "Invalid Opcode $A7",
"Transfer Accumulator to Y", "LDA Immediate", "Transfer Accumulator to X", "Invalid Opcode $AB", "LDY Absolute", "LDA Absolute", "LDX Absolute", "Invalid Opcode $AF",
"Branch on Carry Set", "LDA Indirect,Y", "Invalid Opcode $B2", "Invalid Opcode $B3", "LDY Zero Page,X", "LDA Zero Page,X", "LDX Zero Page,Y", "Invalid Opcode $B7",
"Clear Overflow", "LDA Absolute,Y", "Transfer Stack Pointer to X", "Invalid Opcode $BB", "LDY Absolute,X", "LDA Absolute,X", "LDX Absolute,Y", "Invalid Opcode $BF",
"CPY Immediate", "CMP Indirect,X", "Invalid Opcode $C2", "Invalid Opcode $C3", "CPY Zero Page", "CMP Zero Page", "DEC Zero Page", "Invalid Opcode $C7",
"Increment Y", "CMP Immediate", "Decrement X", "Invalid Opcode $CB", "CPY Absolute", "CMP Absolute", "DEC Absolute", "Invalid Opcode $CF",
"Branch on Not Equal", "CMP Indirect,Y", "Invalid Opcode $D2", "Invalid Opcode $D3", "Invalid Opcode $D4", "CMP Zero Page,X", "DEC Zero Page,X", "Invalid Opcode $D7",
"Clear Decimal", "CMP Absolute,Y", "Invalid Opcode $DA", "Invalid Opcode $DB", "Invalid Opcode $DC", "CMP Absolute,X", "DEC Absolute,X", "Invalid Opcode $DF",
"CPX Immediate", "SBC Indirect,X", "Invalid Opcode $E2", "Invalid Opcode $E3", "CPX Zero Page", "SBC Zero Page", "INC Zero Page", "Invalid Opcode $E7",
"Increment X", "SBC Immediate", "NOP", "Invalid Opcode $EB", "CPX Absolute", "SBC Absolute", "INC Absolute", "Invalid Opcode $EF",
"Branch on Equal", "SBC Indirect,Y", "Invalid Opcode $F2", "Invalid Opcode $F3", "Invalid Opcode $F4", "SBC Zero Page,X", "INC Zero Page,X", "Invalid Opcode $F7",
"Set Decimal", "SBC Absolute,Y", "Invalid Opcode $FA", "Invalid Opcode $FB", "Invalid Opcode $FC", "SBC Absolute,X", "INC Absolute,X", "Invalid Opcode $FF" };

@implementation NESApplicationController

- (id)init
{
    if (self == [super init]) {
        
        _currentInstruction = nil;
        instructions = nil;
        romFilePath = nil;
        debuggerIsVisible = NO;
        gameIsLoaded = NO;
        gameIsRunning = NO;
        playOnActivate = NO;
        applicationHasLaunched = NO;
        lastTimingCorrection = 0;
    }
    
    return self;
}

- (void)dealloc
{
    if (_fullScreenMode != NULL) CGDisplayModeRelease(_fullScreenMode);
    if (_windowedMode != NULL) CGDisplayModeRelease(_windowedMode);
	[cpuInterpreter release];
	[apuEmulator release];
	[ppuEmulator release];
	[cartEmulator release];
	[cpuRegisters release];
	[instructions release];
    [romFilePath release];
	
	[super dealloc];
}

- (CGDisplayModeRef)findBestFullscreenDisplayModeForDisplay:(CGDirectDisplayID)display
{
    CGDisplayModeRef displayMode;
    CGDisplayModeRef bestDisplayMode = NULL;
    CFStringRef pixelEncoding;
    CFIndex displayModeIndex;
    CFArrayRef displayModes = CGDisplayCopyAllDisplayModes(display,NULL);
    
    for (displayModeIndex = 0; displayModeIndex < CFArrayGetCount(displayModes); displayModeIndex++) {
        
        displayMode = (CGDisplayModeRef)CFArrayGetValueAtIndex(displayModes, displayModeIndex);
        
        // Verify that minimum horizontal resolution is met (let's say 512)
        if (CGDisplayModeGetWidth(displayMode) < 512) continue;
        
        // Verify that minimum vertical resolution is met (let's say 480)
        if (CGDisplayModeGetHeight(displayMode) < 480) continue;
        
        // Verify that the minimum refresh rate is met (0 - LCD, 60 - CRT)
        if ((CGDisplayModeGetRefreshRate(displayMode) != 0) && (CGDisplayModeGetRefreshRate(displayMode) < 60.f)) continue;
        
        // Verify that color depth is correct
        pixelEncoding = CGDisplayModeCopyPixelEncoding(displayMode);
        if (![[NSString stringWithCString:IO32BitDirectPixels encoding:NSUTF8StringEncoding] isEqualToString:(NSString *)pixelEncoding]) continue;
        CFRelease(pixelEncoding);
        
        if (bestDisplayMode == NULL) {
            
            CFRetain(displayMode);
            bestDisplayMode = displayMode;
        }
        else {
            
            if (CGDisplayModeGetHeight(displayMode) < CGDisplayModeGetHeight(bestDisplayMode)) {
                
                // We have a new champion
                CFRetain(displayMode);
                CFRelease(bestDisplayMode);
                bestDisplayMode = displayMode;
            }
        }
    }
    
    CFRelease(displayModes);
    
    return bestDisplayMode;
}

- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename
{
    if (applicationHasLaunched) {
        
        if (gameIsRunning) [self play:nil]; // Pause game when opening rom selector
        if (gameIsLoaded) [[cartEmulator cartridge] writeWRAMToDisk]; // This is a decent time to save!
        if ([playfieldView isInFullScreenMode]) [self toggleFullScreenMode:nil]; // Come out of full-screen mode
        
        return [self loadROMAtPath:filename];
    }
    else {
        
        [filename retain];
        romFilePath = filename;
    }
    
    return YES;
}

- (void)application:(NSApplication *)sender openFiles:(NSArray *)filenames
{
    [self application:sender openFile:[filenames objectAtIndex:0]];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
	
    ppuEmulator = [[NESPPUEmulator alloc] initWithBuffer:[playfieldView videoBuffer]];
    apuEmulator = [[NESAPUEmulator alloc] init];
    cpuInterpreter = [[NES6502Interpreter alloc] initWithPPU:ppuEmulator andAPU:apuEmulator];
    cartEmulator = [[NESCartridgeEmulator alloc] initWithPPU:ppuEmulator andCPU:cpuInterpreter];
    [apuEmulator setDMCReadObject:cpuInterpreter];
    
	_fullScreenMode = [self findBestFullscreenDisplayModeForDisplay:kCGDirectMainDisplay];
    _windowedMode = CGDisplayCopyDisplayMode(kCGDirectMainDisplay);
    
    if (_fullScreenMode) {
        
        NSLog(@"Fullscreen mode will be: %lux%lu, %.0fHz, 32bpp",CGDisplayModeGetWidth(_fullScreenMode),CGDisplayModeGetHeight(_fullScreenMode),CGDisplayModeGetRefreshRate(_fullScreenMode));
    }
    
    if (romFilePath) {
        
        // Application was launched by double-clicking a ROM file
        [self loadROMAtPath:romFilePath];
    }
    
    applicationHasLaunched = YES;
}

- (BOOL)loadROMAtPath:(NSString *)path
{
    NSError *propagatedError;
	NSAlert *errorDialog;
	
    if (nil == (propagatedError = [cartEmulator loadROMFileAtPath:path])) {
		
        NESCartridge *cartridge = [cartEmulator cartridge];
        iNESFlags *cartridgeData = [cartridge iNesFlags];
        
        // Friendly Cartridge Info
        NSLog(@"Cartridge Information:");
        NSLog(@"Mapper #: %d\t\tDescription: %@",cartridgeData->mapperNumber,[cartEmulator mapperDescription]);
        NSLog(@"Trainer: %@\t\tVideo Type: %@",(cartridgeData->hasTrainer ? @"Yes" : @"No"),(cartridgeData->isPAL ? @"PAL" : @"NTSC"));
        NSLog(@"Mirroring: %@\tBackup RAM: %@",(cartridgeData->usesVerticalMirroring ? @"Vertical" : @"Horizontal"),(cartridgeData->usesBatteryBackedRAM ? @"Yes" : @"No"));
        NSLog(@"Four-Screen VRAM Layout: %@",(cartridgeData->usesFourScreenVRAMLayout ? @"Yes" : @"No"));
        NSLog(@"PRG-ROM Banks: %d x 16kB\tCHR-ROM Banks: %d x 8kB",cartridgeData->numberOf16kbPRGROMBanks,cartridgeData->numberOf8kbCHRROMBanks);
        NSLog(@"Onboard RAM Banks: %d x 8kB",cartridgeData->numberOf8kbWRAMBanks);
        
        if (gameIsLoaded) [apuEmulator stopAPUPlayback]; // Terminate audio playback
        
        // Reset the PPU
        [ppuEmulator resetPPUstatus];
        
        // Set initial ROM pointers
        [cartridge setInitialROMPointers];
        
        // Configure initial PPU state
        [cartridge configureInitialPPUState];
        
        // Allow CPU Interpreter to cache PRGROM pointers
        [cpuInterpreter setCartridge:cartridge];
        
        // Reset the CPU to prepare for execution
        [cpuInterpreter reset];
        
        // Flip the bool to indicate that the game is loaded
        [self setGameIsLoaded:YES];
        
        // Flip on audio
        [apuEmulator beginAPUPlayback];
        
        // Start the game
        [self play:nil];
    }
    else {
        
        // Throw an error
        errorDialog = [NSAlert alertWithError:propagatedError];
        [errorDialog runModal];
        return NO;
    }
    
    return YES;
}

- (IBAction)loadROM:(id)sender
{
    NSOpenPanel *openPanel;
	
	if (gameIsRunning) [self play:nil]; // Pause game when opening rom selector
	if (gameIsLoaded) [[cartEmulator cartridge] writeWRAMToDisk]; // This is a decent time to save!
	if ([playfieldView isInFullScreenMode]) [self toggleFullScreenMode:nil]; // Come out of full-screen mode
    
	openPanel = [NSOpenPanel openPanel];
	[openPanel setCanChooseFiles:YES];
	[openPanel setCanChooseDirectories:NO];
	[openPanel setAllowsMultipleSelection:NO];
	[openPanel setAllowedFileTypes:[NSArray arrayWithObjects:@"nes",@"NES",nil]]; 
	[openPanel setAllowsOtherFileTypes:NO];
	
	if (NSOKButton == [openPanel runModal]) {
						
        [self loadROMAtPath:(NSString *)[[openPanel filenames] objectAtIndex:0]];
	}
}

- (void)_nextFrame {
	
	uint_fast32_t actualCPUCyclesRun;
	
	gameTimer = [NSTimer scheduledTimerWithTimeInterval:(0.0166 + lastTimingCorrection) target:self selector:@selector(_nextFrame) userInfo:nil repeats:NO];
	
	[cpuInterpreter setData:[_controllerInterface readController:0] forController:0];
	[cpuInterpreter setData:[_controllerInterface readController:1] forController:1];// Pull latest controller data
	
	if ([ppuEmulator triggeredNMI]) [cpuInterpreter _performNonMaskableInterrupt]; // Invoke NMI if triggered by the PPU
	[cpuInterpreter executeUntilCycle:[ppuEmulator cpuCyclesUntilPrimingScanline]]; // Run CPU until just past VBLANK
	actualCPUCyclesRun = [cpuInterpreter executeUntilCycle:[ppuEmulator cpuCyclesUntilVblank]]; // Run CPU until the beginning of next VBLANK
	lastTimingCorrection = [apuEmulator endFrameOnCycle:actualCPUCyclesRun]; // End the APU frame and update timing correction
	[ppuEmulator runPPUUntilCPUCycle:actualCPUCyclesRun];
	[ppuEmulator resetCPUCycleCounter]; // Reset PPU's CPU cycle counter for next frame and update cartridge scanline counters (must occur before CPU cycle counter is reset)
	[cpuInterpreter resetCPUCycleCounter]; // Reset CPU cycle counter for next frame
	[playfieldView setNeedsDisplay:YES]; // Redraw the screen
}

- (IBAction)resetCPU:(id)sender {
	
	if (gameIsLoaded) {
		
		// Reset the PPU
		[ppuEmulator resetPPUstatus];
		
		// Reset ROM bank mapping
		[[cartEmulator cartridge] setInitialROMPointers];
		
		// Configure initial PPU state
		[[cartEmulator cartridge] configureInitialPPUState];
				
		// Reset the CPU to prepare for execution
		[cpuInterpreter reset];
	
		if (debuggerIsVisible) {
		
			[self updatecpuRegisters];
			[self updateInstructions:YES];
		}
	}
}

- (IBAction)showPreferences:(id)sender
{		
	if (gameIsRunning) [self play:nil]; // Pause the game if it is running
	if ([playfieldView isInFullScreenMode]) [self toggleFullScreenMode:nil]; // Switch out of full-screen if in it
	
	[preferencesWindow makeKeyAndOrderFront:nil];
}

- (BOOL)gameIsLoaded
{
	return gameIsLoaded;
}

- (void)setGameIsLoaded:(BOOL)flag
{
	gameIsLoaded = flag;
	
	if (flag) {
		
		[playPauseMenuItem setEnabled:YES];
		[resetMenuItem setEnabled:YES];
	}
	else {
		
		[playPauseMenuItem setTitle:@"Play"];
		[playPauseMenuItem setEnabled:NO];
		[resetMenuItem setEnabled:NO];
	}
}

- (IBAction)play:(id)sender {
	
	if (!gameIsRunning) {
		
		gameIsRunning = YES;
		[self _nextFrame];
		[apuEmulator resume]; // Start up the APU's buffered playback
		[playPauseMenuItem setTitle:@"Pause"];
	}
	else {
		
		gameIsRunning = NO;
		[gameTimer invalidate];
		gameTimer = nil;
		[apuEmulator pause];
		[playPauseMenuItem setTitle:@"Play"];
	}
}

- (IBAction)toggleFullScreenMode:(id)sender
{	
	BOOL gameWasRunning = gameIsRunning;
	
	if (gameIsLoaded) {
		
		if (gameWasRunning) [self play:nil]; // Pause the game during the transition
		if ([playfieldView isInFullScreenMode]) {
			
            CGDisplaySetDisplayMode(kCGDirectMainDisplay, _windowedMode, NULL);
            CGDisplayRelease(kCGDirectMainDisplay);
            
			[playfieldView exitFullScreenModeWithOptions:nil];
			[playfieldView scaleForWindowedDrawing];
		}
		else {
			
            CGDisplayCapture(kCGDirectMainDisplay);
            CGDisplaySetDisplayMode(kCGDirectMainDisplay, _fullScreenMode, NULL);
            
			[playfieldView enterFullScreenMode:[NSScreen mainScreen] withOptions:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO],NSFullScreenModeAllScreens,nil]];
			[playfieldView scaleForFullScreenDrawingWithWidth:CGDisplayModeGetWidth(_fullScreenMode) height:CGDisplayModeGetHeight(_fullScreenMode)];
		}
		if (gameWasRunning) [self play:nil]; // Resume the game at the end of the transition
	}
}

/* BEGIN Debugging functionality and alternate (non-optimized) codepaths */

- (void)_nextFrameWithBreak {
	
	uint_fast32_t actualCPUCyclesRun;
		
	if ([cpuInterpreter encounteredBreakpoint]) {
		
		gameIsRunning = NO;
		[self updatecpuRegisters];
		[self updateInstructions:NO];
		[cpuInterpreter setEncounteredBreakpoint:NO];
		[runDebugButton setTitle:@"Run"];
	}
	else {
		
		gameTimer = [NSTimer scheduledTimerWithTimeInterval:(0.0166 + lastTimingCorrection) target:self selector:@selector(_nextFrameWithBreak) userInfo:nil repeats:NO];
		
		[cpuInterpreter setData:[_controllerInterface readController:0] forController:0];
		[cpuInterpreter setData:[_controllerInterface readController:1] forController:1];// Pull latest controller data
		
		if ([ppuEmulator triggeredNMI] && ([cpuInterpreter cpuRegisters]->cycle == 0)) [cpuInterpreter _performNonMaskableInterrupt]; // Invoke NMI if triggered by the PPU
		actualCPUCyclesRun = [cpuInterpreter executeUntilCycleWithBreak:[ppuEmulator cpuCyclesUntilPrimingScanline]]; // Run CPU until just past VBLANK
		
		if (![cpuInterpreter encounteredBreakpoint]) {
			
			actualCPUCyclesRun = [cpuInterpreter executeUntilCycleWithBreak:[ppuEmulator cpuCyclesUntilVblank]]; // Run CPU until the beginning of the next VBLANK
			[ppuEmulator runPPUUntilCPUCycle:actualCPUCyclesRun];
		}
		
		if (![cpuInterpreter encounteredBreakpoint]) {
			
			lastTimingCorrection = [apuEmulator endFrameOnCycle:actualCPUCyclesRun]; // End the APU frame and update timing correction
			[ppuEmulator resetCPUCycleCounter];
			[cpuInterpreter resetCPUCycleCounter];
		}
		
		[playfieldView setNeedsDisplay:YES];
	}
}

- (IBAction)setBreak:(id)sender {
	
	uint16_t address;
	unsigned int scannedValue;
	NSScanner *hexScanner = [NSScanner scannerWithString:[peekField stringValue]];
	[hexScanner scanHexInt:&scannedValue];
	address = scannedValue; // take just 16-bits for the address
	
	[cpuInterpreter setBreakPoint:address];
	[self updateInstructions:YES];
}

- (IBAction)runUntilBreak:(id)sender {

	if (gameIsRunning) {
		
		gameIsRunning = NO;
		[gameTimer invalidate];
		gameTimer = nil;
		[apuEmulator pause];
		
		if (debuggerIsVisible) {
			
			[self updatecpuRegisters];
			[self updateInstructions:NO];
		}
		[runDebugButton setTitle:@"Run"];
	}
	else {
		
		gameIsRunning = YES;
		[cpuInterpreter setEncounteredBreakpoint:NO];
		[self _nextFrameWithBreak];
		[apuEmulator resume];
		[runDebugButton setTitle:@"Stop"];
	}
}

- (IBAction)showAndHideDebugger:(id)sender
{
	if (debuggerIsVisible) {
	
		[debuggerWindow orderOut:nil];
		debuggerIsVisible = NO;
		[ppuEmulator toggleDebugging:NO];
	}
	else {
	
		if ([playfieldView isInFullScreenMode]) [self toggleFullScreenMode:nil]; // Switch out of full-screen if in it
		if (gameIsRunning) [self runUntilBreak:nil]; // Pause the game if it is running
		
		[debuggerWindow makeKeyAndOrderFront:nil];
		debuggerIsVisible = YES;
		[self updatecpuRegisters];
		[self updateInstructions:NO];
		[ppuEmulator toggleDebugging:YES];
		
	}
}

- (IBAction)advanceFrame:(id)sender {

	uint_fast32_t actualCPUCyclesRun;
	
	[cpuInterpreter setEncounteredBreakpoint:NO]; // Clear existing break, if any to continue to next frame
		
	[cpuInterpreter setData:[_controllerInterface readController:0] forController:0];
	[cpuInterpreter setData:[_controllerInterface readController:1] forController:1];// Pull latest controller data
	
	if ([ppuEmulator triggeredNMI] && ([cpuInterpreter cpuRegisters]->cycle == 0)) [cpuInterpreter _performNonMaskableInterrupt]; // Invoke NMI if triggered by the PPU
	actualCPUCyclesRun = [cpuInterpreter executeUntilCycleWithBreak:[ppuEmulator cpuCyclesUntilPrimingScanline]]; // Run CPU until just past VBLANK
	
	if (![cpuInterpreter encounteredBreakpoint]) {
		
		actualCPUCyclesRun = [cpuInterpreter executeUntilCycleWithBreak:[ppuEmulator cpuCyclesUntilVblank]]; // Run CPU until the beginning of the next VBLANK
		[ppuEmulator runPPUUntilCPUCycle:actualCPUCyclesRun];
	}
	
	if (![cpuInterpreter encounteredBreakpoint]) {
		
		[apuEmulator endFrameOnCycle:actualCPUCyclesRun]; // End the APU frame and update timing correction
		[ppuEmulator resetCPUCycleCounter];
		[cpuInterpreter resetCPUCycleCounter];
	}
	
	[apuEmulator clearBuffer];
	[playfieldView setNeedsDisplay:YES];
	
	if (debuggerIsVisible) {
		
		[self updatecpuRegisters];
		[self updateInstructions:NO];
	}
}

- (IBAction)step:(id)sender {
	
	// Only allow step-through if game is not running
	if (!gameIsRunning) {
		
		if ([ppuEmulator triggeredNMI] && ([cpuInterpreter cpuRegisters]->cycle == 0)) [cpuInterpreter _performNonMaskableInterrupt];
		else [cpuInterpreter interpretOpcode];
		[ppuEmulator runPPUUntilCPUCycle:[cpuInterpreter cpuRegisters]->cycle];
		[apuEmulator clearBuffer];
		[playfieldView setNeedsDisplay:YES];
		
		if ([cpuInterpreter cpuRegisters]->cycle >= [ppuEmulator cpuCyclesUntilVblank]) {
			
			[apuEmulator endFrameOnCycle:[cpuInterpreter cpuRegisters]->cycle]; // End the APU frame and update timing correction
			[ppuEmulator resetCPUCycleCounter];
			[cpuInterpreter resetCPUCycleCounter];
		}
		
		if (debuggerIsVisible) {
			
			[self updatecpuRegisters];
			[self updateInstructions:NO];
		}
	}
}

- (IBAction)peek:(id)sender 
{
	uint16_t address;
	unsigned int scannedValue;
	NSScanner *hexScanner = [NSScanner scannerWithString:[peekField stringValue]];
	[hexScanner scanHexInt:&scannedValue];
	address = scannedValue; // take just 16-bits for the address
	
	[pokeField setStringValue:[NSString stringWithFormat:@"0x%2.2x",[cpuInterpreter readByteFromCPUAddressSpace:address]]];
}

- (IBAction)poke:(id)sender
{
	uint16_t address;
	uint8_t value;
	unsigned int scannedAddress;
	unsigned int scannedValue;
	NSScanner *hexScanner = [NSScanner scannerWithString:[peekField stringValue]];
	[hexScanner scanHexInt:&scannedAddress];
	address = scannedAddress; // take just 16-bits for the address
	hexScanner = [NSScanner scannerWithString:[pokeField stringValue]];
	[hexScanner scanHexInt:&scannedValue];
	value = scannedValue; // take just 8 bits for the value
	
	[cpuInterpreter writeByte:value toCPUAddress:address];
}

- (void)updatecpuRegisters
{
	CPURegisters *registers = [cpuInterpreter cpuRegisters];
	
	[self setCpuRegisters:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"0x%2.2x",registers->accumulator],@"accumulator",
			 [NSString stringWithFormat:@"0x%2.2x",registers->indexRegisterX],@"indexRegisterX",
			 [NSString stringWithFormat:@"0x%2.2x",registers->indexRegisterY],@"indexRegisterY",
			 [NSString stringWithFormat:@"0x%4.4x",registers->programCounter],@"programCounter",
			 [NSString stringWithFormat:@"0x%2.2x",registers->stackPointer],@"stackPointer",
			 [NSString stringWithFormat:@"%d",registers->statusCarry],@"statusCarry",
			 [NSString stringWithFormat:@"%d",registers->statusZero],@"statusZero",
			 [NSString stringWithFormat:@"%d",registers->statusIRQDisable],@"irqDisable",
			 [NSString stringWithFormat:@"%d",registers->statusBreak],@"statusBreak",
			 [NSString stringWithFormat:@"%d",registers->statusOverflow],@"statusOverflow",
			 [NSString stringWithFormat:@"%d",registers->statusDecimal],@"statusDecimal",
			 [NSString stringWithFormat:@"%d",registers->statusNegative],@"statusNegative",nil]];
}

@synthesize cpuRegisters;
@synthesize instructions;

- (void)updateInstructions:(BOOL)force
{
	uint16_t edgeOfPage = 0x00FF | ([cpuInterpreter cpuRegisters]->programCounter & 0xFF00);
	uint16_t addressOfCurrentInstruction = [cpuInterpreter cpuRegisters]->programCounter;
	uint16_t currentInstr = addressOfCurrentInstruction;
	uint16_t breakPoint = [cpuInterpreter breakPoint];
	uint8_t currentOpcode;
	uint16_t address;
	uint8_t operand;
	NSMutableArray *instructionArray;
	
	int firstObject;
	int lastObject;
	int currentSearch;
	unsigned int currentSearchValue;
	unsigned int firstInstruction = [[[instructions objectAtIndex:0] objectForKey:@"address"] unsignedIntValue];
	unsigned int lastInstruction = [[[instructions lastObject] objectForKey:@"address"] unsignedIntValue];
	
	if (([cpuInterpreter cpuRegisters]->programCounter < firstInstruction) || ([cpuInterpreter cpuRegisters]->programCounter > lastInstruction) || force) {
		
		instructionArray = [NSMutableArray array];
		
		while (addressOfCurrentInstruction <= edgeOfPage) {
			
			currentOpcode = [cpuInterpreter readByteFromCPUAddressSpace:addressOfCurrentInstruction];
			
			if (instructionArguments[currentOpcode] == 2) {
				
				address = [cpuInterpreter readByteFromCPUAddressSpace:addressOfCurrentInstruction + 2] * 256;
				address |= [cpuInterpreter readByteFromCPUAddressSpace:addressOfCurrentInstruction + 1];
				
				[instructionArray addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"%s",instructionNames[currentOpcode]],@"name",
											 [NSString stringWithFormat:@"0x%4.4x",address],@"argument",
											 [NSString stringWithFormat:@"%s",instructionDescriptions[[cpuInterpreter readByteFromCPUAddressSpace:addressOfCurrentInstruction]]],@"description",
											 [NSNumber numberWithUnsignedInt:addressOfCurrentInstruction],@"address",
											 addressOfCurrentInstruction == breakPoint ? [NSNumber numberWithBool:YES] : [NSNumber numberWithBool:NO],@"break",
											 nil]];
				addressOfCurrentInstruction += 3;
			}
			else if (instructionArguments[currentOpcode] == 1) {
				
				operand = [cpuInterpreter readByteFromCPUAddressSpace:addressOfCurrentInstruction + 1];
				
				[instructionArray addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"%s",instructionNames[currentOpcode]],@"name",
											 [NSString stringWithFormat:@"0x%2.2x",operand],@"argument",
											 [NSString stringWithFormat:@"%s",instructionDescriptions[[cpuInterpreter readByteFromCPUAddressSpace:addressOfCurrentInstruction]]],@"description",
											 [NSNumber numberWithUnsignedInt:addressOfCurrentInstruction],@"address",
											 addressOfCurrentInstruction == breakPoint ? [NSNumber numberWithBool:YES] : [NSNumber numberWithBool:NO],@"break",
											 nil]];
				
				addressOfCurrentInstruction += 2;
			}
			else {
				
				[instructionArray addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"%s",instructionNames[currentOpcode]],@"name",
											 @"(Implied)",@"argument",
											 [NSString stringWithFormat:@"%s",instructionDescriptions[[cpuInterpreter readByteFromCPUAddressSpace:addressOfCurrentInstruction]]],@"description",
											 [NSNumber numberWithUnsignedInt:addressOfCurrentInstruction],@"address",
											 addressOfCurrentInstruction == breakPoint ? [NSNumber numberWithBool:YES] : [NSNumber numberWithBool:NO],@"break",
											 nil]];
				
				addressOfCurrentInstruction++;
			}
		}
		
		[self setInstructions:instructionArray];
	}
	else {
		
		//Remove current key of last instruction
		[_currentInstruction removeObjectForKey:@"current"];
	}
	
	// set current instruction
	currentSearch = firstObject = 0;
	lastObject = [instructions count] - 1;
	
	while ((currentSearchValue = [[[instructions objectAtIndex:currentSearch] objectForKey:@"address"] unsignedIntValue]) != currentInstr) {
	
		if (currentSearchValue < currentInstr) {
			
			firstObject = currentSearch;
			currentSearch = currentSearch == firstObject ? lastObject : (lastObject + currentSearch) / 2;
		}
		else {
			
			lastObject = currentSearch;
			currentSearch = (firstObject + currentSearch) / 2;
		}
	}
	
	_currentInstruction = [instructions objectAtIndex:currentSearch];
	[_currentInstruction setObject:[NSImage imageNamed:NSImageNameRightFacingTriangleTemplate] forKey:@"current"];
}

/* END Debugging functionality and alternate (non-optimized) codepaths */

/* BEGIN Windowing system event handlers */

- (void)applicationWillResignActive:(NSNotification *)notification
{	
	if (gameIsRunning) {
		
		[self play:nil];
		playOnActivate = YES;
	}
	else {
		
		playOnActivate = NO;
	}
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{	
	if (playOnActivate) {
		
		[self play:nil];
	}
}

- (BOOL)windowShouldClose:(id)sender
{
	if (sender == debuggerWindow) {
	
		[self showAndHideDebugger:nil];
		return NO;
	}
	
	return YES;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {

	if (gameIsRunning) [self play:nil]; // Pause the game
	[apuEmulator stopAPUPlayback]; // Terminate audio playback
	if (gameIsLoaded) [[cartEmulator cartridge] writeWRAMToDisk]; // Save SRAM to disk if the game uses it
	
	return NSTerminateNow;
}

/* END Windowing system event handlers */

@end
