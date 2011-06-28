#import "PRDb.h"
#import "PRHistory.h"
#import "PRLibrary.h"
#import "PRPlaylists.h"
#import "PRQueue.h"
#import "PRLibraryViewSource.h"
#import "PRNowPlayingViewSource.h"
#import "PRAlbumArtController.h"
#import "PRPlaybackOrder.h"
#import "PRLog.h"
#import "NSError+Extensions.h"
#include <string.h>
#include <ctype.h>
#include "sqlite3.h"
#include "PRUserDefaults.h"
#include <sys/file.h>


int no_case(void *udp, int lenA, const void *strA, int lenB, const void *strB);
CFRange PRFormatString(UniChar *string, int length);

// ========================================
// Constants
// ========================================

NSString * const PRLibraryDidChangeNotification = @"PRLibraryDidChangeNotification";
NSString * const PRLibraryViewDidChangeNotification = @"PRLibraryViewDidChangeNotification";
NSString * const PRTagsDidChangeNotification = @"PRTagsDidChangeNotification";
NSString * const PRPlaylistDidChangeNotification = @"PRPlaylistDidChangeNotification";
NSString * const PRPlaylistsDidChangeNotification = @"PRPlaylistsDidChangeNotification";
NSString * const PRFilePboardType = @"PRFilePboardType";
NSString * const PRIndexesPboardType = @"PRIndexesPboardType";

@implementation PRDb

// ========================================
// Properties
// ========================================

@dynamic sqlDb;
@synthesize history;
@synthesize library;
@synthesize playlists;
@synthesize queue;
@synthesize libraryViewSource;
@synthesize nowPlayingViewSource;
@synthesize albumArtController;
@synthesize playbackOrder;

- (sqlite3 *)sqlDb
{
    if ([NSThread isMainThread]) {
        return sqlDb;
    } else {
        return sqlDb2;
    }
}

// ========================================
// Initialization
// ========================================

- (id)init
{
    if ((self = [super init])) {
        history = [[PRHistory alloc] initWithDb:self];
        library = [[PRLibrary alloc] initWithDb:self];
        playlists = [[PRPlaylists alloc] initWithDb:self];
        queue = [[PRQueue alloc] initWithDb:self];
        libraryViewSource = [[PRLibraryViewSource alloc] initWithDb:self];
        nowPlayingViewSource = [[PRNowPlayingViewSource alloc] initWithDb:self];
        playbackOrder = [[PRPlaybackOrder alloc] initWithDb:self];
        
        albumArtController = [[PRAlbumArtController alloc] initWithDb:self];
        
        NSString *libraryPath = [[PRUserDefaults sharedUserDefaults] libraryPath];
        BOOL libraryExists = [[[[NSFileManager alloc] init] autorelease] fileExistsAtPath:libraryPath isDirectory:nil];
        
        if (!libraryExists) {
            goto create;
        }
        if (![self open_error:nil]) {
            goto create;
        }
        if (![self update_error:nil]) {
            goto create;
        }
        if (![self initialize_error:nil]) {
            goto create;
        }
        if (![self validate_error:nil]) {
            goto create;
        }
    }
	return self;
    
create:;
    // move library
    NSString *libraryPath = [[PRUserDefaults sharedUserDefaults] libraryPath];
    BOOL libraryExists = [[[[NSFileManager alloc] init] autorelease] fileExistsAtPath:libraryPath isDirectory:nil];
    if (libraryExists) {
        NSString *newLibraryPath;
        int i = 2;
        while (TRUE) {
            newLibraryPath = [libraryPath stringByDeletingPathExtension];
            newLibraryPath = [newLibraryPath stringByAppendingString:[NSString stringWithFormat:@" %d",i]];
            newLibraryPath = [newLibraryPath stringByAppendingPathExtension:[libraryPath pathExtension]];
            if (![[[[NSFileManager alloc] init] autorelease] fileExistsAtPath:newLibraryPath isDirectory:nil]) {
                break;
            }
            if (i > 50) {
                [[PRLog sharedLog] presentFatalError:[self databaseCouldNotBeInitializedError]];
                return FALSE;
            }
            i++;
        }
        BOOL success = [[[[NSFileManager alloc] init] autorelease] moveItemAtPath:libraryPath toPath:newLibraryPath error:nil];
        if (!success) {
            [[PRLog sharedLog] presentFatalError:[self databaseCouldNotBeInitializedError]];
            return FALSE;
        }
        [[PRLog sharedLog] presentError:[self databaseWasMovedError:newLibraryPath]];
    }
    if (![self open_error:nil]) {
        [[PRLog sharedLog] presentFatalError:[self databaseCouldNotBeInitializedError]];
        [self release];
        return nil;
    }
    if (![self create_error:nil]) {
        [[PRLog sharedLog] presentFatalError:[self databaseCouldNotBeInitializedError]];
        [self release];
        return nil;
    }
    if (![self initialize_error:nil]) {
        [[PRLog sharedLog] presentFatalError:[self databaseCouldNotBeInitializedError]];
        [self release];
        return nil;
    }
    if (![self validate_error:nil]) {
        [[PRLog sharedLog] presentFatalError:[self databaseCouldNotBeInitializedError]];
        [self release];
        return nil;
    }
    return self;
}

