//
//  NESCoreEmulation.m
//  Innuendo
//
//  Created by Auston Stewart on 7/27/08.
//

#import "NESCoreEmulation.h"
#import "NES6502Interpreter.h"
#import "NESPPUEmulator.h"
#import "NESCartridgeEmulator.h"

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
													0, 1, 0, 0, 0, 1, 1, 0,
													0, 2, 0, 0, 0, 2, 2, 0,
													2, 1, 0, 0, 1, 1, 1, 0, 
													0, 1, 0, 0, 2, 2, 2, 0,
													0, 1, 0, 0, 0, 1, 1, 0,
													0, 2, 0, 0, 0, 2, 2, 0,
													0, 1, 0, 0, 1, 1, 1, 0,
													0, 1, 0, 0, 2, 2, 2, 0,
													0, 1, 0, 0, 0, 1, 1, 0,
													0, 2, 0, 0, 0, 2, 2, 0,
													0, 1, 0, 0, 0, 1, 1, 0,
													0, 1, 0, 0, 2, 2, 2, 0,
													0, 1, 0, 0, 0, 1, 1, 0,
													0, 2, 0, 0, 0, 2, 2, 0,
													0, 1, 0, 0, 1, 1, 1, 0,
													0, 0, 0, 0, 2, 2, 2, 0,
													0, 1, 0, 0, 1, 1, 1, 0,
													0, 2, 0, 0, 0, 2, 0, 0,
													1, 1, 1, 0, 1, 1, 1, 0,
													0, 1, 0, 0, 2, 2, 2, 0,
													0, 1, 0, 0, 1, 1, 1, 0,
													0, 2, 0, 0, 2, 2, 2, 0,
													1, 1, 0, 0, 1, 1, 1, 0,
													0, 1, 0, 0, 2, 2, 2, 0,
													0, 1, 0, 0, 0, 1, 1, 0,
													0, 2, 0, 0, 0, 2, 2, 0,
													1, 1, 0, 0, 1, 1, 1, 0,
													0, 1, 0, 0, 2, 2, 2, 0,
													0, 1, 0, 0, 0, 1, 1, 0,
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

@implementation NESCoreEmulation

- (id)initWithBuffer:(NSBitmapImageRep *)buffer
{
	[super init];
	
	ppuEmulator = [[NESPPUEmulator alloc] initWithBuffer:buffer];
	cartEmulator = [[NESCartridgeEmulator alloc] init];
	cpuInterpreter = [[NES6502Interpreter alloc] initWithCartridge:cartEmulator	andPPU:ppuEmulator];
	firstInstruction = 0;
	lastInstruction = 0;
	
	return self;
}

- (void)dealloc
{
	[cpuInterpreter release];
	[ppuEmulator release];
	[cartEmulator release];
	
	[super dealloc];
}

- (NES6502Interpreter *)cpu
{
	return cpuInterpreter;
}

- (NESPPUEmulator *)ppu
{
	return ppuEmulator;
}

- (NESCartridgeEmulator *)cartridge
{
	return cartEmulator;
}

- (uint_fast32_t)runUntilBreak
{
	return [cpuInterpreter executeUntilBreak];
}

/*
 printf("CPU Registers:\n");
 printf("Accumulator: %2.2x\n",registers->accumulator);
 printf("Index Register X: %2.2x\n",registers->indexRegisterX);
 printf("Index Register Y: %2.2x\n",registers->indexRegisterY);
 printf("Program Counter: %4.4x\n",registers->programCounter);
 printf("Stack Pointer: %2.2x\n",registers->stackPointer);
 printf("Carry: %d\t\tZero: %d\n",registers->statusCarry,registers->statusZero);
 printf("IRQ Off: %d\t\tDecimal: %d\n",registers->statusIRQDisable,registers->statusDecimal);
 printf("Break: %d\t\tOverflow: %d\n",registers->statusBreak,registers->statusOverflow);
 printf("Negative: %d\n",registers->statusNegative);
 */

