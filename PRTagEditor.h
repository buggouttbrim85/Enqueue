#import <Cocoa/Cocoa.h>
#include <CoreFoundation/CoreFoundation.h>
#import "PRLibrary.h"

@class PRDb, PRLibrary, PRAlbumArtController;

typedef enum {
    PRFileTypeUnknown,
    PRFileTypeAPE,
    PRFileTypeASF,
    PRFileTypeFLAC,
    PRFileTypeMP4,
    PRFileTypeMPC,
    PRFileTypeMPEG,
    PRFileTypeOggFLAC,
    PRFileTypeOggVorbis,
    PRFileTypeOggSpeex,
    PRFileTypeAIFF,
    PRFileTypeWAV,
    PRFileTypeTrueAudio,
    PRFileTypeWavPack,
} PRFileType;

@interface PRTagEditor : NSObject 
{
    NSURL *URL;
    void *taglibFile;
    PRFileType fileType;
    PRFile file;
        
	PRDb *db;
}

// ========================================
// Initialization

- (id)initWithFile:(PRFile)file_ db:(PRDb *)db_;
- (id)initWithURL:(NSURL *)URL_ db:(PRDb *)db_;

// ========================================
// Accessors

- (void)setFile:(PRFile)file_;
- (void)setValue:(id)value forAttribute:(PRFileAttribute)attribute postNotification:(BOOL)post;

// ========================================
// Update

- (void)updateTagsAndPostNotification:(BOOL)post;
- (void)addFile:(PRFile *)file withAttributes:(NSDictionary *)attributes;

// ========================================
// Tag Reading 

+ (NSDate *)lastModifiedForFileAtPath:(NSString *)path;
+ (NSData *)checkSumForFileAtPath:(NSString *)path;
+ (NSNumber *)sizeForFileAtPath:(NSString *)path;

@end