- (void)dealloc
{
    [history release];
    [library release];
    [playlists release];
    [libraryViewSource release];
    [nowPlayingViewSource release];
    [albumArtController release];
    [playbackOrder release];
    [super dealloc];
}

- (BOOL)open_error:(NSError **)error
{
	// initialize SQLite
	int e = sqlite3_initialize();
	if (e != SQLITE_OK) {
		NSLog(@"PRDb SQLiteInit_error: initialize failed: %d", e);
		return FALSE;
	}
	
    sqlite3_close(sqlDb);
    sqlite3_close(sqlDb2);
    
	// create or open Sqlite db
    NSString *libraryPath = [[PRUserDefaults sharedUserDefaults] libraryPath];
	const char *filename = [libraryPath fileSystemRepresentation];
	e = sqlite3_open_v2(filename, &sqlDb, SQLITE_OPEN_READWRITE|SQLITE_OPEN_CREATE, NULL);
	if (e != SQLITE_OK) {
		sqlite3_close(sqlDb);
		NSLog(@"PRDb SQLiteInit_error: open failed: %d", e);
		return FALSE;
	}
	
	// enable extended error codes
	e = sqlite3_extended_result_codes(sqlDb, TRUE);
	if (e != SQLITE_OK) {
		return FALSE;
	}
	
	// enable foreign keys
	e = sqlite3_exec(sqlDb, "PRAGMA foreign_keys = ON", NULL, NULL, NULL);
	if (e != SQLITE_OK) {
		return FALSE;
	}
    
//    e = sqlite3_exec(sqlDb, "PRAGMA temp_store = 1", NULL, NULL, NULL);
//	if (e != SQLITE_OK) {
//		return FALSE;
//	}
    	
	// register custom collation
	e = sqlite3_create_collation(sqlDb, "NOCASE2", SQLITE_UTF16, NULL, no_case);
	if (e != SQLITE_OK) {
		return FALSE;
	}
    
    // create or open Sqlite db
	e = sqlite3_open_v2(filename, &sqlDb2, SQLITE_OPEN_READWRITE|SQLITE_OPEN_CREATE, NULL);
	if (e != SQLITE_OK) {
		sqlite3_close(sqlDb2);
		return FALSE;
	}
	
	// enable extended error codes
	e = sqlite3_extended_result_codes(sqlDb2, TRUE);
	if (e != SQLITE_OK) {
		return FALSE;
	}
	
	// enable foreign keys
	e = sqlite3_exec(sqlDb2, "PRAGMA foreign_keys = ON", NULL, NULL, NULL);
	if (e != SQLITE_OK) {
		return FALSE;
	}
	
//    e = sqlite3_exec(sqlDb2, "PRAGMA temp_store = 1", NULL, NULL, NULL);
//	if (e != SQLITE_OK) {
//		return FALSE;
//	}
        
	// register custom collation
	e = sqlite3_create_collation(sqlDb2, "NOCASE2", SQLITE_UTF16, NULL, no_case);
	if (e != SQLITE_OK) {
		return FALSE;
	}
    return TRUE;
}

- (BOOL)initialize_error:(NSError **)error
{
    if (![history initialize_error:nil]) {
        return FALSE;
    }
    if (![library initialize_error:nil]) {
        return FALSE;
    }
    if (![playlists initialize_error:nil]) {
        return FALSE;
    }
    if (![queue initialize_error:nil]) {
        return FALSE;
    }
    if (![libraryViewSource initialize_error:nil]) {
        return FALSE;
    }
    if (![nowPlayingViewSource initialize_error:nil]) {
        return FALSE;
    }
    if (![playbackOrder initialize_error:nil]) {
        return FALSE;
    }
    if (![self executeStatement:@"ANALYZE" _error:nil]) {
        return FALSE;
    }
    if (![self executeStatement:@"VACUUM" _error:nil]) {
        return FALSE;
    }
	return TRUE;
}

