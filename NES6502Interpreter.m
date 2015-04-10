/* NES6502Interpreter.m
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

#import "NES6502Interpreter.h"
#import "NESCartridge.h"
#import "NESPPUEmulator.h"
#import "NESAPUEmulator.h"

#define NO_PENDING_IRQ 0xffffffff

static void _ADC(CPURegisters *cpuRegisters, uint8_t operand) {
	
	uint8_t oldAccumulator = cpuRegisters->accumulator;
	uint16_t result = (uint16_t)oldAccumulator + operand + cpuRegisters->statusCarry;
	cpuRegisters->accumulator = (uint8_t)result;
	cpuRegisters->statusCarry = result >> 8;
	cpuRegisters->statusNegative = cpuRegisters->accumulator >> 7;
	cpuRegisters->statusOverflow = ((oldAccumulator ^ cpuRegisters->accumulator) & (operand ^ cpuRegisters->accumulator)) / 128;
	cpuRegisters->statusZero = !cpuRegisters->accumulator;
}

static void _AND(CPURegisters *cpuRegisters, uint8_t operand) {
	
	cpuRegisters->accumulator &= operand;
	cpuRegisters->statusNegative = cpuRegisters->accumulator >> 7;
	cpuRegisters->statusZero = !cpuRegisters->accumulator;
}

static void _ASL(CPURegisters *cpuRegisters, uint8_t operand) {
	
	cpuRegisters->statusCarry = cpuRegisters->accumulator >> 7;
	cpuRegisters->accumulator <<= 1;
	cpuRegisters->statusNegative = cpuRegisters->accumulator >> 7;
	cpuRegisters->statusZero = !cpuRegisters->accumulator;
}

static uint8_t _ASL_RMW(CPURegisters *cpuRegisters, uint8_t operand) {
	
	cpuRegisters->statusCarry = operand >> 7;
	operand <<= 1;
	cpuRegisters->statusNegative = operand >> 7;
	cpuRegisters->statusZero = !operand;
	
	return operand;
}

static void _BIT(CPURegisters *cpuRegisters, uint8_t operand) {
	
	cpuRegisters->statusNegative = operand >> 7;
	cpuRegisters->statusOverflow = ((operand / 64) & 1);
	cpuRegisters->statusZero = !(cpuRegisters->accumulator & operand);
}

static void _CMP(CPURegisters *cpuRegisters, uint8_t operand) {
	
	uint8_t result = cpuRegisters->accumulator - operand;
	cpuRegisters->statusCarry = (operand <= cpuRegisters->accumulator); // Should be an unsigned comparison
	cpuRegisters->statusNegative = result >> 7;
	cpuRegisters->statusZero = !result;
}

static void _CPX(CPURegisters *cpuRegisters, uint8_t operand) {
	
	uint8_t result = cpuRegisters->indexRegisterX - operand;
	cpuRegisters->statusCarry = (operand <= cpuRegisters->indexRegisterX); // Should be an unsigned comparison
	cpuRegisters->statusNegative = result >> 7;
	cpuRegisters->statusZero = !result;
}

static void _CPY(CPURegisters *cpuRegisters, uint8_t operand) {
	
	uint8_t result = cpuRegisters->indexRegisterY - operand;
	cpuRegisters->statusCarry = (operand <= cpuRegisters->indexRegisterY); // Should be an unsigned comparison
	cpuRegisters->statusNegative = result >> 7;
	cpuRegisters->statusZero = !result;
}

static uint8_t _DEC(CPURegisters *cpuRegisters, uint8_t operand) {
	
	operand--;
	cpuRegisters->statusNegative = operand >> 7;
	cpuRegisters->statusZero = !operand;
	
	return operand;
}

static uint8_t _INC(CPURegisters *cpuRegisters, uint8_t operand) {
	
	operand++;
	cpuRegisters->statusNegative = operand >> 7;
	cpuRegisters->statusZero = !operand;
	
	return operand;
}

static void _EOR(CPURegisters *cpuRegisters, uint8_t operand) {
	
	cpuRegisters->accumulator ^= operand;
	cpuRegisters->statusNegative = cpuRegisters->accumulator >> 7;
	cpuRegisters->statusZero = !cpuRegisters->accumulator;
}

static void _LDA(CPURegisters *cpuRegisters, uint8_t operand) {
	
	cpuRegisters->accumulator = operand;
	cpuRegisters->statusNegative = operand >> 7;
	cpuRegisters->statusZero = !operand;
}

static void _LDX(CPURegisters *cpuRegisters, uint8_t operand) {
	
	cpuRegisters->indexRegisterX = operand;
	cpuRegisters->statusNegative = operand >> 7;
	cpuRegisters->statusZero = !operand;
}

static void _LDY(CPURegisters *cpuRegisters, uint8_t operand) {
	
	cpuRegisters->indexRegisterY = operand;
	cpuRegisters->statusNegative = operand >> 7;
	cpuRegisters->statusZero = !operand;
}

static void _LSR(CPURegisters *cpuRegisters, uint8_t operand) {
	
	cpuRegisters->statusCarry = (cpuRegisters->accumulator & 1);
	cpuRegisters->accumulator >>= 1;
	cpuRegisters->statusNegative = cpuRegisters->accumulator >> 7;
	cpuRegisters->statusZero = !cpuRegisters->accumulator;
}

static uint8_t _LSR_RMW(CPURegisters *cpuRegisters, uint8_t operand) {
	
	cpuRegisters->statusCarry = (operand & 1);
	operand >>= 1;
	cpuRegisters->statusNegative = operand >> 7;
	cpuRegisters->statusZero = !operand;
	
	return operand;
}

static void _ORA(CPURegisters *cpuRegisters, uint8_t operand) {
	
	cpuRegisters->accumulator |= operand;
	cpuRegisters->statusNegative = cpuRegisters->accumulator >> 7;
	cpuRegisters->statusZero = !cpuRegisters->accumulator;
}

static void _ROL(CPURegisters *cpuRegisters, uint8_t operand) {
	
	uint8_t oldCarry = cpuRegisters->statusCarry;
	cpuRegisters->statusCarry = cpuRegisters->accumulator >> 7;
	cpuRegisters->accumulator <<= 1;
	cpuRegisters->accumulator |= oldCarry;
	cpuRegisters->statusNegative = cpuRegisters->accumulator >> 7;
	cpuRegisters->statusZero = !cpuRegisters->accumulator;
}

static uint8_t _ROL_RMW(CPURegisters *cpuRegisters, uint8_t operand) {
	
	uint8_t oldCarry = cpuRegisters->statusCarry;
	cpuRegisters->statusCarry = operand >> 7;
	operand <<= 1;
	operand |= oldCarry;
	cpuRegisters->statusNegative = operand >> 7;
	cpuRegisters->statusZero = !operand;
	
	return operand;
}

static void _ROR(CPURegisters *cpuRegisters, uint8_t operand) {
	
	uint8_t oldCarry = cpuRegisters->statusCarry;
	cpuRegisters->statusCarry = (cpuRegisters->accumulator & 1);
	cpuRegisters->accumulator >>= 1;
	cpuRegisters->accumulator |= (oldCarry << 7);
	cpuRegisters->statusNegative = cpuRegisters->accumulator >> 7;
	cpuRegisters->statusZero = !cpuRegisters->accumulator;
}

static uint8_t _ROR_RMW(CPURegisters *cpuRegisters, uint8_t operand) {
	
	uint8_t oldCarry = cpuRegisters->statusCarry;
	cpuRegisters->statusCarry = (operand & 1);
	operand >>= 1;
	operand |= (oldCarry << 7);
	cpuRegisters->statusNegative = operand >> 7;
	cpuRegisters->statusZero = !operand;
	
	return operand;
}

static void _SBC(CPURegisters *cpuRegisters, uint8_t operand) {
	
	uint8_t oldAccumulator = cpuRegisters->accumulator;
	operand = ~operand; // invert operand bits, used to do this below but it must happen BEFORE promotion to uin16_t
	uint16_t result = (uint16_t)oldAccumulator + operand + cpuRegisters->statusCarry;
	cpuRegisters->accumulator = (uint8_t)result;
	cpuRegisters->statusCarry = result >> 8;
	cpuRegisters->statusNegative = cpuRegisters->accumulator >> 7;
	cpuRegisters->statusOverflow = ((oldAccumulator ^ cpuRegisters->accumulator) & (operand ^ cpuRegisters->accumulator)) / 128;
	cpuRegisters->statusZero = !cpuRegisters->accumulator;
}

static uint8_t _GetAccumulator(CPURegisters *cpuRegisters, uint8_t operand) {
	
	return cpuRegisters->accumulator;
}

static uint8_t _GetIndexRegisterX(CPURegisters *cpuRegisters, uint8_t operand) {
	
	return cpuRegisters->indexRegisterX;
}

static uint8_t _GetIndexRegisterY(CPURegisters *cpuRegisters, uint8_t operand) {
	
	return cpuRegisters->indexRegisterY;
}

@implementation NES6502Interpreter

@synthesize encounteredBreakpoint = _encounteredBreakpoint;

- (void)_clearRegisters
{
	_cpuRegisters->accumulator = 0;
	_cpuRegisters->indexRegisterX = 0;
	_cpuRegisters->indexRegisterY = 0;
	_cpuRegisters->programCounter = 0;
	_cpuRegisters->stackPointer = 0xFF; // FIXME: http://nesdevwiki.org/wiki/Power-Up_State says this should be $FD
	_cpuRegisters->statusCarry = 0;
	_cpuRegisters->statusZero = 0;
	_cpuRegisters->statusIRQDisable = 1; // Tepples indicates that IRQs are disabled on boot-up, as though SEI was invoked
	_cpuRegisters->statusDecimal = 0;
	_cpuRegisters->statusBreak = 0; // FIXME: http://nesdevwiki.org/wiki/Power-Up_State says this should be on
	_cpuRegisters->statusOverflow = 0;
	_cpuRegisters->statusNegative = 0;	
}

- (void)_clearCPUMemory
{
	int counter;
	
	// Taken from http://nesdevwiki.org/wiki/Power-Up_State
	for (counter = 0; counter < 2048; counter++) _zeroPage[counter] = 0xFF;
	
	_zeroPage[0x0008] = 0xF7;
	_zeroPage[0x0009] = 0xEF;
	_zeroPage[0x000a] = 0xDF;
	_zeroPage[0x000f] = 0xBF;
}

- (void)_clearStatus
{
	_cpuRegisters->cycle = 0;
	_nextIRQ = NO_PENDING_IRQ;
	breakPoint = 0;
	_encounteredUnsupportedOpcode = NO;
	_encounteredBreakpoint = NO;
	
	_controllers[0] = 0x0001FF00; // Should indicate one controller on $4016 per nestech.txt
	_controllers[1] = 0x0002FF00; // Should indicate one controller on $4017 per nestech.txt
	_controller0ReadIndex = 0;
	_controller1ReadIndex = 0;
}

- (uint8_t)readByteFromCPUAddressSpace:(uint16_t)address
{
	if (address >= 0x8000) return _prgromBankPointers[(address & 0x7FFF) / PRGROM_BANK_SIZE][address & (PRGROM_BANK_SIZE - 1)];
	else if (address < 0x2000) return _zeroPage[address & 0x07FF];
	else if (address >= 0x6000) return _wram[address & (WRAM_SIZE - 1)];
	else if (address >= 0x4020) return 0;
	else if (address >= 0x4000) {
	
		switch (address) {
		
			case 0x4015:
				return [apu readAPUStatusOnCycle:_cpuRegisters->cycle];
				break;
			case 0x4016:
				return ((_controllers[0] >> _controller0ReadIndex++) & 0x1);
				break;
			case 0x4017:
				return ((_controllers[1] >> _controller1ReadIndex++) & 0x1);
				break;
			default:
				break;
		}
	}
	else return [ppu readByteFromCPUAddress:address onCycle:_cpuRegisters->cycle];
	
	return 0;
}

- (uint16_t)readAddressFromCPUAddressSpace:(uint16_t)address
{	
	if (address >= 0x8000) return _prgromBankPointers[(address & 0x7FFF) / PRGROM_BANK_SIZE][address & (PRGROM_BANK_SIZE - 1)] + ((uint16_t)_prgromBankPointers[((address + 1) & 0x7FFF) / PRGROM_BANK_SIZE][(address + 1) & (PRGROM_BANK_SIZE - 1)] * 256);
	
	return _readByteFromCPUAddressSpace(self,@selector(readByteFromCPUAddressSpace:),address) + ((uint16_t)_readByteFromCPUAddressSpace(self,@selector(readByteFromCPUAddressSpace:),address + 1) * 256);
}

- (void)writeByte:(uint8_t)byte toCPUAddress:(uint16_t)address
{
	uint8_t *DMAorigin;
	
	if (address < 0x2000) {
	
		_zeroPage[address & 0x07FF] = byte;
	}
	else if (address < 0x4000) [ppu writeByte:byte toPPUFromCPUAddress:address onCycle:_cpuRegisters->cycle];
	else if (address < 0x4020) {
		
		if (address == 0x4014) {
						
            // Resolve base address for DMA origin
			if (byte < 32) {
				
				// NSLog(@"Initiating DMA SPRRAM transfer from CPU RAM: 0x%4.4x", (0x100 * byte));
				DMAorigin = _zeroPage + (0x100 * (byte & 0x7));
			}
			else if (byte >= 128) {
				
				DMAorigin = _prgromBankPointers[(0x100 * (byte & 0x7F)) / PRGROM_BANK_SIZE] + ((0x100 * (byte & 0x7F)) & (PRGROM_BANK_SIZE - 1)); 
			}
			else if (byte >= 96) {
				
				// NSLog(@"Initiating DMA SPRRAM transfer from WRAM: 0x%4.4x", (0x100 * byte));
				DMAorigin = _wram + (0x100 * (byte & 0x1F));
			}
			else {
				
				// NSLog(@"Initiating DMA SPRRAM transfer from place I don't have a pointer to: 0x%4.4x", (0x100 * byte));
				DMAorigin = NULL; // Crap! Don't know what to do about DMA transfers from registers
			}
			[ppu DMAtransferToSPRRAM:DMAorigin onCycle:_cpuRegisters->cycle];
			_cpuRegisters->cycle += 512; // DMA transfer to SPRRAM requires 512 CPU cycles
		}
		else if (address == 0x4016) {
		
			_controller0ReadIndex = 0; // FIXME: Really, I should be resetting this when 1 then 0 is written
			_controller1ReadIndex = 0;
		}
		else {
		
			// Write to APU Register (0x4000-0x4017, except 0x4014 and 0x4016)
			[apu writeByte:byte toAPUFromCPUAddress:address onCycle:_cpuRegisters->cycle];
		}
	}
	else if (address < 0x6000) return;
	else if (address < 0x8000) {
		
		[cartridge writeByte:byte toWRAMwithCPUAddress:address onCycle:_cpuRegisters->cycle];
	}
	else {
		
		[cartridge writeByte:byte toPRGROMwithCPUAddress:address onCycle:_cpuRegisters->cycle];
	}
}

- (void)_unsupportedOpcode:(uint8_t)opcode
{
	NSLog(@"Encountered unsupported opcode %2.2x at program counter %4.4x on cycle %d",opcode,_cpuRegisters->programCounter,_cpuRegisters->cycle);
	_encounteredUnsupportedOpcode = YES;
}

- (void)_performImpliedOperation:(uint8_t)opcode
{
	_standardOperations[opcode](_cpuRegisters,opcode);
	
	_cpuRegisters->cycle += 2;
}

- (void)_performOperationAsImmediate:(uint8_t)opcode
{
	_standardOperations[opcode](_cpuRegisters,_readByteFromCPUAddressSpace(self,@selector(readByteFromCPUAddressSpace:),_cpuRegisters->programCounter++));
	
	_cpuRegisters->cycle += 2;
}

- (void)_performOperationAsAbsolute:(uint8_t)opcode
{
	uint8_t operand;

	// FIXME: I'm not sure if I split the cycles correctly here, need to read the 6502 reference
	_cpuRegisters->cycle += 3;
	operand = _readByteFromCPUAddressSpace(self,@selector(readByteFromCPUAddressSpace:),[self readAddressFromCPUAddressSpace:_cpuRegisters->programCounter]);
	_cpuRegisters->cycle += 1;
	_standardOperations[opcode](_cpuRegisters,operand);
	_cpuRegisters->programCounter += 2;
}

// FIXME: Should accurately model all reads
- (void)_performOperationAsAbsoluteX:(uint8_t)opcode
{
	uint16_t absoluteAddress = [self readAddressFromCPUAddressSpace:_cpuRegisters->programCounter];
	uint16_t indexedAddress = absoluteAddress + _cpuRegisters->indexRegisterX;
	_standardOperations[opcode](_cpuRegisters,_readByteFromCPUAddressSpace(self,@selector(readByteFromCPUAddressSpace:),indexedAddress));
	_cpuRegisters->programCounter += 2;
	
	_cpuRegisters->cycle += 4 + ((absoluteAddress >> 8) != (indexedAddress >> 8) ? 1 : 0);
}

// FIXME: Should accurately model all reads
- (void)_performOperationAsAbsoluteY:(uint8_t)opcode
{
	uint16_t absoluteAddress = [self readAddressFromCPUAddressSpace:_cpuRegisters->programCounter];
	uint16_t indexedAddress = absoluteAddress + _cpuRegisters->indexRegisterY;
	_standardOperations[opcode](_cpuRegisters,_readByteFromCPUAddressSpace(self,@selector(readByteFromCPUAddressSpace:),indexedAddress));
	_cpuRegisters->programCounter += 2;
	
	_cpuRegisters->cycle += 4 + ((absoluteAddress >> 8) != (indexedAddress >> 8) ? 1 : 0);
}

- (void)_performOperationAsZeroPage:(uint8_t)opcode
{
	_standardOperations[opcode](_cpuRegisters,_zeroPage[_readByteFromCPUAddressSpace(self,@selector(readByteFromCPUAddressSpace:),_cpuRegisters->programCounter++)]);
	
	_cpuRegisters->cycle += 3;
}

- (void)_performOperationAsZeroPageX:(uint8_t)opcode
{
	_standardOperations[opcode](_cpuRegisters,_zeroPage[(uint8_t)(_readByteFromCPUAddressSpace(self,@selector(readByteFromCPUAddressSpace:),_cpuRegisters->programCounter++) + _cpuRegisters->indexRegisterX)]); // hopefully this add will be done as uint8_t, causing it to wrap
	
	_cpuRegisters->cycle += 4;
}

- (void)_performOperationAsZeroPageY:(uint8_t)opcode
{
	_standardOperations[opcode](_cpuRegisters,_zeroPage[(uint8_t)(_readByteFromCPUAddressSpace(self,@selector(readByteFromCPUAddressSpace:),_cpuRegisters->programCounter++) + _cpuRegisters->indexRegisterY)]); // hopefully this add will be done as uint8_t, causing it to wrap
	
	_cpuRegisters->cycle += 4;
}

/* _performOperationAsIndirectX
 * 
 * Description: Performs an operation obtaining the operand through an indexed indirect fetch relative to X.
 *
 * First ADL is fetched using the byte following the opcode, offset by IndexRegisterX, to index page zero.
 * ADH is fetched using the same address plus one. This should wrap due to overflow if reading beyond page zero.
 */
