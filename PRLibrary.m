#import "PRLibrary.h"
#import "PRAlbumArtController.h"
#import "PRDb.h"
#import "PRDefaults.h"
#import "PRFileInfo.h"
#import "PRPlaylists.h"
#import "PRTagger.h"
#import "NSArray+Extensions.h"
#import "PRConnection.h"
#import "PRItem_Private.h"

PRItemAttr * const PRItemAttrPath = @"PRItemAttrPath";
PRItemAttr * const PRItemAttrSize = @"PRItemAttrSize";
PRItemAttr * const PRItemAttrKind = @"PRItemAttrKind";
PRItemAttr * const PRItemAttrTime = @"PRItemAttrTime";
PRItemAttr * const PRItemAttrBitrate = @"PRItemAttrBitrate";
PRItemAttr * const PRItemAttrChannels = @"PRItemAttrChannels";
PRItemAttr * const PRItemAttrSampleRate = @"PRItemAttrSampleRate";
PRItemAttr * const PRItemAttrCheckSum = @"PRItemAttrCheckSum";
PRItemAttr * const PRItemAttrLastModified = @"PRItemAttrLastModified";
PRItemAttr * const PRItemAttrTitle = @"PRItemAttrTitle";
PRItemAttr * const PRItemAttrArtist = @"PRItemAttrArtist";
PRItemAttr * const PRItemAttrAlbum = @"PRItemAttrAlbum";
PRItemAttr * const PRItemAttrBPM = @"PRItemAttrBPM";
PRItemAttr * const PRItemAttrYear = @"PRItemAttrYear";
PRItemAttr * const PRItemAttrTrackNumber = @"PRItemAttrTrackNumber";
PRItemAttr * const PRItemAttrTrackCount = @"PRItemAttrTrackCount";
PRItemAttr * const PRItemAttrComposer = @"PRItemAttrComposer";
PRItemAttr * const PRItemAttrDiscNumber = @"PRItemAttrDiscNumber";
PRItemAttr * const PRItemAttrDiscCount = @"PRItemAttrDiscCount";
PRItemAttr * const PRItemAttrComments = @"PRItemAttrComments";
PRItemAttr * const PRItemAttrAlbumArtist = @"PRItemAttrAlbumArtist";
PRItemAttr * const PRItemAttrGenre = @"PRItemAttrGenre";
PRItemAttr * const PRItemAttrCompilation = @"PRItemAttrCompilation";
PRItemAttr * const PRItemAttrLyrics = @"PRItemAttrLyrics";
PRItemAttr * const PRItemAttrArtwork = @"PRItemAttrArtwork";
PRItemAttr * const PRItemAttrArtistAlbumArtist = @"PRItemAttrArtistAlbumArtist";
PRItemAttr * const PRItemAttrDateAdded = @"PRItemAttrDateAdded";
PRItemAttr * const PRItemAttrLastPlayed = @"PRItemAttrLastPlayed";
PRItemAttr * const PRItemAttrPlayCount = @"PRItemAttrPlayCount";
PRItemAttr * const PRItemAttrRating = @"PRItemAttrRating";

NSString * const PR_TBL_LIBRARY_SQL = @"CREATE TABLE library ("
    "file_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "
    "path TEXT NOT NULL UNIQUE, "
    "title TEXT NOT NULL DEFAULT '', "
    "artist TEXT NOT NULL DEFAULT '', "
    "album TEXT NOT NULL DEFAULT '', "
    "albumArtist TEXT NOT NULL DEFAULT '', "
    "composer TEXT NOT NULL DEFAULT '', "
    "comments TEXT NOT NULL DEFAULT '', "
    "genre TEXT NOT NULL DEFAULT '', "
    "year INT NOT NULL DEFAULT 0, "
    "trackNumber INT NOT NULL DEFAULT 0, "
    "trackCount INT NOT NULL DEFAULT 0, "
    "discNumber INT NOT NULL DEFAULT 0, "
    "discCount INT NOT NULL DEFAULT 0, "
    "BPM INT NOT NULL DEFAULT 0, "
    "checkSum BLOB NOT NULL DEFAULT x'', "
    "size INT NOT NULL DEFAULT 0, "
    "kind INT NOT NULL DEFAULT 0, "
    "time INT NOT NULL DEFAULT 0, "
    "bitrate INT NOT NULL DEFAULT 0, "
    "channels INT NOT NULL DEFAULT 0, "
    "sampleRate INT NOT NULL DEFAULT 0, "
    "lastModified TEXT NOT NULL DEFAULT '', "
    "albumArt INT NOT NULL DEFAULT 0, "
    "dateAdded TEXT NOT NULL DEFAULT '', "
    "lastPlayed TEXT NOT NULL DEFAULT '', "
    "playCount INT NOT NULL DEFAULT 0, "
    "rating INT NOT NULL DEFAULT 0 ,"
    "artistAlbumArtist TEXT NOT NULL DEFAULT '' , "
    "lyrics TEXT NOT NULL DEFAULT '', "
    "compilation INT NOT NULL DEFAULT 0"
    ")";
