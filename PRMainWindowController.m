#import "PRMainWindowController.h"
#import "PRDb.h"
#import "PRNowPlayingController.h"
#import "PRControlsViewController.h"
#import "PRPlaylists.h"
#import "PRTaskManagerViewController.h"
#import "PRNowPlayingViewController.h"
#import "PRLibraryViewController.h"
#import "PRPreferencesViewController.h"
#import "PRPlaylistsViewController.h"
#import "PRHistoryViewController.h"
#import "PRCore.h"
#import "PRPlaylists+Extensions.h"
#import "PRTaskManager.h"
#import "PRGradientView.h"
#import "PRWelcomeSheetController.h"
#import "PRMainMenuController.h"
#import "PRUserDefaults.h"
#import "PRTimeFormatter2.h"
#import "PRSizeFormatter.h"
#import "YRKSpinningProgressIndicator.h"
#import "PRTableViewController.h"
#import "PRStringFormatter.h"
#import <Quartz/Quartz.h>
#import "NSWindow+Extensions.h"
#import "NSOperationQueue+Extensions.h"


@interface NSWindow (hush)
- (void)setBottomCornerRounded:(BOOL)rounded;
@end

@interface PRMainWindowController ()

// ========================================
// Update

// Updates searchField
- (void)playlistDidChange:(NSNotification *)notification;

// update subBar
- (void)libraryViewDidChange:(NSNotification *)notification;

- (void)playlistsDidChange:(NSNotification *)notification;

- (void)windowWillEnterFullScreen:(NSNotification *)notification;
- (void)windowWillExitFullScreen:(NSNotification *)notification;

// ========================================
// Accessors

// Accessors for search field and segmented control bindings
- (NSString *)search;
- (void)setSearch:(NSString *)newSearch;
- (int)libraryViewMode;
- (void)setLibraryViewMode:(int)libraryViewMode;

@end

@implementation PRMainWindowController

// ========================================
// Initialization
// ========================================

- (id)initWithCore:(PRCore *)core
{
	if (!(self = [super initWithWindowNibName:@"PRMainWindow"])) {return nil;}
    _core = core;
    _db = [core db];
    _mode = PRLibraryMode;
    currentPlaylist = 0;
    _playlistMenu = [[NSMenu alloc] init];
    _libraryViewMenu = [[NSMenu alloc] init];
	return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
     
    [_playlistMenu release];
    [_libraryViewMenu release];
    
    [mainMenuController release];
    [libraryViewController release];
    [preferencesViewController release];
    [playlistsViewController release];
    [historyViewController release];
    [nowPlayingViewController release];
    [controlsViewController release];
    [super dealloc];
}