- (void)_performOperationAsIndirectX:(uint8_t)opcode
{
	uint16_t effectiveAddress = _zeroPage[(uint8_t)(_readByteFromCPUAddressSpace(self,@selector(readByteFromCPUAddressSpace:),_cpuRegisters->programCounter) + _cpuRegisters->indexRegisterX)]; // Fetch ADL
	effectiveAddress += (_zeroPage[(uint8_t)(_readByteFromCPUAddressSpace(self,@selector(readByteFromCPUAddressSpace:),_cpuRegisters->programCounter++) + _cpuRegisters->indexRegisterX + 1)] << 8); // Fetch ADH
	uint8_t operand = _readByteFromCPUAddressSpace(self,@selector(readByteFromCPUAddressSpace:),effectiveAddress);
	_standardOperations[opcode](_cpuRegisters,operand);
	
	_cpuRegisters->cycle += 6;
}

/* _performOperationAsIndirectY
 * 
 * Description: Performs an operation obtaining the operand through an indirect indexed fetch relative to Y.
 *
 * Note: Page crossing will result in a cycle beind added.
 */
- (void)_performOperationAsIndirectY:(uint8_t)opcode
{
	uint16_t effectiveAddress = 0;
	uint16_t absoluteAddress = _zeroPage[_readByteFromCPUAddressSpace(self,@selector(readByteFromCPUAddressSpace:),_cpuRegisters->programCounter)]; // Fetch BAL
	absoluteAddress += (_zeroPage[(uint8_t)(_readByteFromCPUAddressSpace(self,@selector(readByteFromCPUAddressSpace:),_cpuRegisters->programCounter++) + 1)] << 8); // Fetch BAH
	effectiveAddress = absoluteAddress + _cpuRegisters->indexRegisterY; // Add IndexRegisterY to BAH,BAL, potential page crossing
	uint8_t operand = _readByteFromCPUAddressSpace(self,@selector(readByteFromCPUAddressSpace:),effectiveAddress);
	_standardOperations[opcode](_cpuRegisters,operand);
	
	_cpuRegisters->cycle += (5 + ((absoluteAddress >> 8) != (effectiveAddress >> 8) ? 1 : 0)); // Check for page crossing
}

