/* NESControllerInterface.m
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

#import "NESControllerInterface.h"
#import "NESKeyboardResponder.h"

#define CONTROLLER_SETTINGS_VERSION 2

static Boolean IOHIDDevice_GetNSIntegerProperty( IOHIDDeviceRef inIOHIDDeviceRef, CFStringRef inKey, NSInteger* outValue )
{
	Boolean result = FALSE;
	
	if ( inIOHIDDeviceRef ) {
		CFTypeRef tCFTypeRef = IOHIDDeviceGetProperty( inIOHIDDeviceRef, inKey );
		if ( tCFTypeRef ) {
			// if this is a number
			if ( CFNumberGetTypeID() == CFGetTypeID( tCFTypeRef ) ) {
				// get it's value
				result = CFNumberGetValue( ( CFNumberRef ) tCFTypeRef, kCFNumberNSIntegerType, outValue );
			}
		}
	}
	return result;
}	// IOHIDDevice_GetLongProperty

NSInteger IOHIDDevice_GetUsage( IOHIDDeviceRef inIOHIDDeviceRef )
{
	NSInteger result = 0;
	( void ) IOHIDDevice_GetNSIntegerProperty( inIOHIDDeviceRef, CFSTR( kIOHIDDeviceUsageKey ), &result );
	return result;
} // IOHIDDevice_GetUsage

NSInteger IOHIDDevice_GetLocationID( IOHIDDeviceRef inIOHIDDeviceRef )
{
	NSInteger result = 0;
	( void ) IOHIDDevice_GetNSIntegerProperty( inIOHIDDeviceRef, CFSTR( kIOHIDLocationIDKey ), &result );
	return result;
}	// IOHIDDevice_GetLocationID

CFStringRef IOHIDDevice_GetSerialNumber( IOHIDDeviceRef inIOHIDDeviceRef )
{
	return IOHIDDeviceGetProperty( inIOHIDDeviceRef, CFSTR( kIOHIDSerialNumberKey ) );
}

CFStringRef IOHIDDevice_GetProduct( IOHIDDeviceRef inIOHIDDeviceRef )
{
	return IOHIDDeviceGetProperty( inIOHIDDeviceRef, CFSTR( kIOHIDProductKey ) );
} // IOHIDDevice_GetProduct

CFStringRef IOHIDDevice_GetManufacturer( IOHIDDeviceRef inIOHIDDeviceRef )
{
	return IOHIDDeviceGetProperty( inIOHIDDeviceRef, CFSTR( kIOHIDManufacturerKey ) );
} // IOHIDDevice_GetManufacturer

NSInteger IOHIDDevice_GetProductID( IOHIDDeviceRef inIOHIDDeviceRef )
{
	NSInteger result = 0;
	( void ) IOHIDDevice_GetNSIntegerProperty( inIOHIDDeviceRef, CFSTR( kIOHIDProductIDKey ), &result );
	return result;
} // IOHIDDevice_GetProductID

NSInteger IOHIDDevice_GetVendorID( IOHIDDeviceRef inIOHIDDeviceRef )
{
	NSInteger result = 0;
	( void ) IOHIDDevice_GetNSIntegerProperty( inIOHIDDeviceRef, CFSTR( kIOHIDVendorIDKey ), &result );
	return result;
} // IOHIDDevice_GetVendorID

// Used under MIT license from http://inquisitivecocoa.com/2009/04/05/key-code-translator/
static const struct { char const* const name; unichar const glyph; } mapOfNamesForUnicodeGlyphs[] =
{
	// Constants defined in NSEvent.h that are expected to relate to unicode characters, but don't seen to translate properly
	{ "Up",           NSUpArrowFunctionKey },
	{ "Down",         NSDownArrowFunctionKey },
	{ "Left",         NSLeftArrowFunctionKey },
	{ "Right",        NSRightArrowFunctionKey },
	{ "Home",         NSHomeFunctionKey },
	{ "End",          NSEndFunctionKey },
	{ "Page Up",      NSPageUpFunctionKey },
	{ "Page Down",    NSPageDownFunctionKey },
	
	//	These are the actual values that these keys translate to
	{ "Up",			0x1E },
	{ "Down",		0x1F },
	{ "Left",		0x1C },
	{ "Right",		0x1D },
	{ "Home",		0x1 },
	{ "End",		0x4 },
	{ "Page Up",	0xB },
	{ "Page Down",	0xC },
	{ "Return",		0x3 },
	{ "Tab",		0x9 },
	{ "Backtab",	0x19 },
	{ "Enter",		0xd },
	{ "Backspace",	0x8 },
	{ "Delete",		0x7F },
	{ "Escape",		0x1b },
	{ "Space",		0x20 }
	
};

// Need to update this value if you modify mapOfNamesForUnicodeGlyphs
#define NumberOfUnicodeGlyphReplacements 24

static void GamePadValueChanged(void *context, IOReturn result, void *sender, IOHIDValueRef value)
{
	IOHIDDeviceRef hidDevice;
	IOHIDElementRef element;
	IOHIDElementType elementType;
	long hidDeviceLocation;
	uint32_t controller;
    NSInteger usage;
	CFIndex logicalValue;
	IOHIDElementCookie cookie;
	NSMutableDictionary *device;
	NSArray *mappings;
	NESControllerButton button;
	NESControllerInterface *controllerInterface = (NESControllerInterface *)context;
	
	element = IOHIDValueGetElement(value);
	hidDevice = IOHIDElementGetDevice(element);
	cookie = IOHIDElementGetCookie(element);
    logicalValue = IOHIDValueGetIntegerValue(value);
	hidDeviceLocation = IOHIDDevice_GetLocationID(hidDevice);
	
	if ([controllerInterface listenForButton]) {
		
		button = [controllerInterface setMappingForButton];
		device = [controllerInterface _activeDeviceForController:[controllerInterface setMappingForController]];
		if ([(NSNumber *)[(NSMutableDictionary *)[device objectForKey:@"identifiers"] objectForKey:@"usage"] unsignedIntValue] != 6) {
	
			elementType = IOHIDElementGetType(element);
			usage = IOHIDElementGetUsage(element);
			
			// If button is a direction, verify that this is an axis and set both up and down
			if (button < NESControllerButtonSelect) {
				
				// If the element is of Axis type or has an X or Y usage indicator, proceed with mapping
				if ((elementType == kIOHIDElementTypeInput_Axis) || (usage == 0x30) || (usage == 0x31)) {
				
					NESControllerButton otherButton = button == NESControllerButtonUp ? NESControllerButtonDown : (button == NESControllerButtonDown ? NESControllerButtonUp : (button == NESControllerButtonLeft ? NESControllerButtonRight : NESControllerButtonLeft));
					
					[controllerInterface mapDevice:device button:button toKeyDictionary:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:(uint32_t)cookie],@"code",[NSString stringWithFormat:@"Axis %d",(uint32_t)cookie],@"name",nil]];
					[controllerInterface mapDevice:device button:otherButton toKeyDictionary:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:(uint32_t)cookie],@"code",[NSString stringWithFormat:@"Axis %d",(uint32_t)cookie],@"name",nil]];
					[controllerInterface stopListeningForMapping:nil];
				}
				// FIXME: Should I allow setting a direction to a non-axis?
			}
			else if (elementType == kIOHIDElementTypeInput_Button) {
			
				// If button is not a direction, verify that this is not an axis and set it only
				[controllerInterface mapDevice:device button:button toKeyDictionary:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:(uint32_t)cookie],@"code",[NSString stringWithFormat:@"Button %d",(uint32_t)cookie],@"name",nil]];
				[controllerInterface stopListeningForMapping:nil];
			}
		}
		
		return;
	}
	
	// Determine which controller this is
	for (device in [controllerInterface activeDevices]) {
		
		if ([(NSNumber *)[(NSDictionary *)[device objectForKey:@"identifiers"] objectForKey:@"locationId"] longValue] == hidDeviceLocation) {
		
			mappings = (NSArray *)[device objectForKey:@"mappings"];
			controller = [(NSNumber *)[device objectForKey:@"usedFor"] unsignedIntValue];
			
			for (button = NESControllerButtonUp; button < [mappings count]; button++) {
				
				if ([(NSNumber *)[(NSDictionary *)[mappings objectAtIndex:button] objectForKey:@"code"] unsignedIntValue] == (uint32_t)cookie) {
					
					if ((button == NESControllerButtonUp) || (button == NESControllerButtonDown)) {

						if (logicalValue < 125) {
                            
                            [controllerInterface setButton:NESControllerButtonUp forController:controller withBool:YES];
                        }
                        else if (logicalValue > 129) {
                            
                            [controllerInterface setButton:NESControllerButtonDown forController:controller withBool:YES];
                        }
                        else {
						
                            [controllerInterface setButton:NESControllerButtonUp forController:controller withBool:NO];
                            [controllerInterface setButton:NESControllerButtonDown forController:controller withBool:NO];
                        }
					}
					else if ((button == NESControllerButtonLeft) || (button == NESControllerButtonRight)) {
						
						if (logicalValue < 125) {
						
                            [controllerInterface setButton:NESControllerButtonLeft forController:controller withBool:YES];
                        }
                        else if (logicalValue > 129) {
                            
                            [controllerInterface setButton:NESControllerButtonRight forController:controller withBool:YES];
                        }
                        else {
							
                            [controllerInterface setButton:NESControllerButtonLeft forController:controller withBool:NO];
                            [controllerInterface setButton:NESControllerButtonRight forController:controller withBool:NO];
						}
					}
					else {
						
						[controllerInterface setButton:button forController:controller withBool:logicalValue ? YES : NO];
					}
					
					return;
				}
			}
		}
	}	
	// NSLog(@"In GamePadValueChanged: 0x%8.8x changed to %ld.",cookie,logicalValue);
}

// function to create matching dictionary
static CFMutableDictionaryRef hu_CreateDeviceMatchingDictionary(UInt32 inUsagePage, UInt32 inUsage)
{
    // create a dictionary to add usage page/usages to
    CFMutableDictionaryRef result = CFDictionaryCreateMutable(
															  kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    if (result) {
        if (inUsagePage) {
            // Add key for device type to refine the matching dictionary.
            CFNumberRef pageCFNumberRef = CFNumberCreate(
														 kCFAllocatorDefault, kCFNumberIntType, &inUsagePage);
            if (pageCFNumberRef) {
                CFDictionarySetValue(result,
									 CFSTR(kIOHIDDeviceUsagePageKey), pageCFNumberRef);
                CFRelease(pageCFNumberRef);
				
                // note: the usage is only valid if the usage page is also defined
                if (inUsage) {
                    CFNumberRef usageCFNumberRef = CFNumberCreate(
																  kCFAllocatorDefault, kCFNumberIntType, &inUsage);
                    if (usageCFNumberRef) {
                        CFDictionarySetValue(result,
											 CFSTR(kIOHIDDeviceUsageKey), usageCFNumberRef);
                        CFRelease(usageCFNumberRef);
                    } else {
                        fprintf(stderr, "%s: CFNumberCreate(usage) failed.", __PRETTY_FUNCTION__);
                    }
                }
            } else {
                fprintf(stderr, "%s: CFNumberCreate(usage page) failed.", __PRETTY_FUNCTION__);
            }
        }
    } else {
        fprintf(stderr, "%s: CFDictionaryCreateMutable failed.", __PRETTY_FUNCTION__);
    }
    return result;
}   // hu_CreateDeviceMatchingDictionary

@implementation NESControllerInterface

@synthesize controllerMappings=_controllerMappings, inputDevices=_inputDevices, activeDevices=_activeDevices, setMappingForController=_setMappingForController, setMappingForButton=_setMappingForButton;

- (NSString *)_nameForButton:(NESControllerButton)button 
{
	switch (button) {
		
		case NESControllerButtonUp:
			return @"Up";
			break;
		case NESControllerButtonDown:
			return @"Down";
			break;
		case NESControllerButtonLeft:
			return @"Left";
			break;
		case NESControllerButtonRight:
			return @"Right";
			break;
		case NESControllerButtonSelect:
			return @"Select";
			break;
		case NESControllerButtonStart:
			return @"Start";
			break;
		case NESControllerButtonA:
			return @"A";
			break;
		case NESControllerButtonB:
			return @"B";
			break;
		default:
			break;
	}
	
	return nil;
}

/*
// Used under MIT license from http://inquisitivecocoa.com/2009/04/05/key-code-translator/
- (NSString *)stringForKeyCode:(unsigned short)keyCode withModifierFlags:(NSUInteger)modifierFlags
{
	TISInputSourceRef currentKeyboard = TISCopyCurrentKeyboardInputSource();
	CFDataRef uchr = (CFDataRef)TISGetInputSourceProperty(currentKeyboard, kTISPropertyUnicodeKeyLayoutData);
	const UCKeyboardLayout *keyboardLayout = (const UCKeyboardLayout*)CFDataGetBytePtr(uchr);
	
	if(keyboardLayout) {
		UInt32 deadKeyState = 0;
		UniCharCount maxStringLength = 255;
		UniCharCount actualStringLength = 0;
		UniChar unicodeString[maxStringLength];
		
		OSStatus status = UCKeyTranslate(keyboardLayout,
										 keyCode, kUCKeyActionDown, modifierFlags,
										 LMGetKbdType(), 0,
										 &deadKeyState,
										 maxStringLength,
										 &actualStringLength, unicodeString);
		
		if(status != noErr)
			NSLog(@"There was an %s error translating from the '%d' key code to a human readable string: %s",
				  GetMacOSStatusErrorString(status), status, GetMacOSStatusCommentString(status));
		else if(actualStringLength > 0) {
			// Replace certain characters with user friendly names, e.g. Space, Enter, Tab etc.
			NSUInteger i = 0;
			while(i <= NumberOfUnicodeGlyphReplacements) {
				if(mapOfNamesForUnicodeGlyphs[i].glyph == unicodeString[0])
					return NSLocalizedString(([NSString stringWithFormat:@"%s", mapOfNamesForUnicodeGlyphs[i].name, nil]), @"Friendly Key Name");
				
				i++;
			}
			
			// NSLog(@"Unicode character as hexadecimal: %X", unicodeString[0]);
			return [NSString stringWithCharacters:unicodeString length:(NSInteger)actualStringLength];
		} else
			NSLog(@"Couldn't find a translation for the '%d' key code", keyCode);
	} else
		NSLog(@"Couldn't find a suitable keyboard layout from which to translate");
	
	return nil;
}
 */

