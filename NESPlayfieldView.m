/* NESPlayfieldView.h
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

#import "NESPlayfieldView.h"
#import "NESControllerInterface.h"

void VideoBufferProviderReleaseData(void *info, const void *data, size_t size)
{
	free((void *)data);
}

@implementation NESPlayfieldView

- (id)initWithFrame:(NSRect)frame {
    
	CMProfileRef profile;
	
	[super initWithFrame:frame];
    
	_videoBuffer = (uint_fast32_t *)malloc(sizeof(uint_fast32_t)*256*240);
	_provider = CGDataProviderCreateWithData(NULL, _videoBuffer, sizeof(uint_fast32_t)*256*240,VideoBufferProviderReleaseData);
	_windowedRect.origin.x = 0;
	_windowedRect.origin.y = 0;
	_fullScreenRect.size.width = _windowedRect.size.width = 256;
	_fullScreenRect.size.height =_windowedRect.size.height = 240;
	_scale = 2;
	screenRect = &_windowedRect;
		
	// There are reports that this can return fnf on Leopard, investigating...
	if (CMGetSystemProfile(&profile) == noErr) { 
		_colorSpace = CGColorSpaceCreateWithPlatformColorSpace(profile); 
		CMCloseProfile(profile); 
		NSLog(@"Obtained System colorspace. CG rendering will follow the fast path.");
	} 
	else _colorSpace = CGColorSpaceCreateDeviceRGB();
		
	[[self window] useOptimizedDrawing:YES]; // Use optimized drawing in window as there are no overlapping subviews
	[[self window] setPreferredBackingLocation:NSWindowBackingLocationVideoMemory]; // Use QuartzGL to scale the video
    [[self window] setBackingType:NSBackingStoreBuffered]; // For double-buffering
	[[self window] setBackgroundColor:[NSColor blackColor]]; // Default background for the window
	
    return self;
}

- (void)dealloc {
	
	// Clean up CG data
	CGColorSpaceRelease(_colorSpace); // Toss the color space.
	CGDataProviderRelease(_provider);
	
	[super dealloc];
}

- (BOOL)acceptsFirstResponder
{
    return YES;
}

- (void)keyDown:(NSEvent *)theEvent
{
	[_controllerInterface keyboardEvent:theEvent changedTo:YES];
}

- (void)keyUp:(NSEvent *)theEvent
{
	[_controllerInterface keyboardEvent:theEvent changedTo:NO];
}

- (uint_fast32_t *)videoBuffer
{
	return _videoBuffer;
}

- (void)scaleForFullScreenDrawingWithWidth:(size_t)width height:(size_t)height
{
	screenRect = &_fullScreenRect;
	
	// Set the preferred backing store to the card to get on the Quartz GL path
	[[self window] setPreferredBackingLocation:NSWindowBackingLocationVideoMemory];
	[[self window] useOptimizedDrawing:YES]; // Use optimized drawing in window as there are no overlapping subviews
	[[self window] setBackingType:NSBackingStoreBuffered]; // For double-buffering
	[[self window] setBackgroundColor:[NSColor blackColor]]; // Default background for the window appears to be white
	
    _scale = height / 240;
    _fullScreenRect.origin.x = ((width / _scale) - _fullScreenRect.size.width) / 2;
    _fullScreenRect.origin.y = ((height / _scale) - _fullScreenRect.size.height) / 2;
	CGDisplayHideCursor(kCGNullDirectDisplay);
}

- (void)scaleForWindowedDrawing
{
	screenRect = &_windowedRect;
    
    // Set the preferred backing store to the card to get on the Quartz GL path
	[[self window] setPreferredBackingLocation:NSWindowBackingLocationVideoMemory];
	[[self window] useOptimizedDrawing:YES]; // Use optimized drawing in window as there are no overlapping subviews
	[[self window] setBackingType:NSBackingStoreBuffered]; // For double-buffering
	[[self window] setBackgroundColor:[NSColor blackColor]]; // Default background for the window appears to be white
	
    _scale = 2;
	[[self window] makeFirstResponder:self];
	CGDisplayShowCursor(kCGNullDirectDisplay);
}

- (void)drawRect:(NSRect)rect {
    
	CGContextRef context = [[NSGraphicsContext currentContext] graphicsPort]; // Obtain graphics port from the window
	CGImageRef screen = CGImageCreate(256, 240, 8, 32, 4 * 256, _colorSpace, kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Host, _provider, NULL, false, kCGRenderingIntentDefault); // Create an image optimized for ARGB32.
	
	CGContextSetInterpolationQuality(context, kCGInterpolationNone);
	CGContextSetShouldAntialias(context, false);
	CGContextScaleCTM(context, _scale, _scale);
	CGContextDrawImage(context, *screenRect, screen); // All that work just to blit.
	CGImageRelease(screen); // Then toss the image.
}

@end