- (void)awakeFromNib
{
    [centerSuperview retain];
    [controlsSuperview retain];
    [_splitView retain];
    [nowPlayingSuperview retain];
    
    // Main Menu
    mainMenuController = [[PRMainMenuController alloc] initWithCore:_core];
    
	// Window
    [[self window] setDelegate:self];
    
    // Toolbar View
    float temp = 0;//185
    [toolbarView setTopBorder:[NSColor colorWithCalibratedWhite:1.0 alpha:0.6]];
    [toolbarView setBotBorder:[NSColor colorWithCalibratedWhite:0.5 alpha:1.0]];
    [toolbarView setFrame:NSMakeRect(temp, [[self window] frame].size.height - [toolbarView frame].size.height, 
                                     [[self window] frame].size.width - temp, [toolbarView frame].size.height)];    

    // Window Buttons
    if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_6) {
        [[self window] setCollectionBehavior:[[self window] collectionBehavior] | NSWindowCollectionBehaviorFullScreenPrimary];
    }
        
    [[[[self window] contentView] superview] addSubview:toolbarView];
    
    [_verticalDivider setColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.2]];
    [_verticalDivider setBotBorder:[NSColor colorWithCalibratedWhite:1.0 alpha:0.8]];
    	
    // ViewControllers
    libraryViewController = [[PRLibraryViewController alloc] initWithCore:_core];
    preferencesViewController = [[PRPreferencesViewController alloc] initWithCore:_core];
	playlistsViewController = [[PRPlaylistsViewController alloc] initWithCore:_core];
    historyViewController = [[PRHistoryViewController alloc] initWithDb:_db mainWindowController:self];
    taskManagerViewController = [[PRTaskManagerViewController alloc] initWithCore:(PRCore *)_core];
    
    nowPlayingViewController = [[PRNowPlayingViewController alloc] initWithDb:_db nowPlayingController:[_core now] mainWindowController:self];
    [[nowPlayingViewController view] setFrame:[nowPlayingSuperview bounds]];
    [nowPlayingSuperview addSubview:[nowPlayingViewController view]];
	
    controlsViewController = [[PRControlsViewController alloc] initWithCore:_core];
    [[controlsViewController view] setFrame:[controlsSuperview bounds]];
    [controlsSuperview addSubview:[controlsViewController view]];
    	
    // Initialize currentViewController
    [[libraryViewController view] setFrame:[centerSuperview bounds]];
    [centerSuperview addSubview:[libraryViewController view]];
    currentViewController = libraryViewController;
    [self setCurrentPlaylist:[[_db playlists] libraryPlaylist]];
    [self setCurrentMode:PRLibraryMode];
		    
    // Info button
    [infoButton setTarget:libraryViewController];
    [infoButton setAction:@selector(infoViewToggle)];
    
	// Search Field
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:@"", NSNullPlaceholderBindingOption, nil];
    PRStringFormatter *stringFormatter = [[[PRStringFormatter alloc] init] autorelease];
    [stringFormatter setMaxLength:80];
	[searchField bind:@"value" toObject:self withKeyPath:@"search" options:options];
    [searchField setFormatter:stringFormatter];
    	    
    // miniplayer
    [centerSuperview retain];
    BOOL mini = [self miniPlayer];
    [self setMiniPlayer:FALSE];
    [self setMiniPlayer:mini];
    
    // Playlist Buttons
    [_clearPlaylistButton setTarget:nowPlayingViewController];
    [_clearPlaylistButton setAction:@selector(clearPlaylist)];
    [_playlistPopupButton setMenu:_playlistMenu];
    [_playlistMenu setDelegate:self];
    [_playlistMenu setAutoenablesItems:FALSE];
    
    // LibraryView Button
    [_libraryViewPopupButton setMenu:_libraryViewMenu];
    [_libraryViewMenu setDelegate:self];
    [_libraryViewMenu setAutoenablesItems:FALSE];
    
	// Buttons
    for (NSDictionary *i in [NSArray arrayWithObjects:
                             [NSDictionary dictionaryWithObjectsAndKeys:libraryButton, @"button", [NSNumber numberWithInt:PRLibraryMode], @"tag", nil], 
                             [NSDictionary dictionaryWithObjectsAndKeys:playlistsButton, @"button", [NSNumber numberWithInt:PRPlaylistsMode], @"tag", nil], 
                             [NSDictionary dictionaryWithObjectsAndKeys:historyButton, @"button", [NSNumber numberWithInt:PRHistoryMode], @"tag", nil], 
                             [NSDictionary dictionaryWithObjectsAndKeys:preferencesButton, @"button", [NSNumber numberWithInt:PRPreferencesMode], @"tag", nil], 
                             nil]) {
        NSButton *button = [i objectForKey:@"button"];
        int tag = [[i objectForKey:@"tag"] intValue];
        [button setAction:@selector(headerButtonAction:)];
        [button setTarget:self];
        [button setTag:tag];
    }
    
    // artwork
    [[controlsViewController albumArtView] retain];
    [[controlsViewController albumArtView] removeFromSuperview];
    [nowPlayingSuperview addSubview:[controlsViewController albumArtView]];
    
    // SplitView
    [_splitView setDelegate:self];
    
	// Update
    [[NSNotificationCenter defaultCenter] observePlaylistChanged:self sel:@selector(playlistDidChange:)];
    [[NSNotificationCenter defaultCenter] observePlaylistsChanged:self sel:@selector(playlistsDidChange:)];
    [[NSNotificationCenter defaultCenter] observeLibraryViewChanged:self sel:@selector(libraryViewDidChange:)];
    [[NSNotificationCenter defaultCenter] observeInfoViewVisibleChanged:self sel:@selector(updateUI)];
    
    if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_6) {
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(windowWillEnterFullScreen:) 
                                                     name:NSWindowWillEnterFullScreenNotification 
                                                   object:[self window]];
        [[NSNotificationCenter defaultCenter] addObserver:self 
                                                 selector:@selector(windowWillExitFullScreen:) 
                                                     name:NSWindowWillExitFullScreenNotification 
                                                   object:[self window]];
    }
}