NSString * const PR_TBL_LIBRARY_SQL2 = @"CREATE TABLE library ("
    "file_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "
    "path TEXT NOT NULL UNIQUE, "
    "title TEXT NOT NULL DEFAULT '', "
    "artist TEXT NOT NULL DEFAULT '', "
    "album TEXT NOT NULL DEFAULT '', "
    "albumArtist TEXT NOT NULL DEFAULT '', "
    "composer TEXT NOT NULL DEFAULT '', "
    "comments TEXT NOT NULL DEFAULT '', "
    "genre TEXT NOT NULL DEFAULT '', "
    "year INT NOT NULL DEFAULT 0, "
    "trackNumber INT NOT NULL DEFAULT 0, "
    "trackCount INT NOT NULL DEFAULT 0, "
    "discNumber INT NOT NULL DEFAULT 0, "
    "discCount INT NOT NULL DEFAULT 0, "
    "BPM INT NOT NULL DEFAULT 0, "
    "checkSum BLOB NOT NULL DEFAULT x'', "
    "size INT NOT NULL DEFAULT 0, "
    "kind INT NOT NULL DEFAULT 0, "
    "time INT NOT NULL DEFAULT 0, "
    "bitrate INT NOT NULL DEFAULT 0, "
    "channels INT NOT NULL DEFAULT 0, "
    "sampleRate INT NOT NULL DEFAULT 0, "
    "albumArt INT NOT NULL DEFAULT 0, "
    "dateAdded TEXT NOT NULL DEFAULT '', "
    "lastPlayed TEXT NOT NULL DEFAULT '', "
    "playCount INT NOT NULL DEFAULT 0, "
    "rating INT NOT NULL DEFAULT 0 ,"
    "artistAlbumArtist TEXT NOT NULL DEFAULT '' , "
    "lastModified TEXT NOT NULL DEFAULT '', "
    "lyrics TEXT NOT NULL DEFAULT '', "
    "compilation INT NOT NULL DEFAULT 0"
    ")";
NSString * const PR_IDX_PATH_SQL = @"CREATE INDEX index_path ON library (path COLLATE hfs_compare)";
NSString * const PR_IDX_ALBUM_SQL = @"CREATE INDEX index_album ON library (album COLLATE NOCASE2)";
NSString * const PR_IDX_ARTIST_SQL = @"CREATE INDEX index_artist ON library (artist COLLATE NOCASE2)";
NSString * const PR_IDX_GENRE_SQL = @"CREATE INDEX index_genre ON library (genre COLLATE NOCASE2)";
NSString * const PR_IDX_ARTIST_ALBUM_ARTIST_SQL = @"CREATE INDEX index_artistAlbumArtist ON library (artistAlbumArtist COLLATE NOCASE2)";
NSString * const PR_IDX_COMPILATION_SQL = @"CREATE INDEX index_compilation ON library (compilation)";
NSString * const PR_TRG_ARTIST_ALBUM_ARTIST_SQL = @"CREATE TEMP TRIGGER trg_artistAlbumArtist "
    "AFTER UPDATE OF artist, albumArtist ON library FOR EACH ROW BEGIN "
    "UPDATE library SET artistAlbumArtist = coalesce(nullif(albumArtist, ''), artist) "
    "WHERE file_id = NEW.file_id; END ";