- (void)_performWriteOperationWithAbsolute:(uint8_t)opcode
{
	uint16_t address = [self readAddressFromCPUAddressSpace:_cpuRegisters->programCounter];
	_cpuRegisters->programCounter += 2;
	_cpuRegisters->cycle += 4;
	[self writeByte:_writeOperations[opcode](_cpuRegisters,opcode) toCPUAddress:address];
}

- (void)_performWriteOperationWithAbsoluteX:(uint8_t)opcode
{
	uint16_t absoluteAddress = [self readAddressFromCPUAddressSpace:_cpuRegisters->programCounter];
	uint16_t indexedAddress = absoluteAddress + _cpuRegisters->indexRegisterX;
	_cpuRegisters->cycle += 5;
	_cpuRegisters->programCounter += 2;
	[self writeByte:_writeOperations[opcode](_cpuRegisters,opcode) toCPUAddress:indexedAddress];
}

- (void)_performWriteOperationWithAbsoluteY:(uint8_t)opcode
{
	uint16_t absoluteAddress = [self readAddressFromCPUAddressSpace:_cpuRegisters->programCounter];
	uint16_t indexedAddress = absoluteAddress + _cpuRegisters->indexRegisterY;
	_cpuRegisters->cycle += 5;
	_cpuRegisters->programCounter += 2;
	[self writeByte:_writeOperations[opcode](_cpuRegisters,opcode) toCPUAddress:indexedAddress];
}

- (void)_performWriteOperationWithZeroPage:(uint8_t)opcode
{
	_zeroPage[_readByteFromCPUAddressSpace(self,@selector(readByteFromCPUAddressSpace:),_cpuRegisters->programCounter++)] = _writeOperations[opcode](_cpuRegisters,opcode);
	
	_cpuRegisters->cycle += 3;
}

- (void)_performWriteOperationWithZeroPageX:(uint8_t)opcode
{
	_zeroPage[(uint8_t)(_readByteFromCPUAddressSpace(self,@selector(readByteFromCPUAddressSpace:),_cpuRegisters->programCounter++) + _cpuRegisters->indexRegisterX)] = _writeOperations[opcode](_cpuRegisters,opcode); // hopefully this add will be done as uint8_t, causing it to wrap
	
	_cpuRegisters->cycle += 4;
}

- (void)_performWriteOperationWithZeroPageY:(uint8_t)opcode
{
	_zeroPage[(uint8_t)(_readByteFromCPUAddressSpace(self,@selector(readByteFromCPUAddressSpace:),_cpuRegisters->programCounter++) + _cpuRegisters->indexRegisterY)] = _writeOperations[opcode](_cpuRegisters,opcode); // hopefully this add will be done as uint8_t, causing it to wrap
	
	_cpuRegisters->cycle += 4;
}

/* _performOperationAsIndirectX
 * 
 * Description: Performs an operation obtaining the operand through an indexed indirect fetch relative to X.
 *
 * Note: This does a separate fetch for each byte in the effective address. This is slower but prevents endianess issues.
 */
- (void)_performWriteOperationWithIndirectX:(uint8_t)opcode
{
	uint16_t effectiveAddress = _zeroPage[(uint8_t)(_readByteFromCPUAddressSpace(self,@selector(readByteFromCPUAddressSpace:),_cpuRegisters->programCounter) + _cpuRegisters->indexRegisterX)]; // Fetch ADL
	effectiveAddress += (_zeroPage[(uint8_t)(_readByteFromCPUAddressSpace(self,@selector(readByteFromCPUAddressSpace:),_cpuRegisters->programCounter++) + _cpuRegisters->indexRegisterX + 1)] << 8); // Fetch ADH
	[self writeByte:_writeOperations[opcode](_cpuRegisters,opcode) toCPUAddress:effectiveAddress];
	
	_cpuRegisters->cycle += 6;
}

/* _performOperationAsIndirectY
 * 
 * Description: Performs an operation obtaining the operand through an indirect indexed fetch relative to Y.
 *
 * Note: This does a separate fetch for each byte in the effective address. This is slower but prevents endianess issues.
 */

- (void)_performWriteOperationWithIndirectY:(uint8_t)opcode
{
	uint16_t effectiveAddress = 0;
	uint16_t absoluteAddress = _zeroPage[_readByteFromCPUAddressSpace(self,@selector(readByteFromCPUAddressSpace:),_cpuRegisters->programCounter)]; // Fetch BAL
	absoluteAddress += (_zeroPage[(uint8_t)(_readByteFromCPUAddressSpace(self,@selector(readByteFromCPUAddressSpace:),_cpuRegisters->programCounter++) + 1)] << 8); // Fetch BAH
	effectiveAddress = absoluteAddress + _cpuRegisters->indexRegisterY; // Add IndexRegisterY to BAH,BAL, potential page crossing
	[self writeByte:_writeOperations[opcode](_cpuRegisters,opcode) toCPUAddress:effectiveAddress];
	
	_cpuRegisters->cycle += 6;
}

// FIXME: Should emulate all reads and writes for RMW
- (void)_performOperationAsRMWAbsolute:(uint8_t)opcode
{
	uint16_t address = [self readAddressFromCPUAddressSpace:_cpuRegisters->programCounter];
	uint8_t value = _writeOperations[opcode](_cpuRegisters,_readByteFromCPUAddressSpace(self,@selector(readByteFromCPUAddressSpace:),address));
	_cpuRegisters->programCounter += 2;
	[self writeByte:value toCPUAddress:address];
	
	_cpuRegisters->cycle += 6; // Read-Modify-Write Absolute operations take 6 cycles
}

// FIXME: Should emulate all reads and writes for RMW
- (void)_performOperationAsRMWAbsoluteX:(uint8_t)opcode
{
	uint16_t absoluteAddress = [self readAddressFromCPUAddressSpace:_cpuRegisters->programCounter];
	uint16_t indexedAddress = absoluteAddress + _cpuRegisters->indexRegisterX;
	uint8_t value = _writeOperations[opcode](_cpuRegisters,_readByteFromCPUAddressSpace(self,@selector(readByteFromCPUAddressSpace:),indexedAddress));
	_cpuRegisters->programCounter += 2;
	[self writeByte:value toCPUAddress:indexedAddress];
	
	_cpuRegisters->cycle += 7; // Read-Modify-Write ZeroPage operations take a full 7 cycles
}

// FIXME: Should emulate all reads and writes for RMW
- (void)_performOperationAsRMWZeroPage:(uint8_t)opcode
{
	uint8_t offset = _readByteFromCPUAddressSpace(self,@selector(readByteFromCPUAddressSpace:),_cpuRegisters->programCounter++);
	_zeroPage[offset] = _writeOperations[opcode](_cpuRegisters,_zeroPage[offset]);
	
	_cpuRegisters->cycle += 5; // Read-Modify-Write ZeroPage operations take 5 cycles
}

- (void)_performOperationAsRMWZeroPageX:(uint8_t)opcode
{
	uint8_t offset = _readByteFromCPUAddressSpace(self,@selector(readByteFromCPUAddressSpace:),_cpuRegisters->programCounter++) + _cpuRegisters->indexRegisterX;
	_zeroPage[offset] = _writeOperations[opcode](_cpuRegisters,_zeroPage[offset]);
	
	_cpuRegisters->cycle += 6; // Read-Modify-Write ZeroPage Indexed operations take 6 cycles
}

- (void)_performClearCarry:(uint8_t)opcode
{
	_cpuRegisters->statusCarry = 0;
	
	_cpuRegisters->cycle += 2;
}

- (void)_performSetCarry:(uint8_t)opcode
{
	_cpuRegisters->statusCarry = 1;
	
	_cpuRegisters->cycle += 2;
}

- (void)_performClearInterrupt:(uint8_t)opcode
{
	_cpuRegisters->statusIRQDisable = 0;
	
	_cpuRegisters->cycle += 2;
}

- (void)_performSetInterrupt:(uint8_t)opcode
{
	_cpuRegisters->statusIRQDisable = 1;
	
	_cpuRegisters->cycle += 2;
}

- (void)_performClearOverflow:(uint8_t)opcode
{
	_cpuRegisters->statusOverflow = 0;
	
	_cpuRegisters->cycle += 2;
}

- (void)_performClearDecimal:(uint8_t)opcode
{
	_cpuRegisters->statusDecimal = 0;
	
	_cpuRegisters->cycle += 2;
}

- (void)_performSetDecimal:(uint8_t)opcode
{
	_cpuRegisters->statusDecimal = 1;
	
	_cpuRegisters->cycle += 2;
}

/*
 * TSX
 */
- (void)_transferStackPointerToIndexRegisterX:(uint8_t)opcode
{
	_cpuRegisters->indexRegisterX = _cpuRegisters->stackPointer;
	_cpuRegisters->statusNegative = (_cpuRegisters->indexRegisterX >> 7);
	_cpuRegisters->statusZero = !_cpuRegisters->indexRegisterX;
	
	_cpuRegisters->cycle += 2;
}

/*
 * TXS
 */