// ========================================
// Accessors
// ========================================

@synthesize mainMenuController;
@synthesize taskManagerViewController;
@synthesize libraryViewController;
@synthesize historyViewController;
@synthesize playlistsViewController;
@synthesize preferencesViewController;
@synthesize nowPlayingViewController;
@synthesize controlsViewController;

@dynamic currentMode;
@dynamic currentPlaylist;
@dynamic showsArtwork;
@dynamic miniPlayer;

- (PRMode)currentMode
{
    return _mode;
}

- (void)setCurrentMode:(PRMode)mode
{
    _mode = mode;
    id newViewController;
	switch (_mode) {
		case PRLibraryMode:
			newViewController = libraryViewController;
			break;
		case PRPlaylistsMode:
			newViewController = playlistsViewController;
			break;
		case PRHistoryMode:
			newViewController = historyViewController;
			[historyViewController update];
			break;
		case PRPreferencesMode:
			newViewController = preferencesViewController;
			break;
		default:
            [PRException raise:NSInternalInconsistencyException format:@"Invalid Mode"];return;
			break;
	}
    [[newViewController view] setFrame:[centerSuperview bounds]];
	[centerSuperview replaceSubview:[currentViewController view] with:[newViewController view]];
	currentViewController = newViewController;
    [self updateUI];
	[self willChangeValueForKey:@"search"];
	[self didChangeValueForKey:@"search"];
}

- (PRPlaylist)currentPlaylist
{
    return currentPlaylist;
}

- (void)setCurrentPlaylist:(PRPlaylist)playlist_
{
    currentPlaylist = playlist_;
    [libraryViewController setPlaylist:currentPlaylist];
    
    [self updateUI];
    
	[self willChangeValueForKey:@"search"];
	[self didChangeValueForKey:@"search"];
}

- (BOOL)showsArtwork
{
    return [[PRUserDefaults userDefaults] showsArtwork];
}

- (void)setShowsArtwork:(BOOL)showsArtwork
{
    [[PRUserDefaults userDefaults] setShowsArtwork:showsArtwork];
    [self updateSplitView];
}

- (BOOL)miniPlayer
{
    return [[PRUserDefaults userDefaults] miniPlayer];
}

- (void)setMiniPlayer:(BOOL)miniPlayer
{
    [[PRUserDefaults userDefaults] setMiniPlayer:miniPlayer];
    
    NSRect winFrame;
    if ([self miniPlayer]) {
        winFrame = [[PRUserDefaults userDefaults] miniPlayerFrame];
        if (NSEqualRects(winFrame, NSZeroRect)) {
            winFrame.origin.x = [[self window] frame].origin.x;
            winFrame.origin.y = [[self window] frame].origin.y;
            winFrame.size.height = 500;
        }
        if (winFrame.size.height < 400 && winFrame.size.height != 140) {
            winFrame.size.height = 400;
        }
        winFrame.size.width = 215;        
    } else {
        winFrame = [[PRUserDefaults userDefaults] playerFrame];
        if (NSEqualRects(winFrame, NSZeroRect)) {
            winFrame.origin.x = [[self window] frame].origin.x;
            winFrame.origin.y = [[self window] frame].origin.y;
            winFrame.size.height = 700;
            winFrame.size.width = 1000;
        }
        if (winFrame.size.height < 500) {
            winFrame.size.height = 500;
        }
        if (winFrame.size.width < 700+185) {
            winFrame.size.width = 700+185;
        }
    }
    [self updateLayoutWithFrame:winFrame];
}