NSString * const PR_TRG_ARTIST_ALBUM_ARTIST_2_SQL = @"CREATE TEMP TRIGGER trg_artistAlbumArtist2 "
    "AFTER INSERT ON library FOR EACH ROW BEGIN "
    "UPDATE library SET artistAlbumArtist = coalesce(nullif(albumArtist, ''), artist) "
    "WHERE file_id = NEW.file_id; END ";


@implementation PRLibrary {
    PRDb *_db;
    __weak PRConnection *_conn;
}

#pragma mark - Initialization

- (id)initWithDb:(PRDb *)db {
    if (!(self = [super init])) {return nil;}
    _db = db;
    return self;
}

- (instancetype)initWithConnection:(PRConnection *)connection {
    if ((self = [super init])) {
        _conn = connection;
        [_conn zExecute:PR_TRG_ARTIST_ALBUM_ARTIST_SQL];
        [_conn zExecute:PR_TRG_ARTIST_ALBUM_ARTIST_2_SQL];
        [_conn zExecute:@"UPDATE library SET artistAlbumArtist = coalesce(nullif(albumArtist, ''), artist) "
            "WHERE artistAlbumArtist != coalesce(nullif(albumArtist, ''), artist)"];
    }
    return self;
}

- (void)create {
    [(PRDb*)(_db?:_conn) zExecute:PR_TBL_LIBRARY_SQL];
    [(PRDb*)(_db?:_conn) zExecute:PR_IDX_PATH_SQL];
    [(PRDb*)(_db?:_conn) zExecute:PR_IDX_ALBUM_SQL];
    [(PRDb*)(_db?:_conn) zExecute:PR_IDX_ARTIST_SQL];
    [(PRDb*)(_db?:_conn) zExecute:PR_IDX_GENRE_SQL];
    [(PRDb*)(_db?:_conn) zExecute:PR_IDX_ARTIST_ALBUM_ARTIST_SQL];
    [(PRDb*)(_db?:_conn) zExecute:PR_IDX_COMPILATION_SQL];
}

- (BOOL)initialize {
    NSArray *columns = @[PRColString];
    NSArray *result = nil;
    [(PRDb*)(_db?:_conn) zExecute:@"SELECT sql FROM sqlite_master WHERE name = 'library'" bindings:nil columns:columns out:&result];
    if ([result count] != 1 || !([[[result objectAtIndex:0] objectAtIndex:0] isEqualToString:PR_TBL_LIBRARY_SQL] || 
        [[[result objectAtIndex:0] objectAtIndex:0] isEqualToString:PR_TBL_LIBRARY_SQL2])) {
        return NO;
    }
    
    [(PRDb*)(_db?:_conn) zExecute:@"SELECT sql FROM sqlite_master WHERE name = 'index_path'" bindings:nil columns:columns out:&result];
    if ([result count] != 1 || ![[[result objectAtIndex:0] objectAtIndex:0] isEqualToString:PR_IDX_PATH_SQL]) {
        return NO;
    }
    
    [(PRDb*)(_db?:_conn) zExecute:@"SELECT sql FROM sqlite_master WHERE name = 'index_album'" bindings:nil columns:columns out:&result];
    if ([result count] != 1 || ![[[result objectAtIndex:0] objectAtIndex:0] isEqualToString:PR_IDX_ALBUM_SQL]) {
        return NO;
    }
    
    [(PRDb*)(_db?:_conn) zExecute:@"SELECT sql FROM sqlite_master WHERE name = 'index_artist'" bindings:nil columns:columns out:&result];
    if ([result count] != 1 || ![[[result objectAtIndex:0] objectAtIndex:0] isEqualToString:PR_IDX_ARTIST_SQL]) {
        return NO;
    }
    
    [(PRDb*)(_db?:_conn) zExecute:@"SELECT sql FROM sqlite_master WHERE name = 'index_genre'" bindings:nil columns:columns out:&result];
    if ([result count] != 1 || ![[[result objectAtIndex:0] objectAtIndex:0] isEqualToString:PR_IDX_GENRE_SQL]) {
        return NO;
    }
    
    [(PRDb*)(_db?:_conn) zExecute:@"SELECT sql FROM sqlite_master WHERE name = 'index_artistAlbumArtist'" bindings:nil columns:columns out:&result];
    if ([result count] != 1 || ![[[result objectAtIndex:0] objectAtIndex:0] isEqualToString:PR_IDX_ARTIST_ALBUM_ARTIST_SQL]) {
        return NO;
    }
    
    [(PRDb*)(_db?:_conn) zExecute:@"SELECT sql FROM sqlite_master WHERE name = 'index_compilation'" bindings:nil columns:columns out:&result];
    if ([result count] != 1 || ![[[result objectAtIndex:0] objectAtIndex:0] isEqualToString:PR_IDX_COMPILATION_SQL]) {
        return NO;
    }

    [(PRDb*)(_db?:_conn) zExecute:PR_TRG_ARTIST_ALBUM_ARTIST_SQL];
    [(PRDb*)(_db?:_conn) zExecute:PR_TRG_ARTIST_ALBUM_ARTIST_2_SQL];
    [(PRDb*)(_db?:_conn) zExecute:@"UPDATE library SET artistAlbumArtist = coalesce(nullif(albumArtist, ''), artist) "
        "WHERE artistAlbumArtist != coalesce(nullif(albumArtist, ''), artist)"];
    return YES;
}