- (BOOL)update_error:(NSError **)error
{
    NSString *statement = @"SELECT version FROM schema_version";
    NSArray *result;
    if (![self executeStatement:statement withBindings:nil result:&result _error:nil]) {
        return FALSE;
    }
    int version = [[result objectAtIndex:0] intValue];
    if (version == 1) {
        statement = @"BEGIN TRANSACTION";
        if (![self executeStatement:statement _error:nil]) {
            return FALSE;
        }
        statement = @"DROP TABLE IF EXISTS now_playing_view_source";
        if (![self executeStatement:statement _error:nil]) {
            return FALSE;
        }
        statement = @"DROP TABLE IF EXISTS playback_order";
        if (![self executeStatement:statement _error:nil]) {
            return FALSE;
        }
        statement = @"ALTER TABLE library ADD COLUMN lastModified TEXT NOT NULL DEFAULT '' ";
        if (![self executeStatement:statement _error:nil]) {
            return FALSE;
        }
        statement = @"CREATE INDEX IF NOT EXISTS index_path ON library (path COLLATE NOCASE)";
        if (![self executeStatement:statement _error:nil]) {
            return FALSE;
        }
        statement = @"DELETE FROM library WHERE file_id NOT IN ("
        "SELECT min(file_id) FROM library GROUP BY path COLLATE NOCASE)";
        if (![self executeStatement:statement _error:nil]) {
            return FALSE;
        }
        statement = @"DROP TABLE IF EXISTS history";
        if (![self executeStatement:statement _error:nil]) {
            return FALSE;
        }
        statement = @"CREATE TABLE IF NOT EXISTS history ("
        "file_id INTEGER NOT NULL, "
        "date TEXT NOT NULL, "
        "FOREIGN KEY(file_id) REFERENCES library(file_id) ON UPDATE CASCADE ON DELETE CASCADE)";
        if (![self executeStatement:statement _error:nil]) {
            return FALSE;
        }
        statement = @"CREATE TABLE IF NOT EXISTS queue ("
        "queue_index INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, "
        "playlist_item_id INTEGER NOT NULL UNIQUE, "
        "FOREIGN KEY(playlist_item_id) REFERENCES playlist_items(playlist_item_id) ON UPDATE CASCADE ON DELETE CASCADE)";
        if (![self executeStatement:statement _error:nil]) {
            return FALSE;
        }
        statement = @"UPDATE schema_version SET version = 2";
        if (![self executeStatement:statement _error:nil]) {
            return FALSE;
        }
        statement = @"END TRANSACTION";
        if (![self executeStatement:statement _error:nil]) {
            return FALSE;
        }
        version = 2;
    }
    if (version == 2) {
        statement = @"BEGIN TRANSACTION";
        if (![self executeStatement:statement _error:nil]) {
            return FALSE;
        }
        statement = @"CREATE TABLE playback_order ("
        "index_ INTEGER PRIMARY KEY, "
        "playlist_item_id INTEGER NOT NULL, "
        "CHECK (index_ > 0), "
        "FOREIGN KEY(playlist_item_id) REFERENCES playlist_items(playlist_item_id) ON UPDATE RESTRICT ON DELETE CASCADE)";
        if (![self executeStatement:statement _error:nil]) {
            return FALSE;
        }
        statement = @"UPDATE schema_version SET version = 3";
        if (![self executeStatement:statement _error:nil]) {
            return FALSE;
        }
        statement = @"END TRANSACTION";
        if (![self executeStatement:statement _error:nil]) {
            return FALSE;
        }
        version = 3;
    }
    return TRUE;
}

- (BOOL)validate_error:(NSError **)error
{
    if (![history validate_error:nil]) {
        return FALSE;
    }
    if (![library validate_error:nil]) {
        return FALSE;
    }
    if (![playlists validate_error:nil]) {
        return FALSE;
    }
    if (![queue validate_error:nil]) {
        return FALSE;
    }
    if (![libraryViewSource validate_error:nil]) {
        return FALSE;
    }
    if (![nowPlayingViewSource validate_error:nil]) {
        return FALSE;
    }
    if (![playbackOrder validate_error:nil]) {
        return FALSE;
    }
    return TRUE;
}

