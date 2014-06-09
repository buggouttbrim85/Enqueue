#import "PRAlbumArtController.h"
#import "PRDb.h"
#import "PRLibrary.h"
#import "PRDefaults.h"
#import "NSFileManager+DirectoryLocations.h"
#import "NSImage+Extensions.h"


@interface PRAlbumArtController ()
/* Priv */
- (NSString *)cachedArtworkPathForItem:(PRItem *)item;
- (int)nextTempValue;
- (NSString *)tempArtPathForTempValue:(int)temp;
@end


@implementation PRAlbumArtController

#pragma mark - Initialization

- (id)initWithDb:(PRDb *)db {
    if (!(self = [super init])){return nil;}
    _tempIndex = 0; 
    _fileManager = [[NSFileManager alloc] init];
    _db = db;
	return self;
}


#pragma mark - Accessors

- (NSImage *)artworkForItem:(PRItem *)item {
    return [self artworkForItems:[NSArray arrayWithObject:item]];
}

- (NSImage *)artworkForItems:(NSArray *)items {
	// Cached album art
    NSMutableString *string = [NSMutableString stringWithString:@"SELECT file_id FROM library WHERE file_id IN ("];
    for (PRItem *i in items) {
		[string appendFormat:@"%llu, ", [i unsignedLongLongValue]];
	}
    [string deleteCharactersInRange:NSMakeRange([string length] - 2, 1)];
    [string appendString:@") AND albumArt = 1"];
    NSArray *results = [_db execute:string bindings:nil columns:@[PRColInteger]];
    for (NSArray *i in results) {
        PRItem *item = [i objectAtIndex:0];
        BOOL isDirectory;
        BOOL fileExists = [_fileManager fileExistsAtPath:[self cachedArtworkPathForItem:item] isDirectory:&isDirectory];
        if (fileExists && !isDirectory) {
            NSImage *albumArt = [[NSImage alloc] initWithContentsOfFile:[self cachedArtworkPathForItem:item]];
            if (!albumArt || ![albumArt isValid]) {
                [self clearArtworkForItem:item];
            } else {
                return albumArt;
            }
        }
    }
    
    // Artwork in Folder
    if (![[PRDefaults sharedDefaults] boolForKey:PRDefaultsFolderArtwork]) {
        return nil;
    }
    string = [NSMutableString stringWithString:@"SELECT path FROM library WHERE file_id IN ("];
	for (PRItem *i in items) {
		[string appendFormat:@"%d, ", [i intValue]];
	}
    [string deleteCharactersInRange:NSMakeRange([string length] - 2, 1)];
    [string appendString:@")"];
    results = [_db execute:string bindings:nil columns:@[PRColString]];
    NSMutableSet *paths = [NSMutableSet set];
    for (NSArray *i in results) {
        NSURL *URL = [NSURL URLWithString:[i objectAtIndex:0]];
        URL = [NSURL fileURLWithPath:[[URL path] stringByDeletingLastPathComponent]];
        if (!URL || [paths containsObject:[URL absoluteString]]) {
            continue;
        } else {
            [paths addObject:[URL absoluteString]];
        }
        NSError *error;
        NSArray *directoryURLs = [_fileManager contentsOfDirectoryAtURL:URL 
                                            includingPropertiesForKeys:@[] 
															   options:0 
																 error:&error];
        if (!directoryURLs) {
            continue;
        }
        for (NSURL *directoryURL in directoryURLs) {
            NSString *pathExtension = [directoryURL pathExtension];
            if ([pathExtension caseInsensitiveCompare:@"jpg"] == NSOrderedSame ||
                [pathExtension caseInsensitiveCompare:@"jpeg"] == NSOrderedSame ||
                [pathExtension caseInsensitiveCompare:@"png"] == NSOrderedSame) {
                NSImage *albumArt = [[NSImage alloc] initWithContentsOfFile:[directoryURL path]];
                if (albumArt && [albumArt isValid]) {
                    return albumArt;
                }
            }
        }
    }
    return nil;
}