#pragma mark - Update

- (BOOL)propagateItemDelete {
    return [[(PRDb*)(_db?:_conn) playlists] cleanPlaylistItems] && [[(PRDb*)(_db?:_conn) playlists] propagateListItemDelete];
}

#pragma mark - Accessors

- (BOOL)containsItem:(PRItemID *)item {
    BOOL rlt = NO;
    [self zContainsItem:item out:&rlt];
    return rlt;
}

- (PRItemID *)addItemWithAttrs:(NSDictionary *)attrs {
    PRItemID *rlt = nil;
    [self zAddItemWithAttrs:attrs out:&rlt];
    return rlt;
}

- (void)removeItems:(NSArray *)items {
    [self zRemoveItems:items];
}

- (id)valueForItem:(PRItemID *)item attr:(PRItemAttr *)attr {
    id rlt = nil;
    [self zValueForItem:item attr:attr out:&rlt];
    return rlt;
}

- (void)setValue:(id)value forItem:(PRItemID *)item attr:(PRItemAttr *)attr {
    [self zSetValue:value forItem:item attr:attr];
}

- (NSDictionary *)attrsForItem:(PRItemID *)item {
    NSDictionary *rlt = nil;
    [self zAttrsForItem:item out:&rlt];
    return rlt;
}

- (void)setAttrs:(NSDictionary *)attrs forItem:(PRItemID *)item {
    [self zSetAttrs:attrs forItem:item];
}

- (NSString *)artistValueForItem:(PRItemID *)item {
    NSString *rlt = nil;
    [self zArtistValueForItem:item out:&rlt];
    return rlt;
}

- (NSURL *)URLForItem:(PRItemID *)item {
    return [NSURL URLWithString:[self valueForItem:item attr:PRItemAttrPath]];
}

- (NSArray *)itemsWithSimilarURL:(NSURL *)URL {
    NSArray *rlt = nil;
    [self zItemsWithSimilarURL:URL out:&rlt];
    return rlt;
}

- (NSArray *)itemsWithValue:(id)value forAttr:(PRItemAttr *)attr {
    NSArray *rlt = nil;
    [self zItemsWithValue:value forAttr:attr out:&rlt];
    return rlt;
}

#pragma mark - zAccessors

- (BOOL)zContainsItem:(PRItemID *)item out:(BOOL *)outValue {
    NSArray *rlt = nil;
    BOOL success = [(PRDb*)(_db?:_conn) zExecute:@"SELECT count(*) FROM library WHERE file_id = ?1"
        bindings:@{@1:item}
        columns:@[PRColInteger]
        out:&rlt];
    if (success && outValue) {
        *outValue = [rlt[0][0] intValue] > 0;
    }
    return success;
}