- (BOOL)create_error:(NSError **)error
{
    NSString *statement = @"CREATE TABLE schema_version (version INTEGER NOT NULL)";
    if (![self executeStatement:statement _error:nil]) {
		return FALSE;
	}
    statement = @"INSERT INTO schema_version (version) VALUES (3)";
    if (![self executeStatement:statement _error:nil]) {
        return FALSE;
    }
    if (![history create_error:nil]) {
        return FALSE;
    }
    if (![library create_error:nil]) {
        return FALSE;
    }
    if (![playlists create_error:nil]) {
        return FALSE;
    }
    if (![queue create_error:nil]) {
        return FALSE;
    }
    if (![libraryViewSource create_error:nil]) {
        return FALSE;
    }
    if (![nowPlayingViewSource create_error:nil]) {
        return FALSE;
    }
    if (![playbackOrder create_error:nil]) {
        return FALSE;
    }
    return TRUE;
}

// ========================================
// Action
// ========================================

- (BOOL)executeStatement:(NSString *)statement _error:(NSError **)error
{
    NSArray *result;
    int e = [self executeStatement:statement 
                      withBindings:nil 
                            result:&result 
                            _error:error];
    
    return (e && [result count] == 0);
}

- (BOOL)executeStatement:(NSString *)statement 
            withBindings:(NSDictionary *)bindings
                  _error:(NSError **)error
{
    NSArray *result;
    int e = [self executeStatement:statement 
                      withBindings:bindings 
                            result:&result 
                            _error:error];
    
    return (e || [result count] == 0);
}

- (BOOL)executeStatement:(NSString *)statement 
            withBindings:(NSDictionary *)bindings
                  result:(NSArray **)result
                  _error:(NSError **)error
{
    sqlite3 *sqlDb_;
    if ([NSThread isMainThread]) {
        sqlDb_ = sqlDb;
    } else {
        sqlDb_ = sqlDb2;
    }
    
    // prep statement
    sqlite3_stmt *stmt = NULL;
    bool continueTrying = TRUE;
    while (continueTrying) {
        int e = sqlite3_prepare_v2(sqlDb_, [statement UTF8String], -1, &stmt, NULL);
        switch (e) {
            case SQLITE_OK:
                continueTrying = FALSE;
                break;
            case SQLITE_BUSY:
                usleep(50);
                break;
            default: {
                NSError *error = [self errorForSQLiteResult:e];
                NSString *details = [NSString stringWithFormat:@"Prep Failed - sqlite_code:%d \nsqlite_errmsg:%s \nstatement:%@ \nbindings:%@", 
                                     e, sqlite3_errmsg(sqlDb_), statement, bindings];
                [[PRLog sharedLog] presentFatalError:[error errorWithValue:details forKey:NSLocalizedFailureReasonErrorKey]];
                return FALSE;
                break;
            }
        }
    }
    
	// bind values
    if (!bindings) {
        bindings = [NSDictionary dictionary];
    }
    for (NSNumber *key in [bindings allKeys]) {
        continueTrying = TRUE;
        while (continueTrying) {
            id object = [bindings objectForKey:key]; 
            int e;
            if ([object isKindOfClass:[NSNumber class]]) {
                e = sqlite3_bind_int(stmt, [key intValue], [object longLongValue]);
            } else if ([object isKindOfClass:[NSString class]]) {
                e = sqlite3_bind_text(stmt, [key intValue], [object UTF8String], -1, SQLITE_TRANSIENT);
            } else if ([object isKindOfClass:[NSData class]]) {
                e = sqlite3_bind_blob(stmt, [key intValue], [object bytes], [object length], SQLITE_TRANSIENT);
            } else {
                NSLog(@"unknownType;%@",object);
            }
            
            switch (e) {
                case SQLITE_OK:
                    continueTrying = FALSE;
                    break;
                case SQLITE_BUSY:
                    usleep(50);
                    break;
                default: {
                    NSError *error = [self errorForSQLiteResult:e];
                    NSString *details = [NSString stringWithFormat:@"Bind Failed - sqlite_code:%d \nsqlite_errmsg:%s \nstatement:%@ \nbindings:%@", 
                                         e, sqlite3_errmsg(sqlDb_), statement, bindings];
                    [[PRLog sharedLog] presentFatalError:[error errorWithValue:details forKey:NSLocalizedFailureReasonErrorKey]];
                    return FALSE;
                }
            }
        }
    }
    
	// step
    NSMutableArray *valueArray = [NSMutableArray array];
    continueTrying = TRUE;
    while (continueTrying) {
        int e = sqlite3_step(stmt);
        switch (e) {
            case SQLITE_ROW:
                if (sqlite3_column_count(stmt) == 1) {
                    id value;
                    switch (sqlite3_column_type(stmt, 0)) {
                        case SQLITE_INTEGER:
                            value = [NSNumber numberWithLongLong:sqlite3_column_int64(stmt, 0)];
                            break;
                        case SQLITE_FLOAT:
                            value = [NSNumber numberWithDouble:sqlite3_column_double(stmt, 0)];
                            break;
                        case SQLITE_TEXT:
                            value = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, 0)];
                            break;
                        case SQLITE_BLOB:
                            value = [NSData dataWithBytes:sqlite3_column_blob(stmt, 0) length:sqlite3_column_bytes(stmt, 0)];
                            break;
                        case SQLITE_NULL:
                            value = [NSNull null];
                            break;
                        default:
                            break;
                    }
                    [valueArray addObject:value];
                } else {
                    NSMutableArray *array = [NSMutableArray array];
                    for (int i = 0; i < sqlite3_column_count(stmt); i++) {
                        id value;
                        switch (sqlite3_column_type(stmt, i)) {
                            case SQLITE_INTEGER:
                                value = [NSNumber numberWithLongLong:sqlite3_column_int64(stmt, i)];
                                break;
                            case SQLITE_FLOAT:
                                value = [NSNumber numberWithDouble:sqlite3_column_double(stmt, i)];
                                break;
                            case SQLITE_TEXT:
                                value = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(stmt, i)];
                                break;
                            case SQLITE_BLOB:
                                value = [NSData dataWithBytes:sqlite3_column_blob(stmt, i) length:sqlite3_column_bytes(stmt, i)];
                                break;
                            case SQLITE_NULL:
                                value = [NSNull null];
                                break;
                            default:
                                break;
                        }
                        [array addObject:value];
                    }
                    [valueArray addObject:[NSArray arrayWithArray:array]];
                }
                break;
            case SQLITE_BUSY:
                usleep(50);
                break;
            case SQLITE_LOCKED:
                usleep(50);
                sqlite3_reset(stmt);
                break;
            case SQLITE_DONE:
                continueTrying = FALSE;
                break;
            default: {
                NSError *error = [self errorForSQLiteResult:e];
                NSString *details = [NSString stringWithFormat:@"Step Failed - sqlite_code:%d \nsqlite_errmsg:%s \nstatement:%@ \nbindings:%@", 
                                     e, sqlite3_errmsg(sqlDb_), statement, bindings];
                [[PRLog sharedLog] presentFatalError:[error errorWithValue:details forKey:NSLocalizedFailureReasonErrorKey]];
                return FALSE;
                break;
            }
        }
    }
	sqlite3_finalize(stmt);
    
    if (result) {
        *result = [NSArray arrayWithArray:valueArray];
    }
    return TRUE;
}