- (void)_transferIndexRegisterXToStackPointer:(uint8_t)opcode
{
	_cpuRegisters->stackPointer = _cpuRegisters->indexRegisterX;
	
	_cpuRegisters->cycle += 2;
}

/*
 * TAX
 */
- (void)_transferAccumulatorToIndexRegisterX:(uint8_t)opcode
{
	_cpuRegisters->indexRegisterX = _cpuRegisters->accumulator;
	_cpuRegisters->statusNegative = (_cpuRegisters->accumulator >> 7);
	_cpuRegisters->statusZero = !_cpuRegisters->accumulator;
	
	_cpuRegisters->cycle += 2;
}

/*
 * TXA
 */
- (void)_transferIndexRegisterXToAccumulator:(uint8_t)opcode
{
	_cpuRegisters->accumulator = _cpuRegisters->indexRegisterX;
	_cpuRegisters->statusNegative = (_cpuRegisters->indexRegisterX >> 7);
	_cpuRegisters->statusZero = !_cpuRegisters->indexRegisterX;
	
	_cpuRegisters->cycle += 2;
}

/*
 * TAY
 */
- (void)_transferAccumulatorToIndexRegisterY:(uint8_t)opcode
{
	_cpuRegisters->indexRegisterY = _cpuRegisters->accumulator;
	_cpuRegisters->statusNegative = (_cpuRegisters->accumulator >> 7);
	_cpuRegisters->statusZero = !_cpuRegisters->accumulator;
	
	_cpuRegisters->cycle += 2;
}

/*
 * TYA
 */
- (void)_transferIndexRegisterYToAccumulator:(uint8_t)opcode
{
	_cpuRegisters->accumulator = _cpuRegisters->indexRegisterY;
	_cpuRegisters->statusNegative = (_cpuRegisters->indexRegisterY >> 7);
	_cpuRegisters->statusZero = !_cpuRegisters->indexRegisterY;
	
	_cpuRegisters->cycle += 2;
}

/*
 * DEX
 */
- (void)_decrementIndexRegisterX:(uint8_t)opcode
{
	_cpuRegisters->indexRegisterX--;
	_cpuRegisters->statusNegative = (_cpuRegisters->indexRegisterX >> 7);
	_cpuRegisters->statusZero = !_cpuRegisters->indexRegisterX;
	
	_cpuRegisters->cycle += 2;
}

/*
 * INX
 */
- (void)_incrementIndexRegisterX:(uint8_t)opcode
{
	_cpuRegisters->indexRegisterX++;
	_cpuRegisters->statusNegative = (_cpuRegisters->indexRegisterX >> 7);
	_cpuRegisters->statusZero = !_cpuRegisters->indexRegisterX;
	
	_cpuRegisters->cycle += 2;
}

/*
 * DEY
 */
- (void)_decrementIndexRegisterY:(uint8_t)opcode
{
	_cpuRegisters->indexRegisterY--;
	_cpuRegisters->statusNegative = (_cpuRegisters->indexRegisterY >> 7);
	_cpuRegisters->statusZero = !_cpuRegisters->indexRegisterY;
	
	_cpuRegisters->cycle += 2;
}

/*
 * INY
 */
- (void)_incrementIndexRegisterY:(uint8_t)opcode
{
	_cpuRegisters->indexRegisterY++;
	_cpuRegisters->statusNegative = (_cpuRegisters->indexRegisterY >> 7);
	_cpuRegisters->statusZero = !_cpuRegisters->indexRegisterY;
	
	_cpuRegisters->cycle += 2;
}

/* Branching Instructions
 *
 * BPL, BMI, BVC, BVS, BCC, BCS, BNE, BEQ
 */
- (void)_performBranchOnPositive:(uint8_t)opcode
{
	uint16_t oldProgramCounter = _cpuRegisters->programCounter + 1; // Page crossing occurs if branch destination is on a page other than that of the next opcode
	_cpuRegisters->programCounter += _cpuRegisters->statusNegative ? 1 : (int8_t)_readByteFromCPUAddressSpace(self,@selector(readByteFromCPUAddressSpace:),_cpuRegisters->programCounter) + 1 ;
	
	_cpuRegisters->cycle += (_cpuRegisters->statusNegative ? 2 : (3 + ((oldProgramCounter >> 8) != (_cpuRegisters->programCounter >> 8) ? 1 : 0)));
}

- (void)_performBranchOnNegative:(uint8_t)opcode
{
	uint16_t oldProgramCounter = _cpuRegisters->programCounter + 1; // Page crossing occurs if branch destination is on a page other than that of the next opcode
	_cpuRegisters->programCounter += _cpuRegisters->statusNegative ? (int8_t)_readByteFromCPUAddressSpace(self,@selector(readByteFromCPUAddressSpace:),_cpuRegisters->programCounter) + 1 : 1;
	
	_cpuRegisters->cycle += (_cpuRegisters->statusNegative ? (3 + ((oldProgramCounter >> 8) != (_cpuRegisters->programCounter >> 8) ? 1 : 0)) : 2);
}

- (void)_performBranchOnOverflowSet:(uint8_t)opcode
{
	uint16_t oldProgramCounter = _cpuRegisters->programCounter + 1; // Page crossing occurs if branch destination is on a page other than that of the next opcode
	_cpuRegisters->programCounter += _cpuRegisters->statusOverflow ? (int8_t)_readByteFromCPUAddressSpace(self,@selector(readByteFromCPUAddressSpace:),_cpuRegisters->programCounter) + 1 : 1;
	
	_cpuRegisters->cycle += (_cpuRegisters->statusOverflow ? (3 + ((oldProgramCounter >> 8) != (_cpuRegisters->programCounter >> 8) ? 1 : 0)) : 2);
}

- (void)_performBranchOnOverflowClear:(uint8_t)opcode
{
	uint16_t oldProgramCounter = _cpuRegisters->programCounter + 1; // Page crossing occurs if branch destination is on a page other than that of the next opcode
	_cpuRegisters->programCounter += _cpuRegisters->statusOverflow ? 1 : (int8_t)_readByteFromCPUAddressSpace(self,@selector(readByteFromCPUAddressSpace:),_cpuRegisters->programCounter) + 1;
	
	_cpuRegisters->cycle += (_cpuRegisters->statusOverflow ? 2 : (3 + ((oldProgramCounter >> 8) != (_cpuRegisters->programCounter >> 8) ? 1 : 0)));
}

- (void)_performBranchOnCarrySet:(uint8_t)opcode
{
	uint16_t oldProgramCounter = _cpuRegisters->programCounter + 1; // Page crossing occurs if branch destination is on a page other than that of the next opcode
	_cpuRegisters->programCounter += _cpuRegisters->statusCarry ? (int8_t)_readByteFromCPUAddressSpace(self,@selector(readByteFromCPUAddressSpace:),_cpuRegisters->programCounter) + 1 : 1;
	
	_cpuRegisters->cycle += (_cpuRegisters->statusCarry ? (3 + ((oldProgramCounter >> 8) != (_cpuRegisters->programCounter >> 8) ? 1 : 0)) : 2);
}

- (void)_performBranchOnCarryClear:(uint8_t)opcode
{
	uint16_t oldProgramCounter = _cpuRegisters->programCounter + 1; // Page crossing occurs if branch destination is on a page other than that of the next opcode
	_cpuRegisters->programCounter += _cpuRegisters->statusCarry ? 1 : (int8_t)_readByteFromCPUAddressSpace(self,@selector(readByteFromCPUAddressSpace:),_cpuRegisters->programCounter) + 1;
	
	_cpuRegisters->cycle += (_cpuRegisters->statusCarry ? 2 : (3 + ((oldProgramCounter >> 8) != (_cpuRegisters->programCounter >> 8) ? 1 : 0)));
}

- (void)_performBranchOnZeroSet:(uint8_t)opcode
{
	uint16_t oldProgramCounter = _cpuRegisters->programCounter + 1; // Page crossing occurs if branch destination is on a page other than that of the next opcode
	_cpuRegisters->programCounter += _cpuRegisters->statusZero ? (int8_t)_readByteFromCPUAddressSpace(self,@selector(readByteFromCPUAddressSpace:),_cpuRegisters->programCounter) + 1 : 1;
	
	_cpuRegisters->cycle += (_cpuRegisters->statusZero ? (3 + ((oldProgramCounter >> 8) != (_cpuRegisters->programCounter >> 8) ? 1 : 0)) : 2);
}

- (void)_performBranchOnZeroClear:(uint8_t)opcode
{
	uint16_t oldProgramCounter = _cpuRegisters->programCounter + 1; // Page crossing occurs if branch destination is on a page other than that of the next opcode
	_cpuRegisters->programCounter += _cpuRegisters->statusZero ? 1 : (int8_t)_readByteFromCPUAddressSpace(self,@selector(readByteFromCPUAddressSpace:),_cpuRegisters->programCounter) + 1;
	
	_cpuRegisters->cycle += (_cpuRegisters->statusZero ? 2 : (3 + ((oldProgramCounter >> 8) != (_cpuRegisters->programCounter >> 8) ? 1 : 0)));
}

- (void)_performAbsoluteJump:(uint8_t)opcode
{
	uint16_t newProgramCounter = _readByteFromCPUAddressSpace(self,@selector(readByteFromCPUAddressSpace:),_cpuRegisters->programCounter++); // Read new PCL
	newProgramCounter += (_readByteFromCPUAddressSpace(self,@selector(readByteFromCPUAddressSpace:),_cpuRegisters->programCounter++) << 8); // add new PCH
	_cpuRegisters->programCounter = newProgramCounter; // Set new Program Counter
	
	_cpuRegisters->cycle += 3;
}

/* JMP Indirect
 * Additional code is introduced here to implement a 6502 bug. If the indirect vector of JMP begins on the last byte of a page then 
 * the fetch  of the second will erroneously occur within the page containing the first byte.
 */