- (void)_updateControllerMappings {
	
	NESControllerButton button;
	NSString *controllerName;
	NSString *deviceName;
	NSNumber *deviceUsage;
	NSDictionary *activeDevice;
	NSArray *mappings;
	
	NSMutableArray *updatedMappings = [NSMutableArray array];
	
	for (activeDevice in _activeDevices) {
	
		controllerName = [NSString stringWithFormat:@"Controller %d",([(NSNumber *)[activeDevice objectForKey:@"usedFor"] unsignedIntValue] + 1)];
		deviceName = (NSString *)[(NSDictionary *)[activeDevice objectForKey:@"identifiers"] objectForKey:@"name"];
		deviceUsage = (NSNumber *)[(NSDictionary *)[activeDevice objectForKey:@"identifiers"] objectForKey:@"usage"];
		mappings = (NSArray *)[activeDevice objectForKey:@"mappings"];
		
		for (button = NESControllerButtonUp; button < [mappings count]; button++) {
		
			[updatedMappings addObject:
			 [NSDictionary dictionaryWithObjectsAndKeys:
			  [NSNumber numberWithInt:button],@"buttonIndex",
			  [activeDevice objectForKey:@"usedFor"],@"controller",
			  [NSString stringWithFormat:@"%@ %@",controllerName,[self _nameForButton:button]],@"button",
			  [NSString stringWithFormat:@"%@ (%@)",[(NSDictionary *)[mappings objectAtIndex:button] objectForKey:@"name"], deviceName],@"assignment",
			  nil]];
		}
	}
	
	self.controllerMappings = updatedMappings;
}