- (BOOL)count:(int *)count forTable:(NSString *)table _error:(NSError **)error
{
    NSArray *result;
    if (![self executeStatement:[NSString stringWithFormat:@"SELECT COUNT(*) FROM %@", table]
                   withBindings:nil 
                         result:&result 
                          _error:error]) {
         return FALSE;
    }
    *count = [[result objectAtIndex:0] intValue];
	return TRUE;
}

- (BOOL)value:(id *)value 
	forColumn:(NSString *)column 
		  row:(int)row 
		  key:(NSString *)key 
		table:(NSString *)table 
	   _error:(NSError **)error 
{
    NSString *statement = [NSString stringWithFormat:@"SELECT %@ FROM %@ WHERE %@ = ?1", column, table, key];
    NSDictionary *bindings = [NSDictionary dictionaryWithObjectsAndKeys:
                              [NSNumber numberWithInt:row], [NSNumber numberWithInt:1], nil];
    NSArray *result;
    if (![self executeStatement:statement
                   withBindings:bindings
                         result:&result 
                         _error:error]) {
        return FALSE;
    }
    if (!result || [result count] != 1) {
        return FALSE;
    }
    
    *value = [result objectAtIndex:0];
    if (*value == [NSNull null]) {
        *value = nil;
    }
    return TRUE;
}

