#import "PRAlbumListViewCell.h"
#import "PRDb.h"
#import "PRLibrary.h"
#import "NSImage+Extensions.h"
#import "PRUserDefaults.h"


@implementation PRAlbumListViewCell

- (void)drawInteriorWithFrame:(NSRect)theCellFrame inView:(NSView *)theControlView
{	
	NSDictionary *dict = [self objectValue];
	PRDb *db = [dict objectForKey:@"db"];
	PRFile file = [[dict objectForKey:@"file"] intValue];
    NSImage *icon = [dict objectForKey:@"icon"];
	
    if (!icon || ![icon isValid]) {
        icon = [NSImage imageNamed:@"PRLightAlbumArt"];
    }
    
    NSString *artist;
	NSString *album;
    NSString *albumArtist;
	NSNumber *year;
	[[db library] value:&album forFile:file attribute:PRAlbumFileAttribute _error:nil];
	[[db library] value:&artist forFile:file attribute:PRArtistFileAttribute _error:nil];
    [[db library] value:&albumArtist forFile:file attribute:PRAlbumArtistFileAttribute _error:nil];
	[[db library] value:&year forFile:file attribute:PRYearFileAttribute _error:nil];
    
	// Inset the cell frame to give everything a little horizontal padding
	NSRect insetRect = NSInsetRect(theCellFrame, 8, 8);
	NSSize iconSize = NSMakeSize(150, 150);
    [icon setFlipped:TRUE];
	
	// Make attributes for our strings
    NSShadow *shadow = [[[NSShadow alloc] init] autorelease];
	[shadow setShadowColor:[NSColor colorWithDeviceWhite:0.0 alpha:0.1]];
	[shadow setShadowOffset:NSMakeSize(1.1, -1.3)];
	
	NSMutableParagraphStyle *paragraphStyle = [[[NSMutableParagraphStyle alloc] init] autorelease];
	[paragraphStyle setLineBreakMode:NSLineBreakByTruncatingTail];
    [paragraphStyle setAlignment:NSCenterTextAlignment];
	
	NSMutableDictionary *titleAttributes = 
      [[[NSMutableDictionary alloc] initWithObjectsAndKeys:
        [NSFont boldSystemFontOfSize:11], NSFontAttributeName,
        paragraphStyle, NSParagraphStyleAttributeName,
//        shadow, NSShadowAttributeName,
        [NSColor colorWithCalibratedWhite:0.2 alpha:1.0], NSForegroundColorAttributeName,
        nil] autorelease];
	NSMutableDictionary *subtitleAttributes = 
      [[[NSMutableDictionary alloc] initWithObjectsAndKeys:
        [NSFont systemFontOfSize:11], NSFontAttributeName,
        paragraphStyle, NSParagraphStyleAttributeName,
//        shadow, NSShadowAttributeName,
        [NSColor colorWithCalibratedWhite:0.2 alpha:1.0], NSForegroundColorAttributeName,
        nil] autorelease];
	
	// Make a Title string
	NSString *title = album;
    NSString *subtitle = artist;
    if ([[PRUserDefaults sharedUserDefaults] useAlbumArtist] && ![albumArtist isEqualToString:@""]) {
        subtitle = albumArtist;
    }
	NSString *subSubtitle = [year stringValue];
    
    if ([title isEqualToString:@""]) {
        title = @"Unknown Album";
    }
    if ([subtitle isEqualToString:@""]) {
        subtitle = @"Unknown Artist";
    }
    if ([subSubtitle isEqualToString:@"0"]) {
        subSubtitle = @"";
    }
	
	// get the size of the string for layout
	NSSize titleSize = [title sizeWithAttributes:titleAttributes];
	NSSize subtitleSize = [subtitle sizeWithAttributes:subtitleAttributes];
	NSSize subSubtitleSize = [subSubtitle sizeWithAttributes:subtitleAttributes];
	
	// Vertical padding between the lines of text
    // Horizontal padding between icon and text
	float verticalPadding = 0.0;
	float subVerticalPadding = 1.0;
	
	// Icon box: center the icon vertically inside of the inset rect
	NSRect iconBox = NSMakeRect(insetRect.origin.x,
								insetRect.origin.y,
								iconSize.width,
								iconSize.height);
	
	// Make a box for our text
	// Place it next to the icon with horizontal padding
	// Size it horizontally to fill out the rest of the inset rect
	// Center it vertically inside of the inset rect
	float combinedHeight = titleSize.height + subtitleSize.height + subSubtitleSize.height + 2 * subVerticalPadding;

    NSRect textBox = NSMakeRect(insetRect.origin.x,
                                insetRect.origin.y + iconBox.size.height + verticalPadding,
                                iconSize.width, combinedHeight);

	// Now split the text box in half and put the title box in the top half and subtitle box in bottom half
	NSRect titleBox = NSMakeRect(textBox.origin.x, textBox.origin.y, textBox.size.width, titleSize.height);
	NSRect subtitleBox = NSMakeRect(textBox.origin.x, 
                                    textBox.origin.y + titleSize.height + subVerticalPadding,
                                    textBox.size.width, subtitleSize.height);
//	NSRect subSubtitleBox = NSMakeRect(textBox.origin.x, 
//                                       subtitleBox.origin.y + subVerticalPadding + subtitleSize.height,
//                                       textBox.size.width, subSubtitleSize.height);
        
    
    NSImage *image = icon;
    NSRect inRect = NSInsetRect(iconBox, 7, 7);
    // create a destination rect scaled to fit inside the frame
    NSRect drawnRect;
    drawnRect.origin = inRect.origin;
    if ([image size].width > [image size].height) {
        drawnRect.size.height = [image size].height * inRect.size.width/[image size].width;
        drawnRect.size.width = inRect.size.width;
    } else {
        drawnRect.size.width = [image size].width * inRect.size.height/[image size].height;
        drawnRect.size.height = inRect.size.height;
    }
    
    // center it in the frame
    drawnRect.origin.x += (inRect.size.width - drawnRect.size.width)/2;
    drawnRect.origin.y += (inRect.size.height - drawnRect.size.height)/2;
    drawnRect.origin.x = floor(drawnRect.origin.x);
    drawnRect.origin.y = floor(drawnRect.origin.y);
    drawnRect.size.width = floor(drawnRect.size.width);
    drawnRect.size.height = floor(drawnRect.size.height);
    
    // drawBorder
    [NSGraphicsContext saveGraphicsState];
    shadow = [[[NSShadow alloc] init] autorelease];
    [shadow setShadowOffset:NSMakeSize(0.0, -1.7)];
    [shadow setShadowBlurRadius:3];
    [shadow setShadowColor:[NSColor colorWithDeviceWhite:0.4 alpha:1.0]];	
    [shadow set];
    
    [[NSColor whiteColor] set];
    [NSBezierPath fillRect:drawnRect];
    [NSGraphicsContext restoreGraphicsState];
    
    // draw image
        [image drawInRect:drawnRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0]; 
    
    //    [icon drawCenteredinRect:iconBox operation:NSCompositeSourceOver fraction:1.0];
    
	// draw the text
	[title drawInRect:titleBox withAttributes:titleAttributes];
//    [[NSString stringWithFormat:@"%@ - %@", subtitle, subSubtitle] drawInRect:subtitleBox withAttributes:subtitleAttributes];
	[subtitle drawInRect:subtitleBox withAttributes:subtitleAttributes];
//    [subSubtitle drawInRect:subSubtitleBox withAttributes:subtitleAttributes];
}

- (NSRect)expansionFrameWithFrame:(NSRect)cellFrame inView:(NSView *)view
{
    return NSZeroRect;
}

@end