- (void)toggleMiniPlayer
{
    [self setMiniPlayer:![self miniPlayer]];
}

// ========================================
// UI
// ========================================

- (void)updateLayoutWithFrame:(NSRect)winFrame
{
    [[self window] setDelegate:nil];
    [_splitView setDelegate:nil];
        
    for (id i in [NSArray arrayWithObjects:_verticalDivider,libraryButton,playlistsButton, historyButton, preferencesButton, infoButton, _libraryViewPopupButton, searchField, nil]) {
        [i setHidden:[self miniPlayer]];
    }
    [toolbarView setHidden:([self miniPlayer] && winFrame.size.height == 140)];
    
    if ([self miniPlayer] && winFrame.size.height != 140) {
        // FULLSCREEN
        if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_6 && [[self window] collectionBehavior] & NSWindowCollectionBehaviorFullScreenPrimary) {
            [[self window] setCollectionBehavior:[[self window] collectionBehavior] ^ NSWindowCollectionBehaviorFullScreenPrimary];
        }
        
        NSRect frame;
        // CONTROLS
        frame.origin.x = 0;
        frame.origin.y = 0;
        frame.size.height = 125;
        frame.size.width = winFrame.size.width;
        [controlsSuperview setFrame:frame];
        [controlsSuperview setAutoresizingMask:NSViewMaxXMargin|NSViewMaxYMargin];
        [[self controlsViewController] updateLayout];
        
        // SPLIT VIEW
        [_splitView removeFromSuperview];
        
        // NOW PLAYING
        [nowPlayingSuperview removeFromSuperview];
        [[[self window] contentView] addSubview:nowPlayingSuperview];
        frame.origin.x = 0;
        frame.origin.y = 125; 
        frame.size.height = winFrame.size.height - 30 - frame.origin.y;
        frame.size.width = winFrame.size.width;
        [nowPlayingSuperview setFrame:frame];
        [nowPlayingSuperview setAutoresizingMask:NSViewMaxXMargin|NSViewMaxYMargin];
        
        // CENTER
        [centerSuperview removeFromSuperview];
        
        // WINDOW
        [[self window] setFrame:winFrame display:TRUE animate:FALSE];
        [[self window] setMinSize:NSMakeSize(215, 140)]; // min 140 / 400
        [[self window] setMaxSize:NSMakeSize(215, 10000)];
        [controlsSuperview setAutoresizingMask:NSViewMaxYMargin|NSViewWidthSizable];
        [nowPlayingSuperview setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
    } else if ([self miniPlayer]) {
        // FULLSCREEN
        if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_6 && [[self window] collectionBehavior] & NSWindowCollectionBehaviorFullScreenPrimary) {
            [[self window] setCollectionBehavior:[[self window] collectionBehavior] ^ NSWindowCollectionBehaviorFullScreenPrimary];
        }
        
        NSRect frame;
        // CONTROLS
        frame.origin.x = 0;
        frame.origin.y = 0;
        frame.size.height = 125;
        frame.size.width = winFrame.size.width;
        [controlsSuperview setFrame:frame];
        [controlsSuperview setAutoresizingMask:NSViewMaxXMargin|NSViewMaxYMargin];
        [[self controlsViewController] updateLayout];
        
        // SPLIT VIEW
        [_splitView removeFromSuperview];
        
        // NOW PLAYING
        [nowPlayingSuperview removeFromSuperview];
        
        // CENTER
        [centerSuperview removeFromSuperview];
        
        // WINDOW
        [[self window] setFrame:winFrame display:TRUE animate:FALSE];
        [[self window] setMinSize:NSMakeSize(215, 140)]; // min 140 / 400
        [[self window] setMaxSize:NSMakeSize(215, 10000)];
        [controlsSuperview setAutoresizingMask:NSViewMaxYMargin|NSViewWidthSizable];
    } else {
        // FULLSCREEN
        if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_6) {
            [[self window] setCollectionBehavior:[[self window] collectionBehavior] | NSWindowCollectionBehaviorFullScreenPrimary];
        }
        
        NSRect frame;
        // CONTROLS
        frame.origin.x = 0;
        frame.origin.y = 0;
        frame.size.height = 54;
        frame.size.width = winFrame.size.width;
        [controlsSuperview setFrame:frame];
        [controlsSuperview setAutoresizingMask:NSViewMaxXMargin|NSViewMaxYMargin];
        [[self controlsViewController] updateLayout];
        
        // SPLIT VIEW
        [[[self window] contentView] addSubview:_splitView];
        frame.origin.x = 0;
        frame.origin.y = 54;
        frame.size.height = winFrame.size.height - 30 - 54;
        frame.size.width = winFrame.size.width;
        [_splitView setFrame:frame];
        [_splitView setAutoresizingMask:NSViewMaxXMargin|NSViewMaxYMargin];
        
        // NOW PLAYING
        [nowPlayingSuperview removeFromSuperview];
        [_splitView addSubview:nowPlayingSuperview];
        
        // CENTER
        [centerSuperview removeFromSuperview];
        [_splitView addSubview:centerSuperview];
        
        [_splitView setPosition:[[PRUserDefaults userDefaults] sidebarWidth] ofDividerAtIndex:0];
        
        // WINDOW
        [[self window] setMinSize:NSMakeSize(700+185, 500)];
        [[self window] setMaxSize:NSMakeSize(10000, 10000)];
        [[self window] setFrame:winFrame display:TRUE animate:FALSE];
        [controlsSuperview setAutoresizingMask:NSViewMaxYMargin|NSViewWidthSizable];
        [_splitView setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
        [nowPlayingSuperview setAutoresizingMask:NSViewMaxXMargin|NSViewHeightSizable];
        [centerSuperview setAutoresizingMask:NSViewWidthSizable|NSViewHeightSizable];
    }
    
    [self updateSplitView];
    [self updateUI];
    [self updateWindowButtons];
    
    [[self window] setDelegate:self];
    [_splitView setDelegate:self];
}