- (BOOL)intValue:(int *)value 
	   forColumn:(NSString *)column 
			 row:(int)row 
			 key:(NSString *)key 
		   table:(NSString *)table 
		  _error:(NSError **)error 
{
    NSString *statement = [NSString stringWithFormat:@"SELECT %@ FROM %@ WHERE %@ = ?1", column, table, key];
    NSDictionary *bindings = [NSDictionary dictionaryWithObjectsAndKeys:
                              [NSNumber numberWithInt:row], [NSNumber numberWithInt:1], nil];
    NSArray *columnTypes = [NSArray arrayWithObjects:[NSNumber numberWithInt:PRColumnInteger], nil];
    NSArray *result = [PRStatement executeString:statement withDb:self bindings:bindings columnTypes:columnTypes];
    
    if ([result count] != 1) {
        [[PRLog sharedLog] presentFatalError:nil];
    }
    
    *value = [[[result objectAtIndex:0] objectAtIndex:0] intValue];
    return TRUE;
    
	int e;
	NSNumber *temp;
	
	e = [self value:&temp forColumn:column row:row key:key table:table _error:error];
	
	if (temp == nil) {
		*value = 0;
	} else {
        *value = [temp intValue];
    }
	
	return e;
}

- (BOOL)setValue:(id)value 
	   forColumn:(NSString *)column 
			 row:(int)row 
			 key:(NSString *)key 
		   table:(NSString *)table 
		  _error:(NSError **)error
{
    NSString *statement = [NSString stringWithFormat:@"UPDATE %@ SET %@ = ?1 WHERE %@ = ?2", table, column, key];
    NSDictionary *bindings = [NSDictionary dictionaryWithObjectsAndKeys:
                              value, [NSNumber numberWithInt:1], 
                              [NSNumber numberWithInt:row], [NSNumber numberWithInt:2], 
                              nil];
    if (![self executeStatement:statement
                   withBindings:bindings
                         result:nil
                         _error:error]) {
        return FALSE;
    }
    return TRUE;
}

- (BOOL)setIntValue:(int)value 
		  forColumn:(NSString *)column 
				row:(int)row 
				key:(NSString *)key 
			  table:(NSString *)table 
			 _error:(NSError **)error
{
	return [self setValue:[NSNumber numberWithInt:value] 
				forColumn:column 
					  row:row 
					  key:key 
					table:table 
				   _error:error];
}

// ========================================
// Error
// ========================================

- (NSError *)databaseWasMovedError:(NSString *)newPath
{
    NSString *description = @"The Enqueue library file does not appear to be valid. ";
    NSString *recovery = [NSString stringWithFormat:@"A new library has been created and the previous library has been moved to:%@", newPath];
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              description, NSLocalizedDescriptionKey,
                              recovery, NSLocalizedRecoverySuggestionErrorKey,
                              nil];
    return [NSError errorWithDomain:PREnqueueErrorDomain code:0 userInfo:userInfo];
}

- (NSError *)databaseCouldNotBeInitializedError
{
    NSString *description = @"Enqueue could not initialize the database and must close.";
    NSString *recovery = @"If this problem persists please contact support";
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              description, NSLocalizedDescriptionKey,
                              recovery, NSLocalizedRecoverySuggestionErrorKey,
                              nil];
    return [NSError errorWithDomain:PREnqueueErrorDomain code:0 userInfo:userInfo];
}

- (NSError *)errorForSQLiteResult:(int)result
{
    NSString *description = @"Enqueue has encountered a serious internal error and must close.";
    NSString *recovery = @"If this problem persists please contact support";
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              description, NSLocalizedDescriptionKey,
                              recovery, NSLocalizedRecoverySuggestionErrorKey,
                              nil];
    return [NSError errorWithDomain:PREnqueueErrorDomain code:0 userInfo:userInfo];
}

- (NSArray *)descriptionAndRecoveryForResultCode:(int)resultCode
{
    switch (resultCode) {
        case SQLITE_PERM:
            return [NSArray arrayWithObjects:
                    @"Enqueue does not have sufficient permissions to access the library and must close.",
                    @"Make sure that you have Read & Write priviledges to the library file.", nil];
        case SQLITE_IOERR:
        case SQLITE_FULL:
            return [NSArray arrayWithObjects:
                    @"Enqueue encountered a IO error and must close.",
                    @"Make sure that there is available disk space.", nil];
        case SQLITE_CORRUPT:
            return [NSArray arrayWithObjects:
                    @"The library appears to be corrupt and Enqueue must close.",
                    @"", nil];
        case SQLITE_ROW:
        case SQLITE_DONE:

        case SQLITE_BUSY:
        case SQLITE_LOCKED:
        case SQLITE_PROTOCOL:
            
        case SQLITE_NOLFS:
        case SQLITE_READONLY:
        case SQLITE_CANTOPEN:
            
        case SQLITE_ERROR:
        case SQLITE_INTERNAL:
        case SQLITE_SCHEMA:
        case SQLITE_TOOBIG:
        case SQLITE_CONSTRAINT:
        case SQLITE_MISMATCH:
        case SQLITE_MISUSE:
        case SQLITE_AUTH:
        case SQLITE_NOMEM:
        default:
            return [NSArray arrayWithObjects:
                    @"Enqueue encountered an internal error and must close.",
                    @"", nil];
    }
}