- (void)_performIndirectJump:(uint8_t)opcode
{
	uint16_t offset = 0;
	uint8_t offsetLowByte = _readByteFromCPUAddressSpace(self,@selector(readByteFromCPUAddressSpace:),_cpuRegisters->programCounter++); // Low byte of address of new PC
	offset = (_readByteFromCPUAddressSpace(self,@selector(readByteFromCPUAddressSpace:),_cpuRegisters->programCounter++) << 8); // High byte of address of new PC
	_cpuRegisters->programCounter = _readByteFromCPUAddressSpace(self,@selector(readByteFromCPUAddressSpace:),(offset | offsetLowByte)); // Load low byte of new PC into PC
	_cpuRegisters->programCounter += (_readByteFromCPUAddressSpace(self,@selector(readByteFromCPUAddressSpace:),(offset | ((uint8_t)(offsetLowByte + 1)))) << 8); // Increment low byte before odding with high byte to allow overflow
	
	_cpuRegisters->cycle += 5;
}

- (void)_performJumpToSubroutine:(uint8_t)opcode
{
	uint16_t oldProgramCounter = _cpuRegisters->programCounter;
	_cpuRegisters->programCounter = _readByteFromCPUAddressSpace(self,@selector(readByteFromCPUAddressSpace:),oldProgramCounter++);
	_cpuRegisters->programCounter += (_readByteFromCPUAddressSpace(self,@selector(readByteFromCPUAddressSpace:),oldProgramCounter) << 8); // Don't increment PC so last byte of JSR add is on stack
	_stack[_cpuRegisters->stackPointer--] = (oldProgramCounter >> 8); // store program counter high byte on stack
	_stack[_cpuRegisters->stackPointer--] = oldProgramCounter; // store program counter low byte on stack
	
	_cpuRegisters->cycle += 6;
}

- (void)_performReturnFromSubroutine:(uint8_t)opcode
{
	uint16_t newProgramCounter = _stack[++(_cpuRegisters->stackPointer)];
	newProgramCounter += (_stack[++(_cpuRegisters->stackPointer)] << 8);
	_cpuRegisters->programCounter = newProgramCounter + 1; // Add one to look past the second byte of the address stored from JSR
	
	_cpuRegisters->cycle += 6;
}

- (void)_performNoOperation:(uint8_t)opcode
{
	_cpuRegisters->cycle += 2;
}

- (void)_pushAccumulatorToStack:(uint8_t)opcode
{
	_stack[_cpuRegisters->stackPointer--] = _cpuRegisters->accumulator;
	
	_cpuRegisters->cycle += 3;
}

- (void)_popAccumulatorFromStack:(uint8_t)opcode
{
	_cpuRegisters->accumulator = _stack[++(_cpuRegisters->stackPointer)];
	_cpuRegisters->statusZero = !_cpuRegisters->accumulator;
	_cpuRegisters->statusNegative = _cpuRegisters->accumulator >> 7;
	
	_cpuRegisters->cycle += 4;
}

- (void)_pushProcessorStatusToStack:(uint8_t)opcode
{
	uint8_t processorStatusByte = (1 << 5);
	// The fake break flag value pushed is 1 for PHP/BRK and 0 for IRQ/NMI:
	// http://www.6502.org/tutorials/register_preservation.html
	// See also http://nesdev.parodius.com/the%20'B'%20flag%20&%20BRK%20instruction.txt
	
	if (opcode == 0x08) {
		
		_cpuRegisters->statusBreak = 1; // If this is invoked as PHP directly, set the break flag
		_cpuRegisters->cycle += 3; // and add three cycles
	}
	
	processorStatusByte |= (_cpuRegisters->statusNegative << 7);
	processorStatusByte |= (_cpuRegisters->statusOverflow << 6);
	processorStatusByte |= (_cpuRegisters->statusBreak << 4);
	processorStatusByte |= (_cpuRegisters->statusDecimal << 3);
	processorStatusByte |= (_cpuRegisters->statusIRQDisable << 2);
	processorStatusByte |= (_cpuRegisters->statusZero << 1);
	processorStatusByte |= _cpuRegisters->statusCarry;
	_stack[_cpuRegisters->stackPointer--] = processorStatusByte;
}

- (void)_popProcessorStatusFromStack:(uint8_t)opcode
{
	uint8_t processorStatusByte = _stack[++(_cpuRegisters->stackPointer)];
	_cpuRegisters->statusNegative = processorStatusByte >> 7;
	_cpuRegisters->statusOverflow = (processorStatusByte & (1 << 6)) >> 6;
	_cpuRegisters->statusBreak = (processorStatusByte & (1 << 4)) >> 4;
	_cpuRegisters->statusDecimal = (processorStatusByte & (1 << 3)) >> 3;
	_cpuRegisters->statusIRQDisable = (processorStatusByte & (1 << 2)) >> 2;
	_cpuRegisters->statusZero = (processorStatusByte & (1 << 1)) >> 1;
	_cpuRegisters->statusCarry = processorStatusByte & 1;
	
	if (opcode == 0x28) _cpuRegisters->cycle += 4; // Only add time if this was invokved by PLP
}

- (void)_performReturnFromInterrupt:(uint8_t)opcode
{
	[self _popProcessorStatusFromStack:0xff];
	_cpuRegisters->programCounter = _stack[++(_cpuRegisters->stackPointer)];
	_cpuRegisters->programCounter |= (_stack[++(_cpuRegisters->stackPointer)] << 8);
	
	_cpuRegisters->cycle += 6;
}

- (void)_performBreak:(uint8_t)opcode
{
	// Brad Taylor is correct in stating that BRK is actually a two-byte opcode, the second being padding - http://nesdev.parodius.com/the%20'B'%20flag%20&%20BRK%20instruction.txt
	_cpuRegisters->statusBreak = 1;
	_cpuRegisters->programCounter++; // Increment the program counter here to account for padding byte read
	_stack[_cpuRegisters->stackPointer--] = (_cpuRegisters->programCounter >> 8); // store program counter high byte on stack
	_stack[_cpuRegisters->stackPointer--] = _cpuRegisters->programCounter; // store program counter low byte on stack
	[self _pushProcessorStatusToStack:opcode]; // Finally, push the processor status register to the stack
	_cpuRegisters->programCounter = [self readAddressFromCPUAddressSpace:0xfffe];
	_cpuRegisters->statusIRQDisable = 1;
	
	_cpuRegisters->cycle += 7;
}

- (void)_performInterrupt
{
	_cpuRegisters->statusBreak = 0; // Interrupt clears the break flag http://www.6502.org/tutorials/register_preservation.html
	_stack[_cpuRegisters->stackPointer--] = (_cpuRegisters->programCounter >> 8); // store program counter high byte on stack
	_stack[_cpuRegisters->stackPointer--] = _cpuRegisters->programCounter; // store program counter low byte on stack
	[self _pushProcessorStatusToStack:0xff]; // Finally, push the processor status register to the stack
	_cpuRegisters->programCounter = [self readAddressFromCPUAddressSpace:0xfffe];
	_cpuRegisters->statusIRQDisable = 1;
	
	_cpuRegisters->cycle += 7;
}

- (void)_performNonMaskableInterrupt
{
	_cpuRegisters->statusBreak = 0; // Break is not set for NMI http://www.6502.org/tutorials/register_preservation.html
	_stack[_cpuRegisters->stackPointer--] = (_cpuRegisters->programCounter >> 8); // store program counter high byte on stack
	_stack[_cpuRegisters->stackPointer--] = _cpuRegisters->programCounter; // store program counter low byte on stack
	[self _pushProcessorStatusToStack:0xff]; // Finally, push the processor status register to the stack
	_cpuRegisters->programCounter = [self readAddressFromCPUAddressSpace:0xfffa];
	_cpuRegisters->statusIRQDisable = 1;
	
	_cpuRegisters->cycle += 7;
}