- (NSImage *)artworkForArtist:(NSString *)artist {
	NSString *string = [NSString stringWithFormat:@"SELECT file_id FROM library WHERE %@ COLLATE NOCASE2 = ?1",
                        ([[PRDefaults sharedDefaults] boolForKey:PRDefaultsUseAlbumArtist] ? @"artistAlbumArtist" : @"artist")];
    NSArray *results = [_db execute:string bindings:@{@1:artist} columns:@[PRColInteger]];
    NSMutableArray *items = [NSMutableArray array];
    for (NSArray *i in results) {
        [items addObject:[i objectAtIndex:0]];
    }
	return [self artworkForItems:items];
}

- (void)clearArtworkForItem:(PRItem *)item {
    [_fileManager removeItemAtPath:[self cachedArtworkPathForItem:item] error:nil];
    [[_db library] setValue:@0 forItem:item attr:PRItemAttrArtwork];
}

#pragma mark - Async Accessors

- (NSDictionary *)artworkInfoForItem:(PRItem *)item {
    return [self artworkInfoForItems:@[item]];
}

- (NSDictionary *)artworkInfoForItems:(NSArray *)items {
	// Embedded Artwork 
	NSMutableString *string = [NSMutableString stringWithString:@"SELECT file_id FROM library WHERE file_id IN ("];
	for (PRItem *i in items) {
		[string appendFormat:@"%d, ", [i intValue]];
	}
    [string deleteCharactersInRange:NSMakeRange([string length] - 2, 1)];
    [string appendString:@") AND albumArt = 1"];
    NSArray *results = [_db execute:string bindings:nil columns:@[PRColInteger]];
    
    NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
    for (NSArray *i in results) {
        [indexSet addIndex:[[i objectAtIndex:0] intValue]];
    }
    
    // Folder Artwork
    if (![[PRDefaults sharedDefaults] boolForKey:PRDefaultsFolderArtwork]) {
        return @{@"files":indexSet, @"paths":@[]};
    }
    
    string = [NSMutableString stringWithString:@"SELECT path FROM library WHERE file_id IN ("];
    for (PRItem *i in items) {
		[string appendFormat:@"%d, ", [i intValue]];
	}        
    [string deleteCharactersInRange:NSMakeRange([string length] - 2, 1)];
    [string appendString:@")"];
    results = [_db execute:string bindings:nil columns:@[PRColString]];
    
    NSMutableArray *paths = [NSMutableArray array];
    for (NSArray *i in results) {
        [paths addObject:[i objectAtIndex:0]];
    }
    return @{@"files":indexSet,@"paths":paths};
}

- (NSDictionary *)artworkInfoForArtist:(NSString *)artist {
    NSString *string = [NSString stringWithFormat:@"SELECT file_id FROM library WHERE %@ COLLATE NOCASE2 = ?1",
                        ([[PRDefaults sharedDefaults] boolForKey:PRDefaultsUseAlbumArtist] ? @"artistAlbumArtist" : @"artist")];
    NSArray *results = [_db execute:string bindings:@{@1:artist} columns:@[PRColInteger]];
    NSMutableArray *items = [NSMutableArray array];
    for (NSArray *i in results) {
        [items addObject:[i objectAtIndex:0]];
    }
    return [self artworkInfoForItems:items];
}