- (NSDictionary *)_identifiersForHIDDevice:(IOHIDDeviceRef)device
{
	NSMutableString *name = [NSMutableString string];
	NSString *product = (NSString *)IOHIDDevice_GetProduct(device);
	if (product) {
	
		[name appendString:product];
	}
	else {
	
		NSString* manufacturer = (NSString *)IOHIDDevice_GetManufacturer(device);
		if (manufacturer) {
			
			[name appendString:manufacturer];
		}
	}
	
	return [NSDictionary dictionaryWithObjectsAndKeys:
								name,@"name",
								[NSNumber numberWithInteger:IOHIDDevice_GetUsage(device)],@"usage",
								[NSNumber numberWithInteger:IOHIDDevice_GetVendorID(device)],@"vendorId",
								[NSNumber numberWithInteger:IOHIDDevice_GetProductID(device)],@"productId",
								[NSNumber numberWithInteger:IOHIDDevice_GetLocationID(device)],@"locationId",nil];
}

- (void)_updateInputDevices:(IOHIDDeviceRef *)devices length:(CFIndex)number {

	NSMutableArray *newDeviceList = [NSMutableArray arrayWithObject:
									 [NSDictionary dictionaryWithObjectsAndKeys:@"Keyboard",@"name",
									  [NSNumber numberWithInteger:6],@"usage",nil]];
	
	for (uint_fast32_t index = 0; index < number; index++) {
	
		[newDeviceList addObject:[self _identifiersForHIDDevice:devices[index]]];
	}
	
	self.inputDevices = newDeviceList;
}

