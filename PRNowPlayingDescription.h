#import <Foundation/Foundation.h>

@interface PRNowPlayingDescription : NSObject
@property (readonly) NSArray *invalidItems;
@property (readonly) PRList *currentList;
@property (readonly) PRItem *currentItem;
@property (readonly) NSInteger currentIndex; // 0 based
@property (readonly) BOOL shuffle;
@property (readonly) NSInteger repeat;
@end

@interface PRMoviePlayerDescription : NSObject
@property (readonly) BOOL isPlaying;
@property (readonly) CGFloat volume;
@property (readonly) long currentTime;
@property (readonly) long duration;
@end
