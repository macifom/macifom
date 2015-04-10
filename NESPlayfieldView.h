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

#import <Cocoa/Cocoa.h>

@class NESControllerInterface;

@interface NESPlayfieldView : NSView {

	uint_fast32_t *_videoBuffer;
	CGDataProviderRef _provider;
	CGColorSpaceRef _colorSpace;
	
	CGRect _windowedRect;
	CGRect _fullScreenRect;
	CGRect *screenRect;
	
	CGFloat _scale;
	
	IBOutlet NESControllerInterface *_controllerInterface;
}

- (uint_fast32_t *)videoBuffer;
- (void)scaleForFullScreenDrawingWithWidth:(size_t)width height:(size_t)height;
- (void)scaleForWindowedDrawing;

@end