- (BOOL)_device:(NSDictionary *)deviceOne matches:(NSDictionary *)deviceTwo {

	if ([(NSNumber *)[deviceOne objectForKey:@"usage"] isEqualToNumber:[NSNumber numberWithInteger:6]] &&
		[(NSNumber *)[deviceTwo objectForKey:@"usage"] isEqualToNumber:[NSNumber numberWithInteger:6]]) return YES;
	
	return [(NSNumber *)[deviceOne objectForKey:@"usage"] isEqualToNumber:(NSNumber *)[deviceTwo objectForKey:@"usage"]] &&
		[(NSNumber *)[deviceOne objectForKey:@"vendorId"] isEqualToNumber:(NSNumber *)[deviceTwo objectForKey:@"vendorId"]] &&
		[(NSNumber *)[deviceOne objectForKey:@"productId"] isEqualToNumber:(NSNumber *)[deviceTwo objectForKey:@"productId"]] &&
		[(NSNumber *)[deviceOne objectForKey:@"locationId"] isEqualToNumber:(NSNumber *)[deviceTwo objectForKey:@"locationId"]];
}

- (void)_activateInputDevices {
	
	NSMutableArray *newActiveDevices = [NSMutableArray array];
	NSMutableDictionary *knownDevice;
	NSUInteger deviceIndex;
	
	BOOL foundControllerOne = NO;
	BOOL foundControllerTwo = NO;
	
	// See if last enabled devices are attached, if so make them active
	for (knownDevice in _knownDevices) {
	
		if ([(NSNumber *)[knownDevice objectForKey:@"enabled"] boolValue]) {
		
			[knownDevice setObject:[NSNumber numberWithBool:NO] forKey:@"enabled"];
			
			if ((([(NSNumber *)[knownDevice objectForKey:@"usedFor"] unsignedIntValue] == 0) && !foundControllerOne) ||
				(([(NSNumber *)[knownDevice objectForKey:@"usedFor"] unsignedIntValue] == 1) && !foundControllerTwo)) {
			
				for (deviceIndex = 0; deviceIndex < [_inputDevices count]; deviceIndex++) {
			
					if ([self _device:(NSDictionary *)[_inputDevices objectAtIndex:deviceIndex] matches:(NSDictionary *)[knownDevice objectForKey:@"identifiers"]]) {
					
						NSLog(@"Found preferred device for Controller %d", [(NSNumber *)[knownDevice objectForKey:@"usedFor"] unsignedIntValue] + 1);
						[knownDevice setObject:[NSNumber numberWithBool:YES] forKey:@"enabled"];
						[newActiveDevices addObject:knownDevice];
						if ([(NSNumber *)[knownDevice objectForKey:@"usedFor"] unsignedIntValue] == 0) {
						
							_initialControllerOneDeviceIndex = deviceIndex;
							foundControllerOne = YES;
						}
						else {
							
							foundControllerTwo = YES;
							_initialControllerTwoDeviceIndex = deviceIndex;
						}
						break;
					}
				}
			}
		}
	}
	
	// If not, see if there are profiles for any attached devices
	for (knownDevice in _knownDevices) {
		
		if ((!foundControllerOne || !foundControllerTwo) && ![newActiveDevices containsObject:knownDevice]) {
		
			for (deviceIndex = 0; deviceIndex < [_inputDevices count]; deviceIndex++) {
				
				if ([self _device:(NSDictionary *)[_inputDevices objectAtIndex:deviceIndex] matches:(NSDictionary *)[knownDevice objectForKey:@"identifiers"]]) {
				
					[knownDevice setObject:[NSNumber numberWithBool:YES] forKey:@"enabled"];
					
					// Activate controllers that have yet to be found
					if (foundControllerOne || foundControllerTwo) {
						
						if (foundControllerOne) {
							
							// If we've found Controller 1, make this controller 2
							[knownDevice setObject:[NSNumber numberWithUnsignedInt:1] forKey:@"usedFor"];
						}
						else {
							
							// If we've found controller 2, but not controller 1, make this controller 1
							[knownDevice setObject:[NSNumber numberWithUnsignedInt:0] forKey:@"usedFor"];
						}
					}
						
					// If neither controller has been found, assign this device to the Controller it was last used for
					if ([(NSNumber *)[knownDevice objectForKey:@"usedFor"] unsignedIntValue] == 0) {
						
						_initialControllerOneDeviceIndex = deviceIndex;
						foundControllerOne = YES;
					}
					else {
							
						_initialControllerTwoDeviceIndex = deviceIndex;
						foundControllerTwo = YES;
					}
	
					NSLog(@"Found non-preferred device for Controller %d", [(NSNumber *)[knownDevice objectForKey:@"usedFor"] unsignedIntValue] + 1);
					[newActiveDevices addObject:knownDevice];
					
					break;
				}
			}
		}
		else break;
	}	
		
	self.activeDevices = newActiveDevices;
}