- (void)updateSplitView
{
    NSRect frame;
    frame = [_toolbarSubview frame];
    frame.origin.x = [nowPlayingSuperview frame].size.width - 54;
    frame.size.width = [[self window] frame].size.width - [nowPlayingSuperview frame].size.width + 54;
    [_toolbarSubview setFrame:frame];
    
    if (![self miniPlayer] && ([[self window] frame].size.width - [nowPlayingSuperview frame].size.width < 700)) {
        [_splitView setPosition:[[self window] frame].size.width-700 ofDividerAtIndex:0];
    }
    
    if ([[PRUserDefaults userDefaults] showsArtwork]) {
        // size of nowPlayingView
        frame = [nowPlayingSuperview frame];
        frame.size.height -= [nowPlayingSuperview frame].size.width;
        if (frame.size.height < 220) {
            frame.size.height = 220;
        } 
        if ([nowPlayingSuperview frame].size.height - frame.size.height > 500) {
            frame.size.height = [nowPlayingSuperview frame].size.height - 500;
        }
        frame.origin.y = [nowPlayingSuperview frame].size.height - frame.size.height;
        [[nowPlayingViewController view] setFrame:frame];
        
        // size of albumArt
        frame.origin.x = -1;
        frame.origin.y = -2;
        frame.size.width = [nowPlayingSuperview frame].size.width + 2;
        frame.size.height = [nowPlayingSuperview frame].size.height - [[nowPlayingViewController view] frame].size.height + 2;
        [[controlsViewController albumArtView] setFrame:frame];
    } else {
        frame = [nowPlayingSuperview frame];
        [[nowPlayingViewController view] setFrame:frame];
    }
    [[controlsViewController albumArtView] setHidden:![[PRUserDefaults userDefaults] showsArtwork]];
}