- (BOOL)zAddItemWithAttrs:(NSDictionary *)attrs out:(PRItemID **)outValue {
    NSMutableString *stm = [NSMutableString stringWithString:@"INSERT INTO library ("];
    NSMutableString *stm2 = [NSMutableString stringWithString:@"VALUES ("];
    NSMutableDictionary *bnd = [NSMutableDictionary dictionary];
    int bndIndex = 1;
    for (PRItemAttr *i in [attrs allKeys]) {
        [stm appendFormat:@"%@, ", [PRLibrary columnNameForItemAttr:i]];
        [stm2 appendFormat:@"?%d, ", bndIndex];
        [bnd setObject:[attrs objectForKey:i] forKey:@(bndIndex)];
        bndIndex++;
    }
    [stm deleteCharactersInRange:NSMakeRange([stm length] - 2, 1)];
    [stm appendFormat:@") "];
    [stm2 deleteCharactersInRange:NSMakeRange([stm2 length] - 2, 1)];
    [stm2 appendFormat:@") "];
    [stm appendString:stm2];
    BOOL success = [(PRDb*)(_db?:_conn) zExecute:stm bindings:bnd columns:nil out:nil];
    if (success && outValue) {
        *outValue = [PRItemID numberWithUnsignedLongLong:[(PRDb*)(_db?:_conn) lastInsertRowid]];
    }
    return success;
}

- (BOOL)zRemoveItems:(NSArray *)items {
    NSMutableString *stm = [NSMutableString stringWithString:@"DELETE FROM library WHERE file_id IN ("];
    for (PRItemID *i in items) {
        [stm appendString:[NSString stringWithFormat:@"%llu, ", [i unsignedLongLongValue]]];
        [[(PRDb*)(_db?:_conn) albumArtController] clearArtworkForItem:i];
    }
    [stm deleteCharactersInRange:NSMakeRange([stm length] - 2, 2)];
    [stm appendString:@")"];
    BOOL success = [(PRDb*)(_db?:_conn) zExecute:stm];
    if (success) {
        [self propagateItemDelete];
    }
    return success;
}

- (BOOL)zValueForItem:(PRItemID *)item attr:(PRItemAttr *)attr out:(id *)outValue {
    NSArray *rlt = nil;
    NSString *stm = [NSString stringWithFormat:@"SELECT %@ FROM library WHERE file_id = ?1", [PRLibrary columnNameForItemAttr:attr]];
    BOOL success = [(PRDb*)(_db?:_conn) zExecute:stm bindings:@{@1:item} columns:@[[PRLibrary columnTypeForItemAttr:attr]] out:&rlt];
    if (success && outValue && [rlt count] > 0) {
        *outValue = rlt[0][0];
    }
    return success;
}

- (BOOL)zSetValue:(id)value forItem:(PRItemID *)item attr:(PRItemAttr *)attr {
    NSString *stm = [NSString stringWithFormat:@"UPDATE library SET %@ = ?1 WHERE file_id = ?2", [PRLibrary columnNameForItemAttr:attr]];
    BOOL success = [(PRDb*)(_db?:_conn) zExecute:stm bindings:@{@1:value, @2:item} columns:nil out:nil];
    return success;
}

- (BOOL)zAttrsForItem:(PRItemID *)item out:(NSDictionary **)outValue {
    NSMutableString *stm = [NSMutableString stringWithString:@"SELECT "];
    NSMutableArray *cols = [NSMutableArray array];
    for (PRItemAttr *i in [PRLibrary itemAttrs]) {
        [stm appendFormat:@"%@, ",[PRLibrary columnNameForItemAttr:i]];
        [cols addObject:[PRLibrary columnTypeForItemAttr:i]];
    }
    [stm deleteCharactersInRange:NSMakeRange([stm length] - 2, 1)];
    [stm appendString:@"FROM library WHERE file_id = ?1"];
    NSArray *rlt = nil;
    BOOL success = [(PRDb*)(_db?:_conn) zExecute:stm bindings:@{@1:item} columns:cols out:&rlt];
    if (!success || [rlt count] != 1) {
        return NO;
    }
    
    NSArray *row = [rlt objectAtIndex:0];
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    for (int i = 0; i < [[PRLibrary itemAttrs] count]; i++) {
        [dictionary setObject:[row objectAtIndex:i] forKey:[[PRLibrary itemAttrs] objectAtIndex:i]];
    }
    if (outValue) {
        *outValue = dictionary;
    }
    return YES;
}