- (NSMutableDictionary *)_activeDeviceForController:(NSNumber *)controller {
	
	NSMutableDictionary *activeDevice;
	
	for (activeDevice in _activeDevices) {
		
		if ([(NSNumber *)[activeDevice objectForKey:@"usedFor"] isEqualToNumber:controller]) {
			
			return activeDevice;
		}
	}
	
	return nil;
}

- (void)_setActiveDevice:(NSMutableDictionary *)device forController:(NSNumber *)controller {

	NSMutableArray *newActiveDevices = [NSMutableArray arrayWithObject:device];
	NSMutableDictionary *otherDevice;
	
	for (otherDevice in _activeDevices) {
	
		if (![(NSNumber *)[otherDevice objectForKey:@"usedFor"] isEqualToNumber:controller]) {
		
			[newActiveDevices addObject:otherDevice];
		}
		else {
		
			[otherDevice setObject:[NSNumber numberWithBool:NO] forKey:@"enabled"];
		}
	}
	
	[device setObject:[NSNumber numberWithBool:YES] forKey:@"enabled"];
	self.activeDevices = newActiveDevices;
}

- (void)_buildKnownDeviceList {

	NSArray *userDefaultsControllers = (NSArray *)[[NSUserDefaults standardUserDefaults] objectForKey:@"controllers"];
	NSDictionary *userDefaultsController;
	NSMutableDictionary *controllerDictionary;
	_knownDevices = [[NSMutableArray alloc] initWithCapacity:[userDefaultsControllers count]];
	
	for (userDefaultsController in userDefaultsControllers) {
	
		 controllerDictionary = [NSMutableDictionary dictionaryWithObjectsAndKeys:
								 [NSMutableArray arrayWithArray:(NSArray *)[userDefaultsController objectForKey:@"mappings"]],@"mappings",
								 [NSDictionary dictionaryWithDictionary:(NSDictionary *)[userDefaultsController objectForKey:@"identifiers"]],@"identifiers",
								 [userDefaultsController objectForKey:@"usedFor"],@"usedFor",
								 [userDefaultsController objectForKey:@"enabled"],@"enabled",nil];
		
		[_knownDevices addObject:controllerDictionary];
	}
	
}