- (void)updateUI
{
    // Header buttons
    NSButton *button;
    switch (_mode) {
		case PRLibraryMode:
            if ([self currentPlaylist] == [[_db playlists] libraryPlaylist]) {
                button = libraryButton;
            } else {
                button = playlistsButton;
            }
			break;
		case PRPlaylistsMode:
            button = playlistsButton;
			break;
		case PRHistoryMode:
            button = historyButton;
			break;
		case PRPreferencesMode:
            button = preferencesButton;
			break;
		default:
            button = libraryButton;
			break;
	}
    for (NSButton *i in [NSArray arrayWithObjects:libraryButton,playlistsButton,historyButton,preferencesButton,nil]) {
        [i setState:NSOffState];
    }
    [button setState:NSOnState];
    
    // Library view mode buttons
    if (![self miniPlayer]) {
        [searchField setHidden:(_mode != PRLibraryMode)];
        [infoButton setHidden:(_mode != PRLibraryMode)];
        [_libraryViewPopupButton setHidden:(_mode != PRLibraryMode)];
    }
    [self menuNeedsUpdate:_libraryViewMenu];
    
    if ([libraryViewController infoViewVisible]) {
        [infoButton setImage:[NSImage imageNamed:@"InfoAlt"]];
    } else {
        [infoButton setImage:[NSImage imageNamed:@"Info"]];
    }
    
    // Playlist title
    [playlistTitle setHidden:!(_mode == PRLibraryMode)];
    if (_mode != PRLibraryMode) {
        NSString *title;
        PRPlaylistType type = [[_db playlists] typeForPlaylist:currentPlaylist];
        if (type == PRLibraryPlaylistType) {
            title = @" ";
        } else {
            title = [[_db playlists] titleForPlaylist:currentPlaylist];
        }
        
        NSShadow *shadow = [[[NSShadow alloc] init] autorelease];
        [shadow setShadowColor:[NSColor colorWithDeviceWhite:1.0 alpha:0.5]];
        [shadow setShadowOffset:NSMakeSize(1.1, -1.3)];
        NSMutableParagraphStyle *centerAlign = [[[NSMutableParagraphStyle alloc] init] autorelease];
        [centerAlign setAlignment:NSLeftTextAlignment];
        [centerAlign setLineBreakMode:NSLineBreakByTruncatingTail];
        NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [NSFont systemFontOfSize:12], NSFontAttributeName,
                                    [NSColor colorWithDeviceWhite:0.4 alpha:1.0], NSForegroundColorAttributeName,
                                    centerAlign, NSParagraphStyleAttributeName,
                                    shadow, NSShadowAttributeName,
                                    nil];
        NSMutableAttributedString *attributedString = [[[NSMutableAttributedString alloc] initWithString:title attributes:attributes] autorelease];
        
        // other
        PRTimeFormatter2 *timeFormatter2 = [[[PRTimeFormatter2 alloc] init] autorelease];
        PRSizeFormatter *sizeFormatter = [[[PRSizeFormatter alloc] init] autorelease];
        NSDictionary *userInfo = [(PRTableViewController *)[libraryViewController currentViewController] info];
        NSString *formattedString = [NSString stringWithFormat:@"%@ songs, %@, %@", 
                                     [userInfo valueForKey:@"count"], 
                                     [timeFormatter2 stringForObjectValue:[userInfo valueForKey:@"time"]], 
                                     [sizeFormatter stringForObjectValue:[userInfo valueForKey:@"size"]]];
        
        NSMutableDictionary *attributes2 = [[[NSMutableDictionary alloc] initWithObjectsAndKeys:
                                             [NSFont systemFontOfSize:11], NSFontAttributeName,
                                             [NSColor colorWithDeviceWhite:0.3 alpha:1.0], NSForegroundColorAttributeName,
                                             shadow, NSShadowAttributeName,
                                             centerAlign, NSParagraphStyleAttributeName,				  
                                             nil] autorelease];
        [attributedString appendAttributedString:[[[NSAttributedString alloc] initWithString:formattedString attributes:attributes2] autorelease]];
        [attributedString addAttributes:[NSDictionary dictionaryWithObject:centerAlign forKey:NSParagraphStyleAttributeName]
                                  range:NSMakeRange(0, [attributedString length])];
        
        [playlistTitle setAttributedStringValue:attributedString];
    }
}

