#import <Cocoa/Cocoa.h>

@class PRDb; 
@class PRNowPlayingController; 
@class PRMainWindowController; 
@class PRFolderMonitor; 
@class PRTaskManager; 
@class PRGrowl; 
@class PRLastfm; 
@class PRMediaKeyController; 
@class PRHotKeyController;


@interface PRCore : NSObject <NSApplicationDelegate>
/* Accessors */
@property (readonly) PRDb *db;
@property (readonly) PRMainWindowController *win;
@property (readonly) PRNowPlayingController *now;
@property (readonly) NSOperationQueue *opQueue;
@property (readonly) PRFolderMonitor *folderMonitor;
@property (readonly) PRTaskManager *taskManager;
@property (weak, readonly) NSMenu *mainMenu;
@property (readonly) PRLastfm *lastfm;
@property (readonly) PRMediaKeyController *keys;
@property (readonly) PRHotKeyController *hotKeys;

/* Actions */
- (void)itunesImport:(id)sender;
- (IBAction)showOpenPanel:(id)sender;
@end
