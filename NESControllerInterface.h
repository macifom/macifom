/* NESControllerInterface.h
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

#import <Cocoa/Cocoa.h>
#include <IOKit/hid/IOHIDLib.h>

typedef enum {
	
	NESControllerButtonUp = 0,
	NESControllerButtonDown,
	NESControllerButtonLeft,
	NESControllerButtonRight,
	NESControllerButtonSelect,
	NESControllerButtonStart,
	NESControllerButtonA,
	NESControllerButtonB
} NESControllerButton;

@class NESKeyboardResponder;

@interface NESControllerInterface : NSObject {

	NSMutableArray *_controllerMappings;
	NSMutableArray *_inputDevices;
	NSMutableArray *_activeDevices;
	NSMutableArray *_knownDevices;
	IOHIDManagerRef gIOHIDManagerRef;
	
	uint_fast32_t *_controllers;
	
	IBOutlet NSWindow *propertiesWindow;
	IBOutlet NESKeyboardResponder *keyboardResponder;
	IBOutlet NSTableView *mappingTable;
	IBOutlet NSArrayController *mappingController;
	IBOutlet NSArrayController *controllerOneDeviceController;
	IBOutlet NSArrayController *controllerTwoDeviceController;
	
	NSNumber *_setMappingForController;
	NESControllerButton _setMappingForButton;
	NSUInteger _setMappingIndex;
	NSUInteger _initialControllerOneDeviceIndex;
	NSUInteger _initialControllerTwoDeviceIndex;
	BOOL _listenForButton;
}

- (uint_fast32_t)readController:(int)index;
- (void)keyboardEvent:(NSEvent *)event changedTo:(BOOL)state;
- (void)setButton:(NESControllerButton)button forController:(int)index withBool:(BOOL)flag;
- (void)startListeningForMapping:(id)sender;
- (void)stopListeningForMapping:(id)sender;
- (BOOL)listenForButton;
- (void)mapDevice:(NSMutableDictionary *)device button:(NESControllerButton)button toKeyDictionary:(NSDictionary *)keyDict;
- (NSMutableDictionary *)_activeDeviceForController:(NSNumber *)controller;

@property (retain) NSMutableArray *controllerMappings;
@property (retain) NSMutableArray *inputDevices;
@property (retain) NSMutableArray *activeDevices;
@property (readonly) NSNumber *setMappingForController;
@property (readonly) NESControllerButton setMappingForButton;

@end