- (BOOL)zSetAttrs:(NSDictionary *)attrs forItem:(PRItemID *)item {
    NSMutableString *stm = [NSMutableString stringWithString:@"UPDATE library SET "];
    NSMutableDictionary *bindings = [NSMutableDictionary dictionary];
    int bindingIndex = 1;
    for (NSString *i in [attrs allKeys]) {
        [stm appendFormat:@"%@ = ?%d, ", [PRLibrary columnNameForItemAttr:i], bindingIndex];
        [bindings setObject:[attrs objectForKey:i] forKey:@(bindingIndex)];
        bindingIndex += 1;
    }
    [stm deleteCharactersInRange:NSMakeRange([stm length] - 2, 1)];
    [stm appendFormat:@"WHERE file_id = ?%d", bindingIndex];
    [bindings setObject:item forKey:@(bindingIndex)];
    return [(PRDb*)(_db?:_conn) zExecute:stm bindings:bindings columns:nil out:nil];
}

- (BOOL)zArtistValueForItem:(PRItemID *)item out:(NSString **)outValue {
    PRItemAttr *attr = [[PRDefaults sharedDefaults] boolForKey:PRDefaultsUseAlbumArtist] ? PRItemAttrArtistAlbumArtist : PRItemAttrArtist;
    NSString *rlt = nil;
    BOOL success = [self zValueForItem:item attr:attr out:&rlt];
    if (!success) {
        return NO;
    }
    if (outValue) {
        *outValue = rlt;
    }
    return YES;
}

- (BOOL)zURLForItem:(PRItemID *)item out:(NSURL **)outValue {
    NSString *rlt = nil;
    BOOL success = [self zValueForItem:item attr:PRItemAttrPath out:&rlt];
    if (!success) {
        return NO;
    }
    if (outValue) {
        *outValue = [NSURL URLWithString:rlt];
    }
    return YES;
}

- (BOOL)zItemsWithSimilarURL:(NSURL *)url out:(NSArray **)outValue {
    NSArray *rlt = nil;
    BOOL success = [(PRDb*)(_db?:_conn) zExecute:@"SELECT file_id FROM library WHERE path = ?1 COLLATE hfs_compare" 
        bindings:@{@1:[url absoluteString]}
        columns:@[PRColInteger] 
        out:&rlt];
    if (!success) {
        return NO;
    }
    if (outValue) {
        *outValue = [rlt PRMap:^(NSInteger idx, id obj){return obj[0];}];
    }
    return YES;
}

- (BOOL)zItemsWithValue:(id)value forAttr:(PRItemAttr *)attr out:(NSArray **)outValue {
    NSArray *rlt = nil;
    BOOL success = [(PRDb*)(_db?:_conn) zExecute:[NSString stringWithFormat:@"SELECT file_id FROM library WHERE %@ = ?1", [PRLibrary columnNameForItemAttr:attr]]
        bindings:@{@1:value}
        columns:@[PRColInteger]
        out:&rlt];
    if (!success) {
        return NO;
    }
    if (outValue) {
        *outValue = [rlt PRMap:^(NSInteger idx, id obj){return obj[0];}];
    }
    return YES;
}

- (BOOL)zItemDescriptionForItem:(PRItemID *)item out:(PRItem **)outValue {
    if (outValue) {
        *outValue = [[PRItem alloc] initWithItemID:item connection:(PRConnection*)(_db?:(id)_conn)];
    }
    return *outValue != nil;
}

- (BOOL)zSetItemDescription:(PRItem *)value forItem:(PRItemID *)item {
    return [value writeToConnection:(PRConnection*)(_db?:(id)_conn)];
}