- (id)init {

	CFMutableArrayRef matchingCFArrayRef;
	IOReturn tIOReturn;
	CFSetRef tCFSetRef;
	CFIndex numMatchedDevices = 0;
	uint_fast32_t deviceIndex;
	void **usbHidDevices = NULL;
	
	[super init];
		
	_listenForButton = NO;
	_controllers = (uint_fast32_t *)malloc(sizeof(uint_fast32_t)*2);
	_controllers[0] = 0x0001FF00; // Should indicate one controller on $4016 per nestech.txt
	_controllers[1] = 0x0002FF00; // Should indicate one controller on $4017 per nestech.txt
	
	// Enumerate any attached USB joysticks and gamepads
	gIOHIDManagerRef = IOHIDManagerCreate(kCFAllocatorDefault,kIOHIDOptionsTypeNone);
	// create an array of matching dictionaries
	matchingCFArrayRef = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
	if (matchingCFArrayRef) {
		// create a device matching dictionary for joysticks
		CFDictionaryRef matchingCFDictRef =
		hu_CreateDeviceMatchingDictionary(kHIDPage_GenericDesktop, kHIDUsage_GD_Joystick);
		if (matchingCFDictRef) {
			// add it to the matching array
			CFArrayAppendValue(matchingCFArrayRef, matchingCFDictRef);
			CFRelease(matchingCFDictRef); // and release it
		} else {
			NSLog(@"CreateDeviceMatchingDictionary(joystick) failed.");
		}
		
		// create a device matching dictionary for game pads
		matchingCFDictRef = hu_CreateDeviceMatchingDictionary(kHIDPage_GenericDesktop, kHIDUsage_GD_GamePad);
		if (matchingCFDictRef) {
			// add it to the matching array
			CFArrayAppendValue(matchingCFArrayRef, matchingCFDictRef);
			CFRelease(matchingCFDictRef); // and release it
		} else {
			NSLog(@"CreateDeviceMatchingDictionary(game pad) failed.");
		}
	} else {
		NSLog(@"CFArrayCreateMutable failed.");
	}
	// set the HID device matching array
	IOHIDManagerSetDeviceMatchingMultiple(gIOHIDManagerRef, matchingCFArrayRef);
	
	// and then release it
	CFRelease(matchingCFArrayRef);
	
	// Schedule the HID Manager in the current runloop to allow for callbacks
	IOHIDManagerScheduleWithRunLoop(gIOHIDManagerRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
	
	// Open up the HID Manager
	tIOReturn = IOHIDManagerOpen(gIOHIDManagerRef, kIOHIDOptionsTypeNone);
	
	// Get the matched devices
	tCFSetRef = IOHIDManagerCopyDevices(gIOHIDManagerRef);
	if (tCFSetRef) {
		
		numMatchedDevices = CFSetGetCount(tCFSetRef);
		if (numMatchedDevices) {
			
			usbHidDevices = (void **)malloc(sizeof(void*)*numMatchedDevices);
			CFSetGetValues(tCFSetRef,(const void **)usbHidDevices);
			for (deviceIndex = 0; deviceIndex < numMatchedDevices; deviceIndex++) {
			
				IOHIDDeviceRegisterInputValueCallback((IOHIDDeviceRef)usbHidDevices[deviceIndex],GamePadValueChanged,self);
			}
		}
		else NSLog(@"No matching USB HID devices were found!");
	}
	else NSLog(@"No matching USB HID devices were found!");
		
	// Initialize controller Settings
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	// Set default controls
	NSDictionary *defaultControls = [NSDictionary dictionaryWithObjectsAndKeys:
									 [NSArray arrayWithObjects:
									  [NSDictionary dictionaryWithObjectsAndKeys:
									   [NSArray arrayWithObjects:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedShort:13],@"code",@"w",@"name",nil],[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedShort:1],@"code",@"s",@"name",nil],[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedShort:0],@"code",@"a",@"name",nil],[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedShort:2],@"code",@"d",@"name",nil],[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedShort:5],@"code",@"g",@"name",nil],[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedShort:4],@"code",@"h",@"name",nil],[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedShort:37],@"code",@"l",@"name",nil],[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedShort:40],@"code",@"k",@"name",nil],nil],@"mappings",
									   [NSDictionary dictionaryWithObjectsAndKeys:@"Keyboard",@"name",[NSNumber numberWithUnsignedInt:6],@"usage",nil],@"identifiers",
									   [NSNumber numberWithUnsignedInt:0],@"usedFor",
									   [NSNumber numberWithBool:YES],@"enabled",nil],
									  [NSDictionary dictionaryWithObjectsAndKeys:
									   [NSArray arrayWithObjects:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedShort:126],@"code",@"Up",@"name",nil],[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedShort:125],@"code",@"Down",@"name",nil],[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedShort:123],@"code",@"Left",@"name",nil],[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedShort:124],@"code",@"Right",@"name",nil],[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedShort:9],@"code",@"v",@"name",nil],[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedShort:11],@"code",@"b",@"name",nil],[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedShort:46],@"code",@"m",@"name",nil],[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedShort:45],@"code",@"n",@"name",nil],nil],@"mappings",
									   [NSDictionary dictionaryWithObjectsAndKeys:@"Keyboard",@"name",[NSNumber numberWithUnsignedInt:6],@"usage",nil],@"identifiers",
									   [NSNumber numberWithUnsignedInt:1],@"usedFor",
									   [NSNumber numberWithBool:YES],@"enabled",nil],nil],@"controllers",[NSNumber numberWithUnsignedInt:1],@"controllerSettingsVersion",nil];
	
	[defaults registerDefaults:defaultControls];
	
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"controllerSettingsVersion"] || ([[[NSUserDefaults standardUserDefaults] objectForKey:@"controllerSettingsVersion"] unsignedIntValue] != CONTROLLER_SETTINGS_VERSION)) {
        
        NSLog(@"Updating controller settings schema.");
        
        [[NSUserDefaults standardUserDefaults] setObject:[defaultControls objectForKey:@"controllers"] forKey:@"controllers"];
        [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithUnsignedInt:CONTROLLER_SETTINGS_VERSION] forKey:@"controllerSettingsVersion"];
    }
    
	// Build list of known devices
	[self _buildKnownDeviceList];
	
	// Determine attached devices
	[self _updateInputDevices:(IOHIDDeviceRef *)usbHidDevices length:numMatchedDevices];
	
	// Set new active devices if necessary
	[self _activateInputDevices];
	
	// Update controller mappings for display
	[self _updateControllerMappings];
	
	return self;
}