@end

// collate no_case 
int no_case(void *udp, int lenA, const void *strA, int lenB, const void *strB) 
{
    UniChar *uniCharA = (UniChar *)strA;
    UniChar *uniCharB = (UniChar *)strB;
    CFRange rangeA = PRFormatString(uniCharA, lenA/2);
    CFRange rangeB = PRFormatString(uniCharB, lenB/2);
    
    if (rangeA.length == 0 && rangeB.length == 0) {
        return 0;
    } else if (rangeA.length == 0) {
        return 1;
    } else if (rangeB.length == 0) {
        return -1;
    }
    
    CFStringRef stringA = CFStringCreateWithCharactersNoCopy(NULL, uniCharA+rangeA.location, rangeA.length, kCFAllocatorNull);
    CFStringRef stringB = CFStringCreateWithCharactersNoCopy(NULL, uniCharB+rangeB.location, rangeB.length, kCFAllocatorNull);
    
    int result = CFStringCompare(stringA, stringB, kCFCompareCaseInsensitive);
    
    CFRelease(stringA);
    CFRelease(stringB);
    
    return result;
}

CFRange PRFormatString(UniChar *string, int length) 
{
    CFCharacterSetRef whiteSpace = CFCharacterSetGetPredefined(kCFCharacterSetWhitespace);
    int index = 0;
    int reverseIndex = length - 1;
    while (index < length && CFCharacterSetIsCharacterMember(whiteSpace, string[index])) {
        index++;
    }
    int skipCount = 0;
    if (index + 4 < length &&
		(string[index] == 't' || string[index] == 'T') &&
		(string[index+1] == 'h' || string[index+1] == 'H') &&
		(string[index+2] == 'e' || string[index+2] == 'E') &&
		CFCharacterSetIsCharacterMember(whiteSpace, string[index+3])) {
        skipCount = 4;
		index += 4;
	} else if (index + 2 < length &&
               (string[index] == 'a' || string[index] == 'A') &&
               CFCharacterSetIsCharacterMember(whiteSpace, string[index+1])) {
        skipCount = 2;
		index += 2;
	} else if (index + 3 < length &&
               (string[index] == 'a' || string[index] == 'A') &&
               (string[index+1] == 'n' || string[index+1] == 'N') &&
               CFCharacterSetIsCharacterMember(whiteSpace, string[index+2])) {
        skipCount = 3;
		index += 3;
	}
    while (index < length && CFCharacterSetIsCharacterMember(whiteSpace, string[index])) {
        skipCount++;
        index++;
    }
    if (index >= length) {
        index -= skipCount;
    }
    while (reverseIndex >= index && CFCharacterSetIsCharacterMember(whiteSpace, string[reverseIndex])) {
        reverseIndex--;
    }
    int tempIdxA = index;
    while (tempIdxA < length && string[tempIdxA] >= '!' && string[tempIdxA] < 'A') {
        string[tempIdxA] += 57344;
        tempIdxA++;
    }
    int newLength = reverseIndex - index + 1;
    if (newLength < 0) {
        newLength = 0;
    }
    return CFRangeMake(index, newLength);
}


@implementation PRStatement

- (id)initWithString:(NSString *)string db:(PRDb *)db
{
    if (!(self = [super init])) {
        return self;
    }
    _columnTypes = [[NSArray array] retain];
    _statement = [string retain];
    _sqlite3 = [db sqlDb];
    while (TRUE) {
        int e = sqlite3_prepare_v2(_sqlite3, [_statement UTF8String], -1, &_stmt, NULL);
        if (e == SQLITE_OK) {
            break;
        } else if (e == SQLITE_BUSY) {
            usleep(50);
        } else {
            [[PRLog sharedLog] presentFatalError:nil];
            [self release];
            return nil;
        }
    }
    return self;
}