- (id)initWithPPU:(NESPPUEmulator *)ppuEmu andAPU:(NESAPUEmulator *)apuEmu {

	[super init];
	
	cartridge = nil;
	ppu = ppuEmu; // Non-retained reference;
	apu = apuEmu; // Non-retained reference;
	
	_controllers = (uint_fast32_t *)malloc(sizeof(uint_fast32_t)*2);
	_cpuRegisters = (CPURegisters *)malloc(sizeof(CPURegisters));
	_zeroPage = (uint8_t *)malloc(sizeof(uint8_t)*2048);
	_stack = _zeroPage + 256;
	_cpuRAM = _stack + 256;
	_operationMethods = (OperationMethodPointer *)malloc(sizeof(void (*)(id, SEL, uint8_t))*256);
	_operationSelectors = (SEL *)malloc(sizeof(SEL)*256);
	_standardOperations = (StandardOpPointer *)malloc(sizeof(void (*)(CPURegisters *,uint8_t))*256);
	_writeOperations = (WriteOpPointer *)malloc(sizeof(uint8_t (*)(CPURegisters *,uint8_t))*256);
	
	[self _clearRegisters];
	[self _clearCPUMemory];
	[self _clearStatus];
		
	// Load valid method pointers
	_operationMethods[0x00] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performBreak:)]; // BRK
	_operationSelectors[0x00] = @selector(_performBreak:);
	_operationMethods[0x01] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsIndirectX:)]; // ORA Indirect,X
	_operationSelectors[0x01] = @selector(_performOperationAsIndirectX:);
	_standardOperations[0x01] = (void (*)(CPURegisters *,uint8_t))_ORA;
	_operationMethods[0x02] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationSelectors[0x02] = @selector(_unsupportedOpcode:);
	_operationMethods[0x03] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationSelectors[0x03] = @selector(_unsupportedOpcode:);
	_operationMethods[0x04] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationSelectors[0x04] = @selector(_unsupportedOpcode:);
	_operationMethods[0x05] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsZeroPage:)]; // ORA ZeroPage
	_standardOperations[0x05] = (void (*)(CPURegisters *,uint8_t))_ORA;
	_operationMethods[0x06] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsRMWZeroPage:)]; // ASL ZeroPage
	_writeOperations[0x06] = (uint8_t (*)(CPURegisters *,uint8_t))_ASL_RMW;
	_operationMethods[0x07] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x08] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_pushProcessorStatusToStack:)]; // PHP
	_operationMethods[0x09] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsImmediate:)]; // ORA Immediate
	_standardOperations[0x09] = (void (*)(CPURegisters *,uint8_t))_ORA;
	_operationMethods[0x0A] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performImpliedOperation:)]; // ASL Accumulator
	_standardOperations[0x0A] = (void (*)(CPURegisters *,uint8_t))_ASL;
	_operationMethods[0x0B] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x0C] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x0D] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsAbsolute:)]; // ORA Absolute
	_standardOperations[0x0D] = (void (*)(CPURegisters *,uint8_t))_ORA;
	_operationMethods[0x0E] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsRMWAbsolute:)]; // ASL Absolute
	_writeOperations[0x0E] = (uint8_t (*)(CPURegisters *,uint8_t))_ASL_RMW;
	_operationMethods[0x0F] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x10] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performBranchOnPositive:)]; // BPL
	_operationMethods[0x11] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsIndirectY:)]; // ORA Indirect,Y
	_standardOperations[0x11] = (void (*)(CPURegisters *,uint8_t))_ORA;
	_operationMethods[0x12] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x13] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x14] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x15] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsZeroPageX:)]; // ORA ZeroPage,X
	_standardOperations[0x15] = (void (*)(CPURegisters *,uint8_t))_ORA;
	_operationMethods[0x16] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsRMWZeroPageX:)]; // ASL ZeroPage,X
	_writeOperations[0x16] = (uint8_t (*)(CPURegisters *,uint8_t))_ASL_RMW;
	_operationMethods[0x17] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x18] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performClearCarry:)]; // CLC
	_operationMethods[0x19] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsAbsoluteY:)]; // ORA Absolute,Y
	_standardOperations[0x19] = (void (*)(CPURegisters *,uint8_t))_ORA;
	_operationMethods[0x1A] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performNoOperation:)]; // NOP
	_operationMethods[0x1B] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x1C] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x1D] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsAbsoluteX:)]; // ORA Absolute,X
	_standardOperations[0x1D] = (void (*)(CPURegisters *,uint8_t))_ORA;
	_operationMethods[0x1E] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsRMWAbsoluteX:)]; // ASL Absolute,X
	_writeOperations[0x1E] = (uint8_t (*)(CPURegisters *,uint8_t))_ASL_RMW;
	_operationMethods[0x1F] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x20] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performJumpToSubroutine:)]; // JSR
	_operationMethods[0x21] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsIndirectX:)]; // AND Indirect,X
	_standardOperations[0x21] = (void (*)(CPURegisters *,uint8_t))_AND;
	_operationMethods[0x22] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x23] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x24] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsZeroPage:)]; // BIT ZeroPage
	_standardOperations[0x24] = (void (*)(CPURegisters *,uint8_t))_BIT;
	_operationMethods[0x25] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsZeroPage:)]; // AND ZeroPage
	_standardOperations[0x25] = (void (*)(CPURegisters *,uint8_t))_AND;
	_operationMethods[0x26] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsRMWZeroPage:)]; // ROL ZeroPage
	_writeOperations[0x26] = (uint8_t (*)(CPURegisters *,uint8_t))_ROL_RMW;
	_operationMethods[0x27] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x28] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_popProcessorStatusFromStack:)]; // PLP
	_operationMethods[0x29] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsImmediate:)]; // AND Immediate
	_standardOperations[0x29] = (void (*)(CPURegisters *,uint8_t))_AND;
	_operationMethods[0x2A] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performImpliedOperation:)]; // ROL Accumulator
	_standardOperations[0x2A] = (void (*)(CPURegisters *,uint8_t))_ROL;
	_operationMethods[0x2B] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x2C] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsAbsolute:)]; // BIT Absolute
	_standardOperations[0x2C] = (void (*)(CPURegisters *,uint8_t))_BIT;
	_operationMethods[0x2D] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsAbsolute:)]; // AND Absolute
	_standardOperations[0x2D] = (void (*)(CPURegisters *,uint8_t))_AND;
	_operationMethods[0x2E] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsRMWAbsolute:)]; // ROL Absolute
	_writeOperations[0x2E] = (uint8_t (*)(CPURegisters *,uint8_t))_ROL_RMW;
	_operationMethods[0x2F] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x30] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performBranchOnNegative:)]; // BMI
	_operationMethods[0x31] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsIndirectY:)]; // AND Indirect,Y
	_standardOperations[0x31] = (void (*)(CPURegisters *,uint8_t))_AND;
	_operationMethods[0x32] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x33] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x34] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x35] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsZeroPageX:)]; // AND ZeroPage,X
	_standardOperations[0x35] = (void (*)(CPURegisters *,uint8_t))_AND;
	_operationMethods[0x36] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsRMWZeroPageX:)]; // ROL ZeroPage,X
	_writeOperations[0x36] = (uint8_t (*)(CPURegisters *,uint8_t))_ROL_RMW;
	_operationMethods[0x37] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x38] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performSetCarry:)]; // SEC
	_operationMethods[0x39] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsAbsoluteY:)]; // AND Absolute,Y
	_standardOperations[0x39] = (void (*)(CPURegisters *,uint8_t))_AND;
	_operationMethods[0x3A] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performNoOperation:)]; // NOP
	_operationMethods[0x3B] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x3C] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x3D] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsAbsoluteX:)]; // AND Absolute,X
	_standardOperations[0x3D] = (void (*)(CPURegisters *,uint8_t))_AND;
	_operationMethods[0x3E] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsRMWAbsoluteX:)]; // ROL Absolute,X
	_writeOperations[0x3E] = (uint8_t (*)(CPURegisters *,uint8_t))_ROL_RMW;
	_operationMethods[0x3F] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x40] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performReturnFromInterrupt:)]; // RTI
	_operationMethods[0x41] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsIndirectX:)]; // EOR Indirect,X
	_standardOperations[0x41] = (void (*)(CPURegisters *,uint8_t))_EOR;
	_operationMethods[0x42] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x43] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x44] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x45] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsZeroPage:)]; // EOR ZeroPage
	_standardOperations[0x45] = (void (*)(CPURegisters *,uint8_t))_EOR;
	_operationMethods[0x46] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsRMWZeroPage:)]; // LSR ZeroPage
	_writeOperations[0x46] = (uint8_t (*)(CPURegisters *,uint8_t))_LSR_RMW;
	_operationMethods[0x47] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x48] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_pushAccumulatorToStack:)]; // PHA
	_operationMethods[0x49] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsImmediate:)]; // EOR Immediate
	_standardOperations[0x49] = (void (*)(CPURegisters *,uint8_t))_EOR;
	_operationMethods[0x4A] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performImpliedOperation:)]; // LSR Accumulator
	_standardOperations[0x4A] = (void (*)(CPURegisters *,uint8_t))_LSR;
	_operationMethods[0x4B] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x4C] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performAbsoluteJump:)]; // JMP Absolute
	_operationMethods[0x4D] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsAbsolute:)]; // EOR Absolute
	_standardOperations[0x4D] = (void (*)(CPURegisters *,uint8_t))_EOR;
	_operationMethods[0x4E] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsRMWAbsolute:)]; // LSR Absolute
	_writeOperations[0x4E] = (uint8_t (*)(CPURegisters *,uint8_t))_LSR_RMW;
	_operationMethods[0x4F] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x50] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performBranchOnOverflowClear:)]; // BVC
	_operationMethods[0x51] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsIndirectY:)]; // EOR Indirect,Y
	_standardOperations[0x51] = (void (*)(CPURegisters *,uint8_t))_EOR;
	_operationMethods[0x52] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x53] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x54] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x55] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsZeroPageX:)]; // EOR ZeroPage,X
	_standardOperations[0x55] = (void (*)(CPURegisters *,uint8_t))_EOR;
	_operationMethods[0x56] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsRMWZeroPageX:)]; // LSR ZeroPage,X
	_writeOperations[0x56] = (uint8_t (*)(CPURegisters *,uint8_t))_LSR_RMW;
	_operationMethods[0x57] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x58] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performClearInterrupt:)]; // CLI
	_operationMethods[0x59] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsAbsoluteY:)]; // EOR Absolute,Y
	_standardOperations[0x59] = (void (*)(CPURegisters *,uint8_t))_EOR;
	_operationMethods[0x5A] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performNoOperation:)]; // NOP
	_operationMethods[0x5B] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x5C] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x5D] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsAbsoluteX:)]; // EOR Absolute,X
	_standardOperations[0x5D] = (void (*)(CPURegisters *,uint8_t))_EOR;
	_operationMethods[0x5E] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsRMWAbsoluteX:)]; // LSR Absolute,X
	_writeOperations[0x5E] = (uint8_t (*)(CPURegisters *,uint8_t))_LSR_RMW;
	_operationMethods[0x5F] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x60] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performReturnFromSubroutine:)]; // RTS
	_operationMethods[0x61] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsIndirectX:)]; // ADC Indirect,X
	_standardOperations[0x61] = (void (*)(CPURegisters *,uint8_t))_ADC;
	_operationMethods[0x62] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x63] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x64] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x65] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsZeroPage:)]; // ADC ZeroPage
	_standardOperations[0x65] = (void (*)(CPURegisters *,uint8_t))_ADC;
	_operationMethods[0x66] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsRMWZeroPage:)]; // ROR ZeroPage
	_writeOperations[0x66] = (uint8_t (*)(CPURegisters *,uint8_t))_ROR_RMW;
	_operationMethods[0x67] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x68] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_popAccumulatorFromStack:)]; // PLA
	_operationMethods[0x69] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsImmediate:)]; // ADC Immediate
	_standardOperations[0x69] = (void (*)(CPURegisters *,uint8_t))_ADC;
	_operationMethods[0x6A] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performImpliedOperation:)]; // ROR Accumulator
	_standardOperations[0x6A] = (void (*)(CPURegisters *,uint8_t))_ROR;
	_operationMethods[0x6B] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x6C] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performIndirectJump:)]; // JMP Indirect
	_operationMethods[0x6D] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsAbsolute:)]; // ADC Absolute
	_standardOperations[0x6D] = (void (*)(CPURegisters *,uint8_t))_ADC;
	_operationMethods[0x6E] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsRMWAbsolute:)]; // ROR Absolute
	_writeOperations[0x6E] = (uint8_t (*)(CPURegisters *,uint8_t))_ROR_RMW;
	_operationMethods[0x6F] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x70] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performBranchOnOverflowSet:)]; // BVS
	_operationMethods[0x71] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsIndirectY:)]; // ADC Indirect,Y
	_standardOperations[0x71] = (void (*)(CPURegisters *,uint8_t))_ADC;
	_operationMethods[0x72] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x73] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x74] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x75] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsZeroPageX:)]; // ADC ZeroPage,X
	_standardOperations[0x75] = (void (*)(CPURegisters *,uint8_t))_ADC;
	_operationMethods[0x76] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsRMWZeroPageX:)]; // ROR ZeroPage,X
	_writeOperations[0x76] = (uint8_t (*)(CPURegisters *,uint8_t))_ROR_RMW;
	_operationMethods[0x77] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x78] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performSetInterrupt:)]; // SEI
	_operationMethods[0x79] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsAbsoluteY:)]; // ADC Absolute,Y
	_standardOperations[0x79] = (void (*)(CPURegisters *,uint8_t))_ADC;
	_operationMethods[0x7A] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performNoOperation:)]; // NOP
	_operationMethods[0x7B] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x7C] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x7D] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsAbsoluteX:)]; // ADC Absolute,X
	_standardOperations[0x7D] = (void (*)(CPURegisters *,uint8_t))_ADC;
	_operationMethods[0x7E] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsRMWAbsoluteX:)]; // ROR Absolute,X
	_writeOperations[0x7E] = (uint8_t (*)(CPURegisters *,uint8_t))_ROR_RMW;
	_operationMethods[0x7F] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x80] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x81] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performWriteOperationWithIndirectX:)]; // STA Indirect,X
	_writeOperations[0x81] = (uint8_t (*)(CPURegisters *,uint8_t))_GetAccumulator;
	_operationMethods[0x82] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x83] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x84] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performWriteOperationWithZeroPage:)]; // STY ZeroPage
	_writeOperations[0x84] = (uint8_t (*)(CPURegisters *,uint8_t))_GetIndexRegisterY;
	_operationMethods[0x85] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performWriteOperationWithZeroPage:)]; // STA ZeroPage
	_writeOperations[0x85] = (uint8_t (*)(CPURegisters *,uint8_t))_GetAccumulator;
	_operationMethods[0x86] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performWriteOperationWithZeroPage:)]; // STX ZeroPage
	_writeOperations[0x86] = (uint8_t (*)(CPURegisters *,uint8_t))_GetIndexRegisterX;
	_operationMethods[0x87] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x88] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_decrementIndexRegisterY:)]; // DEY
	_operationMethods[0x89] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x8A] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_transferIndexRegisterXToAccumulator:)]; // TXA
	_operationMethods[0x8B] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x8C] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performWriteOperationWithAbsolute:)]; // STY Absolute
	_writeOperations[0x8C] = (uint8_t (*)(CPURegisters *,uint8_t))_GetIndexRegisterY;
	_operationMethods[0x8D] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performWriteOperationWithAbsolute:)]; // STA Absolute
	_writeOperations[0x8D] = (uint8_t (*)(CPURegisters *,uint8_t))_GetAccumulator;
	_operationMethods[0x8E] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performWriteOperationWithAbsolute:)]; // STX Absolute
	_writeOperations[0x8E] = (uint8_t (*)(CPURegisters *,uint8_t))_GetIndexRegisterX;
	_operationMethods[0x8F] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x90] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performBranchOnCarryClear:)]; // BCC
	_operationMethods[0x91] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performWriteOperationWithIndirectY:)]; // STA Indirect,Y
	_writeOperations[0x91] = (uint8_t (*)(CPURegisters *,uint8_t))_GetAccumulator;
	_operationMethods[0x92] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x93] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x94] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performWriteOperationWithZeroPageX:)]; // STY ZeroPage,X
	_writeOperations[0x94] = (uint8_t (*)(CPURegisters *,uint8_t))_GetIndexRegisterY;
	_operationMethods[0x95] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performWriteOperationWithZeroPageX:)]; // STA ZeroPage,X
	_writeOperations[0x95] = (uint8_t (*)(CPURegisters *,uint8_t))_GetAccumulator;
	_operationMethods[0x96] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performWriteOperationWithZeroPageY:)]; // STX ZeroPage,Y
	_writeOperations[0x96] = (uint8_t (*)(CPURegisters *,uint8_t))_GetIndexRegisterX;
	_operationMethods[0x97] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x98] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_transferIndexRegisterYToAccumulator:)]; // TYA
	_operationMethods[0x99] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performWriteOperationWithAbsoluteY:)]; // STA Absolute,Y
	_writeOperations[0x99] = (uint8_t (*)(CPURegisters *,uint8_t))_GetAccumulator;
	_operationMethods[0x9A] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_transferIndexRegisterXToStackPointer:)]; // TXS
	_operationMethods[0x9B] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x9C] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x9D] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performWriteOperationWithAbsoluteX:)]; // STA Absolute,X
	_writeOperations[0x9D] = (uint8_t (*)(CPURegisters *,uint8_t))_GetAccumulator;
	_operationMethods[0x9E] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0x9F] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0xA0] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsImmediate:)]; // LDY Immediate
	_standardOperations[0xA0] = (void (*)(CPURegisters *,uint8_t))_LDY;
	_operationMethods[0xA1] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsIndirectX:)]; // LDA Indirect,X
	_standardOperations[0xA1] = (void (*)(CPURegisters *,uint8_t))_LDA;
	_operationMethods[0xA2] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsImmediate:)]; // LDX Immediate
	_standardOperations[0xA2] = (void (*)(CPURegisters *,uint8_t))_LDX;
	_operationMethods[0xA3] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0xA4] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsZeroPage:)]; // LDY ZeroPage
	_standardOperations[0xA4] = (void (*)(CPURegisters *,uint8_t))_LDY;
	_operationMethods[0xA5] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsZeroPage:)]; // LDA ZeroPage
	_standardOperations[0xA5] = (void (*)(CPURegisters *,uint8_t))_LDA;
	_operationMethods[0xA6] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsZeroPage:)]; // LDX ZeroPage
	_standardOperations[0xA6] = (void (*)(CPURegisters *,uint8_t))_LDX;
	_operationMethods[0xA7] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0xA8] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_transferAccumulatorToIndexRegisterY:)]; // TAY
	_operationMethods[0xA9] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsImmediate:)]; // LDA Immediate
	_standardOperations[0xA9] = (void (*)(CPURegisters *,uint8_t))_LDA;
	_operationMethods[0xAA] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_transferAccumulatorToIndexRegisterX:)]; // TAX
	_operationMethods[0xAB] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0xAC] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsAbsolute:)]; // LDY Absolute
	_standardOperations[0xAC] = (void (*)(CPURegisters *,uint8_t))_LDY;
	_operationMethods[0xAD] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsAbsolute:)]; // LDA Absolute
	_standardOperations[0xAD] = (void (*)(CPURegisters *,uint8_t))_LDA;
	_operationMethods[0xAE] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsAbsolute:)]; // LDX Absolute
	_standardOperations[0xAE] = (void (*)(CPURegisters *,uint8_t))_LDX;
	_operationMethods[0xAF] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0xB0] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performBranchOnCarrySet:)]; // BCS
	_operationMethods[0xB1] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsIndirectY:)]; // LDA Indirect,Y
	_standardOperations[0xB1] = (void (*)(CPURegisters *,uint8_t))_LDA;
	_operationMethods[0xB2] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0xB3] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0xB4] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsZeroPageX:)]; // LDY ZeroPage,X
	_standardOperations[0xB4] = (void (*)(CPURegisters *,uint8_t))_LDY;
	_operationMethods[0xB5] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsZeroPageX:)]; // LDA ZeroPage,X
	_standardOperations[0xB5] = (void (*)(CPURegisters *,uint8_t))_LDA;
	_operationMethods[0xB6] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsZeroPageY:)]; // LDX ZeroPage,Y
	_standardOperations[0xB6] = (void (*)(CPURegisters *,uint8_t))_LDX;
	_operationMethods[0xB7] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0xB8] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performClearOverflow:)]; // CLV
	_operationMethods[0xB9] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsAbsoluteY:)]; // LDA Absolute,Y
	_standardOperations[0xB9] = (void (*)(CPURegisters *,uint8_t))_LDA;
	_operationMethods[0xBA] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_transferStackPointerToIndexRegisterX:)]; // TSX
	_operationMethods[0xBB] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0xBC] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsAbsoluteX:)]; // LDY Absolute,X
	_standardOperations[0xBC] = (void (*)(CPURegisters *,uint8_t))_LDY;
	_operationMethods[0xBD] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsAbsoluteX:)]; // LDA Absolute,X
	_standardOperations[0xBD] = (void (*)(CPURegisters *,uint8_t))_LDA;
	_operationMethods[0xBE] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsAbsoluteY:)]; // LDX Absolute,Y
	_standardOperations[0xBE] = (void (*)(CPURegisters *,uint8_t))_LDX;
	_operationMethods[0xBF] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0xC0] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsImmediate:)]; // CPY Immediate
	_standardOperations[0xC0] = (void (*)(CPURegisters *,uint8_t))_CPY;
	_operationMethods[0xC1] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsIndirectX:)]; // CMP Indirect,X
	_standardOperations[0xC1] = (void (*)(CPURegisters *,uint8_t))_CMP;
	_operationMethods[0xC2] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0xC3] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0xC4] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsZeroPage:)]; // CPY ZeroPage
	_standardOperations[0xC4] = (void (*)(CPURegisters *,uint8_t))_CPY;
	_operationMethods[0xC5] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsZeroPage:)]; // CMP ZeroPage
	_standardOperations[0xC5] = (void (*)(CPURegisters *,uint8_t))_CMP;
	_operationMethods[0xC6] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsRMWZeroPage:)]; // DEC ZeroPage
	_writeOperations[0xC6] = (uint8_t (*)(CPURegisters *,uint8_t))_DEC;
	_operationMethods[0xC7] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0xC8] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_incrementIndexRegisterY:)]; // INY
	_operationMethods[0xC9] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsImmediate:)]; // CMP Immediate
	_standardOperations[0xC9] = (void (*)(CPURegisters *,uint8_t))_CMP;
	_operationMethods[0xCA] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_decrementIndexRegisterX:)]; // DEX
	_operationMethods[0xCB] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0xCC] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsAbsolute:)]; // CPY Absolute
	_standardOperations[0xCC] = (void (*)(CPURegisters *,uint8_t))_CPY;
	_operationMethods[0xCD] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsAbsolute:)]; // CMP Absolute
	_standardOperations[0xCD] = (void (*)(CPURegisters *,uint8_t))_CMP;
	_operationMethods[0xCE] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsRMWAbsolute:)]; // DEC Absolute
	_writeOperations[0xCE] = (uint8_t (*)(CPURegisters *,uint8_t))_DEC;
	_operationMethods[0xCF] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0xD0] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performBranchOnZeroClear:)]; // BNE
	_operationMethods[0xD1] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsIndirectY:)]; // CMP Indirect,Y
	_standardOperations[0xD1] = (void (*)(CPURegisters *,uint8_t))_CMP;
	_operationMethods[0xD2] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0xD3] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0xD4] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0xD5] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsZeroPageX:)]; // CMP ZeroPage,X
	_standardOperations[0xD5] = (void (*)(CPURegisters *,uint8_t))_CMP;
	_operationMethods[0xD6] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsRMWZeroPageX:)]; // DEC ZeroPage,X
	_writeOperations[0xD6] = (uint8_t (*)(CPURegisters *,uint8_t))_DEC;
	_operationMethods[0xD7] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0xD8] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performClearDecimal:)]; // CLD
	_operationMethods[0xD9] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsAbsoluteY:)]; // CMP Absolute,Y
	_standardOperations[0xD9] = (void (*)(CPURegisters *,uint8_t))_CMP;
	_operationMethods[0xDA] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performNoOperation:)]; // NOP
	_operationMethods[0xDB] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0xDC] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0xDD] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsAbsoluteX:)]; // CMP Absolute,X
	_standardOperations[0xDD] = (void (*)(CPURegisters *,uint8_t))_CMP;
	_operationMethods[0xDE] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsRMWAbsoluteX:)]; // DEC Absolute,X
	_writeOperations[0xDE] = (uint8_t (*)(CPURegisters *,uint8_t))_DEC;
	_operationMethods[0xDF] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0xE0] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsImmediate:)]; // CPX Immediate
	_standardOperations[0xE0] = (void (*)(CPURegisters *,uint8_t))_CPX;
	_operationMethods[0xE1] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsIndirectX:)]; // SBC Indirect,X
	_standardOperations[0xE1] = (void (*)(CPURegisters *,uint8_t))_SBC;
	_operationMethods[0xE2] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0xE3] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0xE4] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsZeroPage:)]; // CPX ZeroPage
	_standardOperations[0xE4] = (void (*)(CPURegisters *,uint8_t))_CPX;
	_operationMethods[0xE5] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsZeroPage:)]; // SBC ZeroPage
	_standardOperations[0xE5] = (void (*)(CPURegisters *,uint8_t))_SBC;
	_operationMethods[0xE6] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsRMWZeroPage:)]; // INC ZeroPage
	_writeOperations[0xE6] = (uint8_t (*)(CPURegisters *,uint8_t))_INC;
	_operationMethods[0xE7] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0xE8] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_incrementIndexRegisterX:)]; // INX
	_operationMethods[0xE9] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsImmediate:)]; // SBC Immediate
	_standardOperations[0xE9] = (void (*)(CPURegisters *,uint8_t))_SBC;
	_operationMethods[0xEA] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performNoOperation:)]; // NOP
	_operationMethods[0xEB] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0xEC] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsAbsolute:)]; // CPX Absolute
	_standardOperations[0xEC] = (void (*)(CPURegisters *,uint8_t))_CPX;
	_operationMethods[0xED] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsAbsolute:)]; // SBC Absolute
	_standardOperations[0xED] = (void (*)(CPURegisters *,uint8_t))_SBC;
	_operationMethods[0xEE] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsRMWAbsolute:)]; // INC Absolute
	_writeOperations[0xEE] = (uint8_t (*)(CPURegisters *,uint8_t))_INC;
	_operationMethods[0xEF] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0xF0] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performBranchOnZeroSet:)]; // BEQ
	_operationMethods[0xF1] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsIndirectY:)]; // SBC Indirect,Y
	_standardOperations[0xF1] = (void (*)(CPURegisters *,uint8_t))_SBC;
	_operationMethods[0xF2] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0xF3] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0xF4] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0xF5] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsZeroPageX:)]; // SBC ZeroPage,X
	_standardOperations[0xF5] = (void (*)(CPURegisters *,uint8_t))_SBC;
	_operationMethods[0xF6] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsRMWZeroPageX:)]; // INC ZeroPage,X
	_writeOperations[0xF6] = (uint8_t (*)(CPURegisters *,uint8_t))_INC;
	_operationMethods[0xF7] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0xF8] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performSetDecimal:)]; // SED
	_operationMethods[0xF9] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsAbsoluteY:)]; // SBC Absolute,Y
	_standardOperations[0xF9] = (void (*)(CPURegisters *,uint8_t))_SBC;
	_operationMethods[0xFA] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performNoOperation:)]; // NOP
	_operationMethods[0xFB] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0xFC] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ???
	_operationMethods[0xFD] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsAbsoluteX:)]; // SBC Absolute,X
	_standardOperations[0xFD] = (void (*)(CPURegisters *,uint8_t))_SBC;
	_operationMethods[0xFE] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_performOperationAsRMWAbsoluteX:)]; // INC Absolute,X
	_writeOperations[0xFE] = (uint8_t (*)(CPURegisters *,uint8_t))_INC;
	_operationMethods[0xFF] = (void (*)(id, SEL, uint8_t))[self methodForSelector:@selector(_unsupportedOpcode:)]; // ??
	
	_readByteFromCPUAddressSpace = (uint8_t (*)(id, SEL, uint16_t))[self methodForSelector:@selector(readByteFromCPUAddressSpace:)];
	
	return self;
}