- (NSDictionary *)CPUregisters
{
	CPURegisters *registers = [cpuInterpreter cpuRegisters];
	
	return [NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:"@0x%2.2x",registers->accumulator],@"accumulator",
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
			 [NSString stringWithFormat:@"%d",registers->statusNegative],@"statusNegative"];
}

- (NSArray *)instructions
{
	uint16_t edgeOfPage = 0x00FF;
	uint16_t addressOfCurrentInstruction = [cpuInterpreter cpuRegisters]->programCounter;
	uint8_t currentOpcode;
	uint16_t address;
	uint8_t operand;
	
	int firstObject;
	int lastObject;
	int currentSearch;
	unsigned int currentSearchValue;
	
	BOOL currentIsFirst = NO;
	
	edgeOfPage = [cpuInterpreter cpuRegisters]->programCounter | 0xFF00;
	
	if (([cpuInterpreter cpuRegisters]->programCounter < firstInstruction) || ([cpuInterpreter cpuRegisters]->programCounter >= lastInstruction)) {
		
		currentIsFirst = YES;
		[instructionArray release];
		instructionArray = [NSMutableArray array];
		
		while (addressOfCurrentInstruction < edgeOfPage) {
		
			currentOpcode = [cpuInterpreter readByteFromCPUAddressSpace:addressOfCurrentInstruction];
			
			if (instructionArguments[currentOpcode] == 2) {
			
				address = [cpuInterpreter readByteFromCPUAddressSpace:addressOfCurrentInstruction + 1] * 256;
				address |= [cpuInterpreter readByteFromCPUAddressSpace:addressOfCurrentInstruction + 2];
				
				[instructionArray addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"%s",instructionNames[currentOpcode]],@"name",
																					[NSString stringWithFormat:@"0x%4.4x",address],@"argument",
																					[NSString stringWithFormat:@"%s",instructionDescriptions[[cpuInterpreter readByteFromCPUAddressSpace:addressOfCurrentInstruction]]],@"description",
																					[NSNumber numberWithUnsignedInt:addressOfCurrentInstruction],@"address",
																					nil]];
				addressOfCurrentInstruction += 3;
			}
			else if (instructionArguments[currentOpcode] == 1) {
				
				operand = [cpuInterpreter readByteFromCPUAddressSpace:addressOfCurrentInstruction + 1];
				
				[instructionArray addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"%s",instructionNames[currentOpcode]],@"name",
											 [NSString stringWithFormat:@"0x%2.2x",operand],@"argument",
											 [NSString stringWithFormat:@"%s",instructionDescriptions[[cpuInterpreter readByteFromCPUAddressSpace:addressOfCurrentInstruction]]],@"description",
											 [NSNumber numberWithUnsignedInt:addressOfCurrentInstruction],@"address",
											 nil]];
				
				addressOfCurrentInstruction += 2;
			}
			else {
				
				[instructionArray addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"%s",instructionNames[currentOpcode]],@"name",
											 @"(Implied)",@"argument",
											 [NSString stringWithFormat:@"%s",instructionDescriptions[[cpuInterpreter readByteFromCPUAddressSpace:addressOfCurrentInstruction]]],@"description",
											 [NSNumber numberWithUnsignedInt:addressOfCurrentInstruction],@"address",
											 nil]];
				
				addressOfCurrentInstruction++;
			}
		}
	}
	else {
	
		//Remove current key of last instruction
		[_currentInstruction removeObjectForKey:@"current"];
	}
	
	// set current instruction
	currentSearch = firstObject = 0;
	lastObject = [instructionArray count] - 1;
		
	while ((currentSearchValue = [[[instructionArray objectAtIndex:currentSearch] objectForKey:address] unsignedIntValue]) != addressOfCurrentInstruction) {
			
		if (currentSearchValue > addressOfCurrentInstruction) {
				
			firstObject = currentSearch;
			currentSearch = (lastObject + currentSearch) / 2;
		}
		else {
			
			lastObject = currentSearch;
			currentSearch = (firstObject + currentSearch) / 2;
		}
	}
		
	[[instructionArray objectAtIndex:curentSearch] setObject:[NSImage imageNamed:] forKey:@"current"];
		
	return instructionArray;
}


@end