- (NSImage *)artworkForArtworkInfo:(NSDictionary *)info {
    NSIndexSet *files = [info objectForKey:@"files"];
    NSArray *paths = [info objectForKey:@"paths"];
    
    NSInteger file = [files firstIndex];
    while (file != NSNotFound) {
		PRItem *item = [PRItem numberWithInt:file];
        BOOL isDirectory;
        BOOL fileExists = [_fileManager fileExistsAtPath:[self cachedArtworkPathForItem:item] isDirectory:&isDirectory];
        if (fileExists && !isDirectory) {
            NSImage *albumArt = [[NSImage alloc] initWithContentsOfFile:[self cachedArtworkPathForItem:item]];
            if (albumArt || [albumArt isValid]) {
                return albumArt;
            } 
        }
        file = [files indexGreaterThanIndex:file];
    }
    
    NSMutableSet *folderPaths = [NSMutableSet set];
    for (NSString *path in paths) {
        NSURL *URL = [NSURL URLWithString:path];
        URL = [NSURL fileURLWithPath:[[URL path] stringByDeletingLastPathComponent]];
        if (!URL || [folderPaths containsObject:[URL absoluteString]]) {
            continue;
        }
        [folderPaths addObject:[URL absoluteString]];
        NSError *error;
        NSArray *contents = [_fileManager contentsOfDirectoryAtURL:URL 
										includingPropertiesForKeys:@[] 
														   options:0 
															 error:&error];
        if (!contents) {
            continue;
        }
        for (NSURL *content in contents) {
            NSString *pathExtension = [content pathExtension];
            if ([pathExtension caseInsensitiveCompare:@"jpg"] == NSOrderedSame ||
                [pathExtension caseInsensitiveCompare:@"jpeg"] == NSOrderedSame ||
                [pathExtension caseInsensitiveCompare:@"png"] == NSOrderedSame) {
                NSImage *albumArt = [[NSImage alloc] initWithContentsOfFile:[content path]];
                if (albumArt && [albumArt isValid]) {
                    return albumArt;
                }
            }
        }
    }

    return nil;
}

- (void)setTempArtwork:(int)temp forItem:(PRItem *)item {
    if (temp == 0) {
		[_fileManager removeItemAtPath:[self cachedArtworkPathForItem:item] error:nil];
        return;
    }
    NSString *path = [self tempArtPathForTempValue:temp];
    NSString *path2 = [self cachedArtworkPathForItem:item];
    if (![_fileManager findOrCreateDirectoryAtPath:[path2 stringByDeletingLastPathComponent] error:nil]) {return;}
    NSURL *URL = [NSURL fileURLWithPath:path];
    NSURL *URL2 = [NSURL fileURLWithPath:path2];
    [_fileManager moveItemAtURL:URL toURL:URL2 error:nil];
}

- (int)saveTempArtwork:(NSImage *)image {
    if (![image isValid]) {
        return 0;
    }
    NSData *data = [image jpegRepresentationWithCompressionFactor:0.8];
    int tempValue = [self nextTempValue];
    if (tempValue == 0) {
        return 0;
    }
    NSString *path = [self tempArtPathForTempValue:tempValue];
	if (![data writeToFile:path atomically:TRUE]) {
		return 0;
	}
    return tempValue;
}

- (void)clearTempArtwork {
    _tempIndex = 1;
    [_fileManager removeItemAtURL:[NSURL fileURLWithPath:[[PRDefaults sharedDefaults] tempArtPath]] error:nil];
    [_fileManager findOrCreateDirectoryAtPath:[[PRDefaults sharedDefaults] tempArtPath] error:nil];
}

#pragma mark - Priv

- (NSString *)cachedArtworkPathForItem:(PRItem *)item {
	unsigned long long file = [item unsignedLongLongValue];
    NSString *path = [[PRDefaults sharedDefaults] cachedAlbumArtPath];
	path = [path stringByAppendingPathComponent:[NSString stringWithFormat:@"%03llu", ((file / 1000000) % 1000)]];
	path = [path stringByAppendingPathComponent:[NSString stringWithFormat:@"%03llu", ((file / 1000) % 1000)]];
	path = [path stringByAppendingPathComponent:[NSString stringWithFormat:@"%09llu", file]];
	return path;
}

- (int)nextTempValue {
    while (_tempIndex < 1000) {
        NSString *tempPath = [self tempArtPathForTempValue:_tempIndex];
        BOOL exists = [_fileManager fileExistsAtPath:tempPath];
        if (!exists) {
            return _tempIndex;;
        }
        _tempIndex++;
    }
    return 0;
}

- (NSString *)tempArtPathForTempValue:(int)temp {
    NSString *path = [[PRDefaults sharedDefaults] tempArtPath];
	return [path stringByAppendingPathComponent:[NSString stringWithFormat:@"%03d", temp]];
}

@end