- (void)dealloc
{
	free(_cpuRegisters);
	free(_zeroPage); // FIXME: Current all memory below 0x2000 is allocated in the zeroPage
	free(_operationMethods);
	free(_operationSelectors);
	free(_standardOperations);
	free(_writeOperations);
	
	[super dealloc];
}

- (void)setCartridge:(NESCartridge *)cart
{
	[cart retain];
	if (cartridge != nil) [cartridge release];
	cartridge = cart;
	
	_prgromBankPointers = [cartridge prgromBankPointers];
	_wram = [cartridge wram]; // FIXME: This assumes we have WRAM, which isn't a great assumption.
}
 
- (void)reset
{
	[self _clearRegisters];
	[self _clearCPUMemory];
	[self _clearStatus];
	_cpuRegisters->programCounter = [self readAddressFromCPUAddressSpace:0xfffc];
	_cpuRegisters->cycle = 8;
}

- (uint16_t)breakPoint
{
	return breakPoint;
}

- (void)setBreakPoint:(uint16_t)counter
{
	breakPoint = counter;
}

- (void)setProgramCounter:(uint16_t)jump
{
	_cpuRegisters->programCounter = jump;
}

- (uint_fast32_t)executeUntilCycle:(uint_fast32_t)cycle 
{
	uint8_t opcode;
	
	while (_cpuRegisters->cycle < cycle) {
			
		if ([apu pendingDMCReadsOnCycle:_cpuRegisters->cycle]) {
			
			[apu runAPUUntilCPUCycle:_cpuRegisters->cycle];
		}
		else if ((_cpuRegisters->cycle >= _nextIRQ) && !_cpuRegisters->statusIRQDisable) {
		
			[self _performInterrupt];
			[cartridge servicedInterruptOnCycle:_cpuRegisters->cycle];
		}
		else {
			
			opcode = _readByteFromCPUAddressSpace(self,@selector(readByteFromCPUAddressSpace:),_cpuRegisters->programCounter++);
			_operationMethods[opcode](self,@selector(_unsupportedOpcode:),opcode); // Deliberately passing wrong SEL here, bbum says that's fine
		}
	}
	
	return _cpuRegisters->cycle;
}