#pragma mark - Misc

+ (NSArray *)itemAttrProperties {
    static NSArray *array = nil;
    if (!array) {
        array = @[
            @{@"itemAttr":PRItemAttrPath, @"columnType":PRColString, @"columnName":@"path", @"title":@"Path", @"internal":@25},
            @{@"itemAttr":PRItemAttrSize, @"columnType":PRColInteger, @"columnName":@"size", @"title":@"Size", @"internal":@18},
            @{@"itemAttr":PRItemAttrKind, @"columnType":PRColInteger, @"columnName":@"kind", @"title":@"Kind", @"internal":@19},
            @{@"itemAttr":PRItemAttrTime, @"columnType":PRColInteger, @"columnName":@"time", @"title":@"Time", @"internal":@20},
            @{@"itemAttr":PRItemAttrBitrate, @"columnType":PRColInteger, @"columnName":@"bitrate", @"title":@"Bitrate", @"internal":@21},
            @{@"itemAttr":PRItemAttrChannels, @"columnType":PRColInteger, @"columnName":@"channels", @"title":@"Channels", @"internal":@22},
            @{@"itemAttr":PRItemAttrSampleRate, @"columnType":PRColInteger, @"columnName":@"sampleRate", @"title":@"Sample Rate", @"internal":@23},
            @{@"itemAttr":PRItemAttrCheckSum, @"columnType":PRColData, @"columnName":@"checkSum", @"title":@"Check Sum", @"internal":@27},
            @{@"itemAttr":PRItemAttrLastModified, @"columnType":PRColString, @"columnName":@"lastModified", @"title":@"Last Modified", @"internal":@28},
            
            @{@"itemAttr":PRItemAttrTitle, @"columnType":PRColString, @"columnName":@"title", @"title":@"Title", @"internal":@1},
            @{@"itemAttr":PRItemAttrArtist, @"columnType":PRColString, @"columnName":@"artist", @"title":@"Artist", @"internal":@2},
            @{@"itemAttr":PRItemAttrAlbum, @"columnType":PRColString, @"columnName":@"album", @"title":@"Album", @"internal":@3},
            @{@"itemAttr":PRItemAttrBPM, @"columnType":PRColInteger, @"columnName":@"BPM", @"title":@"BPM", @"internal":@4},
            @{@"itemAttr":PRItemAttrYear, @"columnType":PRColInteger, @"columnName":@"year", @"title":@"Year", @"internal":@5},
            @{@"itemAttr":PRItemAttrTrackNumber, @"columnType":PRColInteger, @"columnName":@"trackNumber", @"title":@"Track", @"internal":@6},
            @{@"itemAttr":PRItemAttrTrackCount, @"columnType":PRColInteger, @"columnName":@"trackCount", @"title":@"Track Count", @"internal":@7},
            @{@"itemAttr":PRItemAttrComposer, @"columnType":PRColString, @"columnName":@"composer", @"title":@"Composer", @"internal":@8},
            @{@"itemAttr":PRItemAttrDiscNumber, @"columnType":PRColInteger, @"columnName":@"discNumber", @"title":@"Disc", @"internal":@9},
            @{@"itemAttr":PRItemAttrDiscCount, @"columnType":PRColInteger, @"columnName":@"discCount", @"title":@"Disc Count", @"internal":@10},
            @{@"itemAttr":PRItemAttrComments, @"columnType":PRColString, @"columnName":@"comments", @"title":@"Comments", @"internal":@11},
            @{@"itemAttr":PRItemAttrAlbumArtist, @"columnType":PRColString, @"columnName":@"albumArtist", @"title":@"Album Artist", @"internal":@12},
            @{@"itemAttr":PRItemAttrGenre, @"columnType":PRColString, @"columnName":@"genre", @"title":@"Genre", @"internal":@13},
            @{@"itemAttr":PRItemAttrCompilation, @"columnType":PRColInteger, @"columnName":@"compilation", @"title":@"Compilation", @"internal":@29},
            @{@"itemAttr":PRItemAttrLyrics, @"columnType":PRColString, @"columnName":@"lyrics", @"title":@"Lyrics", @"internal":@30},
            
            @{@"itemAttr":PRItemAttrArtwork, @"columnType":PRColInteger, @"columnName":@"albumArt", @"title":@"Artwork", @"internal":@24},
            @{@"itemAttr":PRItemAttrArtistAlbumArtist, @"columnType":PRColString, @"columnName":@"artistAlbumArtist", @"title":@"Artist / Album Artist", @"internal":@26},
            
            @{@"itemAttr":PRItemAttrDateAdded, @"columnType":PRColString, @"columnName":@"dateAdded", @"title":@"Date Added", @"internal":@14},
            @{@"itemAttr":PRItemAttrLastPlayed, @"columnType":PRColString, @"columnName":@"lastPlayed", @"title":@"Last Played", @"internal":@15},
            @{@"itemAttr":PRItemAttrPlayCount, @"columnType":PRColInteger, @"columnName":@"playCount", @"title":@"Play Count", @"internal":@16},
            @{@"itemAttr":PRItemAttrRating, @"columnType":PRColInteger, @"columnName":@"rating", @"title":@"Rating", @"internal":@17},
        ];
    }
    return array;
}

