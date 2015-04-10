# macifom

Macifom is a highly-accurate NES emulator and debugger for OS X written in Objective-C. The purpose of this project to facilitate new NES development on the Mac OS X platform while leveraging OS X technologies such as AppKit, CoreAudio, and CoreGraphics.
The latest version of Macifom features:

 * Cycle-exact CPU (2A03) emulation for valid opcodes
 * Scanline-accurate PPU (2C02) emulation
 * Excellent sound reproduction care of Blargg's Nes_snd_emu library
 * Windowed and full-screen display modes
 * Support USB Gamepad and Joystick controls
 * Supports games designed for NROM, UxROM, CNROM, AxROM, SNROM, SUROM, TxROM, VRC1, VRC2a, VRC2b, and iNES #184 (Sunsoft) boards.
 * Automatic saving of cartridge SRAM to disk
 * A debugger featuring breakpoints, live disassembly of program code, reading and writing of memory locations, register display and step-through execution.

I am working to extend Macifom's emulation and debugging capabilities with the following:

 * Support for additional mapper chips and cartridge boards
 * Interfaces for viewing and modifying live program and graphics memory
 * Française, 日本語, Español and Deutch localizations
 
## About our License

The Macifom sources are distributed under the MIT License, but embeds Shay Green's Nes_snd_emu library which is licensed under the GNU LGPL. See http://www.slack.net/~ant/libs/audio.html for details and visit http://www.gnu.org/licenses/lgpl.html for a copy of the LGPL License.