+ (PRStatement *)statementWithString:(NSString *)string db:(PRDb *)db
{
    return [[[PRStatement alloc] initWithString:string db:db] autorelease];
}

- (void)setBindings:(NSDictionary *)bindings
{
    for (NSNumber *key in [bindings allKeys]) {
        BOOL bind = TRUE;
        while (bind) {
            id object = [bindings objectForKey:key]; 
            int e;
            if ([object isKindOfClass:[NSNumber class]]) {
                if ([object objCType][0] == 'f' || [object objCType][0] == 'd') { // if float or double
                    e = sqlite3_bind_double(_stmt, [key intValue], [object doubleValue]);
                } else {
                    e = sqlite3_bind_int64(_stmt, [key intValue], [object longLongValue]);
                }
            } else if ([object isKindOfClass:[NSString class]]) {
                e = sqlite3_bind_text(_stmt, [key intValue], [object UTF8String], -1, SQLITE_TRANSIENT);
            } else if ([object isKindOfClass:[NSData class]]) {
                e = sqlite3_bind_blob(_stmt, [key intValue], [object bytes], [object length], SQLITE_TRANSIENT);
            } else {
                [[PRLog sharedLog] presentFatalError:nil];
            }
            
            switch (e) {
                case SQLITE_OK:
                    bind = FALSE;
                    break;
                case SQLITE_BUSY:
                    usleep(50);
                    break;
                default:;
                    NSError *error = [[[NSError alloc] initWithDomain:@"" code:0 userInfo:nil] autorelease];
                    NSString *details = [NSString stringWithFormat:@"Bind Failed - sqlite_code:%d \nsqlite_errmsg:%s \nstatement:%@ \nbindings:%@", 
                                         e, sqlite3_errmsg(_sqlite3), _statement, bindings];
                    [[PRLog sharedLog] presentFatalError:[error errorWithValue:details forKey:NSLocalizedFailureReasonErrorKey]];
                    break;
            }
        }
    }
}

- (void)setColumnTypes:(NSArray *)columnTypes
{
    if (columnTypes == nil) {
        columnTypes = [NSArray array];
    }
    _columnTypes = [columnTypes retain];
}

- (NSArray *)execute
{
    NSMutableArray *result = [NSMutableArray array];
    BOOL step = TRUE;
    while (step) {
        switch (sqlite3_step(_stmt)) {
            case SQLITE_ROW:
                if (sqlite3_column_count(_stmt) != [_columnTypes count]) {
                    [[PRLog sharedLog] presentFatalError:nil];
                }
                NSMutableArray *column = [NSMutableArray array];
                for (int i = 0; i < [_columnTypes count]; i++) {
                    id value;
                    switch ([[_columnTypes objectAtIndex:i] intValue]) {
                        case PRColumnInteger:
                            value = [NSNumber numberWithLongLong:sqlite3_column_int64(_stmt, i)];
                            break;
                        case PRColumnFloat:
                            value = [NSNumber numberWithDouble:sqlite3_column_double(_stmt, i)];
                            break;
                        case PRColumnString:
                            value = [NSString stringWithUTF8String:(const char *)sqlite3_column_text(_stmt, i)];
                            break;
                        case PRColumnData:
                            value = [NSData dataWithBytes:sqlite3_column_blob(_stmt, i) length:sqlite3_column_bytes(_stmt, i)];
                            break;
                        default:
                            [[PRLog sharedLog] presentFatalError:nil];
                            break;
                    }
                    [column addObject:value];
                }
                [result addObject:column];
                break;
            case SQLITE_BUSY:
                usleep(50);
                break;
            case SQLITE_LOCKED:
                usleep(50);
                sqlite3_reset(_stmt);
                break;
            case SQLITE_DONE:
                step = FALSE;
                break;
            default: {
                [[PRLog sharedLog] presentFatalError:nil];
                break;
            }
        }
    }
    return result;
}

+ (NSArray *)executeString:(NSString *)string withDb:(PRDb *)db bindings:(NSDictionary *)bindings columnTypes:(NSArray *)columnTypes
{
    PRStatement *statement = [PRStatement statementWithString:string db:db];
    [statement setBindings:bindings];
    [statement setColumnTypes:columnTypes];
    return [statement execute];
}

+ (NSArray *)executeString:(NSString *)string withDb:(PRDb *)db
{
    return [PRStatement executeString:string withDb:db bindings:nil columnTypes:nil];
}

- (void)dealloc
{
    sqlite3_finalize(_stmt);
    [super dealloc];
}

@end