+ (NSArray *)itemAttrs {
    static NSMutableArray *itemAttrs = nil;
    if (!itemAttrs) {
        NSArray *array = [self itemAttrProperties];
        itemAttrs = [[NSMutableArray alloc] init];
        for (NSDictionary *i in array) {
            [itemAttrs addObject:[i objectForKey:@"itemAttr"]];
        }
    }
    return itemAttrs;
}

+ (NSString *)columnNameForItemAttr:(PRItemAttr *)attr {
    static NSMutableDictionary *dict = nil;
    if (!dict) {
        dict = [[NSMutableDictionary alloc] init];
        NSArray *array = [self itemAttrProperties];
        for (NSDictionary *i in array) {
            [dict setObject:[i objectForKey:@"columnName"] forKey:[i objectForKey:@"itemAttr"]];
        }
    }
    return [dict objectForKey:attr];
}

+ (PRCol *)columnTypeForItemAttr:(PRItemAttr *)attr {
    static NSMutableDictionary *dict = nil;
    if (!dict) {
        dict = [[NSMutableDictionary alloc] init];
        NSArray *array = [self itemAttrProperties];
        for (NSDictionary *i in array) {
            [dict setObject:[i objectForKey:@"columnType"] forKey:[i objectForKey:@"itemAttr"]];
        }
    }
    return [dict objectForKey:attr];
}

+ (NSString *)titleForItemAttr:(PRItemAttr *)attr {
    static NSMutableDictionary *dict = nil;
    if (!dict) {
        dict = [[NSMutableDictionary alloc] init];
        NSArray *array = [self itemAttrProperties];
        for (NSDictionary *i in array) {
            [dict setObject:[i objectForKey:@"title"] forKey:[i objectForKey:@"itemAttr"]];
        }
    }
    return [dict objectForKey:attr];
}

+ (NSNumber *)internalForItemAttr:(PRItemAttr *)attr {
    if (attr == nil) {
        return @0;
    }
    static NSMutableDictionary *dict = nil;
    if (!dict) {
        dict = [[NSMutableDictionary alloc] init];
        NSArray *array = [self itemAttrProperties];
        for (NSDictionary *i in array) {
            [dict setObject:[i objectForKey:@"internal"] forKey:[i objectForKey:@"itemAttr"]];
        }
    }
    return [dict objectForKey:attr];
}

+ (PRItemAttr *)itemAttrForInternal:(NSNumber *)internal {
    if ([internal intValue] == 0) {
        return nil;
    }
    static NSMutableDictionary *dict = nil;
    if (!dict) {
        dict = [[NSMutableDictionary alloc] init];
        NSArray *array = [self itemAttrProperties];
        for (NSDictionary *i in array) {
            [dict setObject:[i objectForKey:@"itemAttr"] forKey:[i objectForKey:@"internal"]];
        }
    }
    return [dict objectForKey:internal];
}

@end