- (void)updateWindowButtons
{
    // Window Buttons
    if ([self miniPlayer] && [[self window] frame].size.height == 140) {
        
    } else {
        float x = 10;
        for (NSButton *i in [NSArray arrayWithObjects:
                             [[self window] standardWindowButton:NSWindowCloseButton],
                             [[self window] standardWindowButton:NSWindowMiniaturizeButton],
                             [[self window] standardWindowButton:NSWindowZoomButton], nil]) {
            NSRect frame = [i frame];
            frame.origin.y = [[self window] frame].size.height - [i bounds].size.height - 7;
            frame.origin.x = x;
            [i setFrame:frame];
            x += 20;
        }
    }
    if (floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_6) {
        NSButton *fullScreen = [[self window] standardWindowButton:NSWindowFullScreenButton];
        NSRect frame = [fullScreen frame];
        frame.origin.y = [[self window] frame].size.height - [fullScreen bounds].size.height - 6;
        frame.origin.x = [[self window] frame].size.width - [fullScreen bounds].size.width - 9;
        [fullScreen setFrame:frame];
    }
}

- (void)find
{
    [[searchField window] makeFirstResponder:searchField];
}

// ========================================
// Update
// ========================================

// Private Methods

- (void)playlistDidChange:(NSNotification *)notification
{
	[self willChangeValueForKey:@"search"];
	[self didChangeValueForKey:@"search"];
    [self updateUI];
}

- (void)libraryViewDidChange:(NSNotification *)notification
{
    [self updateUI];
}

- (void)playlistsDidChange:(NSNotification *)notification
{
    [self updateUI];
}

- (NSString *)search
{
	if (_mode != PRLibraryMode) {
		return nil;
	}
	return [[_db playlists] searchForPlaylist:currentPlaylist];
}

- (void)setSearch:(NSString *)search
{	
	if (_mode != PRLibraryMode) {
		return;
	}
	if (!search) {
		search = @"";
	}
	[[_db playlists] setValue:search forPlaylist:currentPlaylist attribute:PRSearchPlaylistAttribute];
    [[NSNotificationCenter defaultCenter] postPlaylistChanged:currentPlaylist];
}

- (int)libraryViewMode
{
	if (_mode != PRLibraryMode) {
		return -1;
	} else {
		return [libraryViewController libraryViewMode];
	}
}

- (void)setLibraryViewMode:(int)libraryViewMode
{
	if (_mode != PRLibraryMode) {
		return;
	}
	[libraryViewController setLibraryViewMode:libraryViewMode];
}

- (void)headerButtonAction:(id)sender
{
    if ([sender tag] == PRLibraryMode) {
        [self setCurrentPlaylist:[[_db playlists] libraryPlaylist]];
    }
    [self setCurrentMode:[sender tag]];
}

// ========================================
// Window Delegate
// ========================================

- (void)windowWillEnterFullScreen:(NSNotification *)notification
{
    NSRect frame = [_splitView frame];
    frame.size.height = [[self window] frame].size.height - 30 - 54 - 22;
    [_splitView setFrame:frame];
}

- (void)windowWillExitFullScreen:(NSNotification *)notification
{
    _resizingSplitView = TRUE;
//    [_splitView setDelegate:nil];
    NSRect frame = [_splitView frame];
    frame.size.height = [[self window] frame].size.height - 30 - 54 + 22;
    [_splitView setFrame:frame];
    
    if ([[PRUserDefaults userDefaults] playerFrame].size.width - [nowPlayingSuperview frame].size.width < 700) {
        [_splitView setPosition:[[PRUserDefaults userDefaults] playerFrame].size.width - 700 ofDividerAtIndex:0];
    }
}

- (void)windowDidExitFullScreen:(NSNotification *)notification
{
    if ([self window].frame.size.width - [nowPlayingSuperview frame].size.width < 700) {
        [_splitView setPosition:[self window].frame.size.width-700 ofDividerAtIndex:0];
    } else if ([nowPlayingSuperview frame].size.width < 185) {
        [_splitView setPosition:185 ofDividerAtIndex:0];
    }
    [self updateSplitView];
//    [_splitView setDelegate:self];
    _resizingSplitView = FALSE;
}