- (void)dealloc
{
	[controllerOneDeviceController removeObserver:self forKeyPath:@"selectionIndex"];
	[controllerTwoDeviceController removeObserver:self forKeyPath:@"selectionIndex"];
	
	// Clean up HID Manager data
	IOHIDManagerUnscheduleFromRunLoop(gIOHIDManagerRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
	IOHIDManagerClose(gIOHIDManagerRef, kIOHIDOptionsTypeNone);
	CFRelease(gIOHIDManagerRef);
	
	[super dealloc];
}

- (void)awakeFromNib {
	
	[mappingTable setTarget:self];
	[mappingTable setDoubleAction:@selector(startListeningForMapping:)];
	
	// Set up active device selections in Controller Preferences
	[controllerOneDeviceController setSelectionIndex:_initialControllerOneDeviceIndex];
	[controllerTwoDeviceController setSelectionIndex:_initialControllerTwoDeviceIndex];
	
	[controllerOneDeviceController addObserver:self
									forKeyPath:@"selectionIndex"
									   options:(NSKeyValueObservingOptionNew |
												NSKeyValueObservingOptionOld)
									   context:(void *)0];
	
	[controllerTwoDeviceController addObserver:self
									forKeyPath:@"selectionIndex"
									   options:(NSKeyValueObservingOptionNew |
												NSKeyValueObservingOptionOld)
									   context:(void *)1];
}

- (void)startListeningForMapping:(id)sender {

	if (!_listenForButton) {

		// NSLog(@"Enabling button mapping.");
		[propertiesWindow makeFirstResponder:keyboardResponder]; // Unnecessary if not mapping a keyboard key
				
		NSDictionary *mapping = (NSDictionary *)[[mappingController selectedObjects] objectAtIndex:0];
		_setMappingIndex = [mappingController selectionIndex];
		_setMappingForController = (NSNumber *)[mapping objectForKey:@"controller"];
		_setMappingForButton = (NESControllerButton)[(NSNumber *)[mapping objectForKey:@"buttonIndex"] intValue];
		_listenForButton = YES;
	}
}

- (void)stopListeningForMapping:(id)sender {

	if (_listenForButton) {
		
		[mappingController setSelectionIndex:_setMappingIndex];
		_listenForButton = NO;
        [propertiesWindow makeFirstResponder:mappingTable];
	}
}

- (void)mapDevice:(NSMutableDictionary *)device button:(NESControllerButton)button toKeyDictionary:(NSDictionary *)keyDict {
	
	[(NSMutableArray *)[device objectForKey:@"mappings"] replaceObjectAtIndex:button withObject:keyDict];
	[[NSUserDefaults standardUserDefaults] setObject:_knownDevices forKey:@"controllers"];
	
	[self _updateControllerMappings];
}

- (void)keyboardEvent:(NSEvent *)event changedTo:(BOOL)state
{
	NESControllerButton buttonIndex;
	NSDictionary *controller;
	NSArray *mappings;
    NSString *keyName;
    NSUInteger keyCounter;
	NSNumber *key = [NSNumber numberWithUnsignedShort:[event keyCode]];

	if (_listenForButton) {
	
		NSMutableDictionary *device = [self _activeDeviceForController:_setMappingForController];
		if ([(NSNumber *)[(NSMutableDictionary *)[device objectForKey:@"identifiers"] objectForKey:@"usage"] unsignedIntValue] == 6) {
		
            keyName = [event charactersIgnoringModifiers];
			for (keyCounter = 0; keyCounter < NumberOfUnicodeGlyphReplacements; keyCounter++) {
				
                if (mapOfNamesForUnicodeGlyphs[keyCounter].glyph == [keyName characterAtIndex:0]) {
                    
                    keyName = [NSString stringWithCString:mapOfNamesForUnicodeGlyphs[keyCounter].name encoding:NSUTF8StringEncoding];
                    break;
                }
			}
            
			[self mapDevice:device button:_setMappingForButton toKeyDictionary:[NSDictionary dictionaryWithObjectsAndKeys:key,@"code",keyName,@"name",nil]];
			[self stopListeningForMapping:nil];
			return;
		}
	}
	
	for (controller in _activeDevices) {
		
		if ([(NSNumber *)[(NSDictionary *)[controller objectForKey:@"identifiers"] objectForKey:@"usage"] unsignedIntValue] != 6) continue;
		
		mappings = [controller objectForKey:@"mappings"];
		
		for (buttonIndex = NESControllerButtonUp; buttonIndex < [mappings count]; buttonIndex++) {
			
			if ([(NSNumber *)[(NSDictionary *)[mappings objectAtIndex:buttonIndex] objectForKey:@"code"] isEqualToNumber:key]) {
		
				[self setButton:buttonIndex forController:[(NSNumber *)[controller objectForKey:@"usedFor"] unsignedIntValue] withBool:state];
				return;
			}
		}
	}
}

- (void)setButton:(NESControllerButton)button forController:(int)index withBool:(BOOL)flag
{	
	switch (button) {
			
		case NESControllerButtonUp:
			if (flag) {
				
				_controllers[index] &= 0xFFFFFFCF; // FIXME: Currently, we clear up and down to prevent errors. Perhaps I should clear all directions?
				_controllers[index] |= 0x10; // Up
			}
			else {
				_controllers[index] &= 0xFFFFFFEF; // Clear up
			}
			break;
		case NESControllerButtonLeft:
			if (flag) {
				
				_controllers[index] &= 0xFFFFFF3F; // Clear left and right to prevent errors
				_controllers[index] |= 0x40; // Left
			}
			else {
				_controllers[index] &= 0xFFFFFFBF;
			}
			break;
		case NESControllerButtonDown:
			if (flag) {
				
				_controllers[index] &= 0xFFFFFFCF;
				_controllers[index] |= 0x20; // Down
			}
			else {
				_controllers[index] &= 0xFFFFFFDF;
			}
			break;
		case NESControllerButtonRight:
			if (flag) {
				
				_controllers[index] &= 0xFFFFFF3F;
				_controllers[index] |= 0x80; // Right
			}
			else {
				_controllers[index] &= 0xFFFFFF7F;
			}
			break;
		case NESControllerButtonA:
			if (flag) {
				
				_controllers[index] |= 0x1; // A button fire
			}
			else {
				_controllers[index] &= 0xFFFFFFFE; // A button release
			}
			break;
		case NESControllerButtonB:
			if (flag) {
				
				_controllers[index] |= 0x2; // B button fire
			}
			else {
				_controllers[index] &= 0xFFFFFFFD; // B button release
			}
			break;
		case NESControllerButtonSelect:
			if (flag) {
				
				_controllers[index] |= 0x4; // Select button fire
			}
			else {
				_controllers[index] &= 0xFFFFFFFB; // Select button fire
			}
			break;
		case NESControllerButtonStart:
			if (flag) {
				
				_controllers[index] |= 0x8; // Start button fire
			}
			else {
				_controllers[index] &= 0xFFFFFFF7; // Start button fire
			}
			break;
		default:
			break;
	}
}

- (uint_fast32_t)readController:(int)index
{
	return _controllers[index];
}

- (BOOL)listenForButton {

	return _listenForButton;
}

- (NSMutableDictionary *)_knownDeviceMatchingIdentifiers:(NSDictionary *)identifiers forController:(NSNumber *)controller {
	
	NSMutableDictionary *knownDevice;
	NSMutableDictionary *alternative = nil;
	
	for (knownDevice in _knownDevices) {
		
		if ([self _device:identifiers matches:(NSDictionary *)[knownDevice objectForKey:@"identifiers"]]) {
			
			if ([(NSNumber *)[knownDevice objectForKey:@"usedFor"] isEqualToNumber:controller]) {
					
				// If the device matches and was last used for this controller, return it immediately
				return knownDevice;
			}
			else {
			
				// Otherwise, make this an alternative
				alternative = knownDevice;
			}
		}
	}
	
	return alternative;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{	
	NSDictionary *newSelection;
	NSMutableDictionary *newDevice;
	NSNumber *controller = [NSNumber numberWithUnsignedLong:(unsigned long)context];
	
	// Get a reference to the new device
	if (context) newSelection = [[controllerTwoDeviceController selectedObjects] objectAtIndex:0];
	else newSelection = [[controllerOneDeviceController selectedObjects] objectAtIndex:0];
	
	// Check to see if there's a saved mapping for this device
	newDevice = [self _knownDeviceMatchingIdentifiers:newSelection forController:controller];
	
	if (newDevice) {
		
		NSLog(@"Found existing device.");
		// Hey, a device we know about, let's enable it and set it for this controller
		[newDevice setObject:[NSNumber numberWithBool:YES] forKey:@"enabled"];
		[newDevice setObject:controller forKey:@"usedFor"];
	
		// Let's hope that the NSUserDefaults magically picks up on these changes (yeah, right)
	}
	else {
		
		NSLog(@"Creating new known device.");
        
		// A device we don't know about, give it empty data and add it to the list of known devices
		newDevice = [NSMutableDictionary dictionaryWithObjectsAndKeys:
					 [NSMutableArray arrayWithObjects:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:-1],@"code",@"None",@"name",nil],[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:-1],@"code",@"None",@"name",nil],[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:-1],@"code",@"None",@"name",nil],[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:-1],@"code",@"None",@"name",nil],[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:-1],@"code",@"None",@"name",nil],[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:-1],@"code",@"None",@"name",nil],[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:-1],@"code",@"None",@"name",nil],[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:-1],@"code",@"None",@"name",nil],nil],@"mappings",
					 newSelection,@"identifiers",
					 controller,@"usedFor",
					 [NSNumber numberWithBool:YES],@"enabled",nil];
		
		[_knownDevices addObject:newDevice];
	}
	
	// Swap active device for this controller
	[self _setActiveDevice:newDevice forController:controller];
	
	// Update saved preferences
	[[NSUserDefaults standardUserDefaults] setObject:_knownDevices forKey:@"controllers"];
		
	// Update mappings
	[self _updateControllerMappings];
}

@end
