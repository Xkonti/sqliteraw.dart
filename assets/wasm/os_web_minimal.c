#include "../../sqlite/sqlite3.h"
#include <stddef.h>  // For NULL definition

/*
** Minimal VFS implementation for WASM compilation.
** This VFS does nothing functional - it's just enough to allow
** SQLite to compile and link successfully. The only working
** function we need is sqlite3_libversion().
*/

// Minimal file structure
typedef struct MinimalFile {
    sqlite3_file base;    // Base class - must be first
    int dummy;            // Placeholder
} MinimalFile;

// VFS method stubs that always fail
static int minimalVfsOpen(sqlite3_vfs* pVfs, const char* zName, sqlite3_file* pFile, int flags, int* pOutFlags) {
    return SQLITE_CANTOPEN; // Always fail - we don't support file operations
}

static int minimalVfsDelete(sqlite3_vfs* pVfs, const char* zName, int syncDir) {
    return SQLITE_IOERR_DELETE;
}

static int minimalVfsAccess(sqlite3_vfs* pVfs, const char* zName, int flags, int* pResOut) {
    *pResOut = 0; // File doesn't exist
    return SQLITE_OK;
}

static int minimalVfsFullPathname(sqlite3_vfs* pVfs, const char* zName, int nOut, char* zOut) {
    if (nOut > 0) {
        zOut[0] = '\0'; // Empty path
    }
    return SQLITE_OK;
}

// File method stubs (not used since xOpen always fails)
static int minimalFileClose(sqlite3_file* pFile) {
    return SQLITE_OK;
}

static int minimalFileRead(sqlite3_file* pFile, void* zBuf, int iAmt, sqlite3_int64 iOfst) {
    return SQLITE_IOERR_READ;
}

static int minimalFileWrite(sqlite3_file* pFile, const void* zBuf, int iAmt, sqlite3_int64 iOfst) {
    return SQLITE_IOERR_WRITE;
}

static int minimalFileTruncate(sqlite3_file* pFile, sqlite3_int64 size) {
    return SQLITE_IOERR_TRUNCATE;
}

static int minimalFileSync(sqlite3_file* pFile, int flags) {
    return SQLITE_OK;
}

static int minimalFileFileSize(sqlite3_file* pFile, sqlite3_int64* pSize) {
    *pSize = 0;
    return SQLITE_OK;
}

// IO methods structure
static const sqlite3_io_methods minimalIoMethods = {
    1,                      // iVersion
    minimalFileClose,       // xClose
    minimalFileRead,        // xRead
    minimalFileWrite,       // xWrite
    minimalFileTruncate,    // xTruncate
    minimalFileSync,        // xSync
    minimalFileFileSize,    // xFileSize
    NULL,                   // xLock
    NULL,                   // xUnlock
    NULL,                   // xCheckReservedLock
    NULL,                   // xFileControl
    NULL,                   // xSectorSize
    NULL,                   // xDeviceCharacteristics
};

// VFS structure
static sqlite3_vfs minimalVfs = {
    3,                          // iVersion
    sizeof(MinimalFile),        // szOsFile
    512,                        // mxPathname
    NULL,                       // pNext
    "minimal",                  // zName
    NULL,                       // pAppData
    minimalVfsOpen,             // xOpen
    minimalVfsDelete,           // xDelete
    minimalVfsAccess,           // xAccess
    minimalVfsFullPathname,     // xFullPathname
    NULL,                       // xDlOpen (not supported)
    NULL,                       // xDlError (not supported)
    NULL,                       // xDlSym (not supported)
    NULL,                       // xDlClose (not supported)
    NULL,                       // xRandomness (use default)
    NULL,                       // xSleep (use default)
    NULL,                       // xCurrentTime (use default)
    NULL,                       // xGetLastError
    NULL,                       // xCurrentTimeInt64 (use default)
};

/*
** Initialize the minimal VFS.
** This function is called from Dart after the WASM module is loaded.
*/
int sqlite3_web_vfs_init(void) {
    return sqlite3_vfs_register(&minimalVfs, 0);  // Register as non-default VFS
}