- (void)resetCPUCycleCounter {
	
	if (_nextIRQ != NO_PENDING_IRQ) {
	
		if (_nextIRQ < _cpuRegisters->cycle) {
		
			// If there is a pending interrupt, set it for the beginning next frame
			_nextIRQ = 0;
		}
		else {
		
			// If the interrupt has yet to occur, set for the next frame
			_nextIRQ -= _cpuRegisters->cycle;
		}
	}
	
	_cpuRegisters->cycle = 0;
}

- (uint_fast32_t)executeUntilCycleWithBreak:(uint_fast32_t)cycle
{
	while ((_cpuRegisters->cycle < cycle) && (_cpuRegisters->programCounter != breakPoint)) [self interpretOpcode];

	[self setEncounteredBreakpoint:(_cpuRegisters->programCounter == breakPoint)];
	
	return _cpuRegisters->cycle;
}

- (uint_fast32_t)interpretOpcode
{
	uint8_t opcode;
	
	if ([apu pendingDMCReadsOnCycle:_cpuRegisters->cycle]) {
		
		[apu runAPUUntilCPUCycle:_cpuRegisters->cycle];
	}
	else if ((_cpuRegisters->cycle >= _nextIRQ) && !_cpuRegisters->statusIRQDisable) {
		
		[self _performInterrupt];
		[cartridge servicedInterruptOnCycle:_cpuRegisters->cycle];
	}
	else {
	
		opcode = _readByteFromCPUAddressSpace(self,@selector(readByteFromCPUAddressSpace:),_cpuRegisters->programCounter++);
		_operationMethods[opcode](self,@selector(_unsupportedOpcode:),opcode); // Deliberately passing wrong SEL here, I don't think this matters
	}
	
	return _cpuRegisters->cycle;
}

- (uint8_t)currentOpcode
{
	return _readByteFromCPUAddressSpace(self,@selector(readByteFromCPUAddressSpace:),_cpuRegisters->programCounter);
}

- (CPURegisters *)cpuRegisters
{
	return _cpuRegisters;
}

- (void)setData:(uint_fast32_t)data forController:(int)index;
{
	_controllers[index] = data;
}

- (void)stealCycles:(uint_fast32_t)cycles
{
	_cpuRegisters->cycle += cycles;
}

- (void)setNextIRQ:(uint_fast32_t)cycles
{
	if (cycles != NO_PENDING_IRQ) _nextIRQ = _cpuRegisters->cycle + cycles;
	else _nextIRQ = NO_PENDING_IRQ;
}

@end