- (BOOL)windowShouldClose:(id)sender
{
    if (sender == [self window]) {
        [[self window] orderOut:self];
        [NSApp addWindowsItem:[self window] title:@"Enqueue" filename:FALSE];
        return FALSE;
    }
    return TRUE;
}

- (NSRect)window:(NSWindow *)window willPositionSheet:(NSWindow *)sheet usingRect:(NSRect)rect
{
    rect.origin.y -= 8;
    return rect;
}

- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)frameSize
{
    if (![self miniPlayer] && (frameSize.width - [nowPlayingSuperview frame].size.width < 700)) {
        [_splitView setPosition:frameSize.width-700 ofDividerAtIndex:0];
    } else if ([self miniPlayer]) {
        if (frameSize.height < 170) {
            frameSize.height = 140;
            if ([[self window] frame].size.height != 140) {
                _windowWillResize = TRUE;
            }
        } else if (frameSize.height < 400) {
            frameSize.height = 400;
            if ([[self window] frame].size.height == 140) {
                _windowWillResize = TRUE;
            }
        }
    }
    return frameSize;
}

- (void)windowDidResize:(NSNotification *)notification
{
    if (_windowWillResize) {
        [self updateLayoutWithFrame:[[self window] frame]];
        _windowWillResize = FALSE;
    }
    
    if ([[self window] styleMask] & NSFullScreenWindowMask) {
        return;
    }
    [self updateWindowButtons];
    if ([self miniPlayer]) {
        [[PRUserDefaults userDefaults] setMiniPlayerFrame:[[self window] frame]];
    } else {
        [[PRUserDefaults userDefaults] setPlayerFrame:[[self window] frame]];
    }
}

- (void)windowDidMove:(NSNotification *)notification
{
    if ([[self window] styleMask] & NSFullScreenWindowMask) {
        return;
    }
    [self updateWindowButtons];
    if ([self miniPlayer]) {
        [[PRUserDefaults userDefaults] setMiniPlayerFrame:[[self window] frame]];
    } else {
        [[PRUserDefaults userDefaults] setPlayerFrame:[[self window] frame]];
    }
}

// ========================================
// SplitView Delegate
// ========================================

- (void)splitViewDidResizeSubviews:(NSNotification *)note
{
    if (_resizingSplitView) {
        return;
    }
    if ([self window].frame.size.width - [nowPlayingSuperview frame].size.width < 700) {
        if (!([[self window] styleMask] & NSFullScreenWindowMask)) {
            NSRect frame = [[self window] frame];
            frame.size.width = [nowPlayingSuperview frame].size.width + 700;
            [[self window] setFrame:frame display:TRUE];
        } else {
            [_splitView setPosition:[self window].frame.size.width-700 ofDividerAtIndex:0];
        }
    }
    [self updateSplitView];
    [[PRUserDefaults userDefaults] setSidebarWidth:[nowPlayingSuperview frame].size.width];
}

- (BOOL)splitView:(NSSplitView *)splitView shouldAdjustSizeOfSubview:(NSView *)subview
{
    if (subview == nowPlayingSuperview) {
        return FALSE;
    }
    return TRUE;
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainSplitPosition:(CGFloat)proposedPosition ofSubviewAt:(NSInteger)dividerIndex
{
    if (proposedPosition < 185) {
        return 185;
    } else if (proposedPosition > 500) {
        return 500;
    } else {
        return proposedPosition;
    }
}

// ========================================
// Menu Delegate
// ========================================

- (void)menuNeedsUpdate:(NSMenu *)menu
{
    if (menu == _playlistMenu) {
        [_playlistMenu removeAllItems];
        NSMenu *menu = [nowPlayingViewController playlistMenu];
        NSArray *items = [menu itemArray];
        [menu removeAllItems];
        for (NSMenuItem *i in items) {
            [_playlistMenu addItem:i];
        }
    } else if (menu == _libraryViewMenu) {
        [_libraryViewMenu removeAllItems];
        NSMenu *menu = [libraryViewController libraryViewMenu];
        NSArray *items = [menu itemArray];
        [menu removeAllItems];
        for (NSMenuItem *i in items) {
            [_libraryViewMenu addItem:i];
        }
    }
}

@end
