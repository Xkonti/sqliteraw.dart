// SQLite WASM Core JavaScript Wrapper Functions
// Provides JavaScript abstraction layer for SQLite C API operations
// Called by Dart through established interop pattern

let wasmInstance = null;
let wasmMemory = null;

// SQLite constants
const SQLITE_OK = 0;
const SQLITE_ERROR = 1;
const SQLITE_BUSY = 5;
const SQLITE_LOCKED = 6;
const SQLITE_NOMEM = 7;
const SQLITE_READONLY = 8;
const SQLITE_INTERRUPT = 9;
const SQLITE_IOERR = 10;
const SQLITE_CORRUPT = 11;
const SQLITE_NOTFOUND = 12;
const SQLITE_FULL = 13;
const SQLITE_CANTOPEN = 14;
const SQLITE_PROTOCOL = 15;
const SQLITE_EMPTY = 16;
const SQLITE_SCHEMA = 17;
const SQLITE_TOOBIG = 18;
const SQLITE_CONSTRAINT = 19;
const SQLITE_MISMATCH = 20;
const SQLITE_MISUSE = 21;
const SQLITE_NOLFS = 22;
const SQLITE_AUTH = 23;
const SQLITE_FORMAT = 24;
const SQLITE_RANGE = 25;
const SQLITE_NOTADB = 26;
const SQLITE_NOTICE = 27;
const SQLITE_WARNING = 28;
const SQLITE_ROW = 100;
const SQLITE_DONE = 101;

// Data types
const SQLITE_INTEGER = 1;
const SQLITE_FLOAT = 2;
const SQLITE_TEXT = 3;
const SQLITE_BLOB = 4;
const SQLITE_NULL = 5;

// Open flags
const SQLITE_OPEN_READONLY = 0x00000001;
const SQLITE_OPEN_READWRITE = 0x00000002;
const SQLITE_OPEN_CREATE = 0x00000004;

// Special values
const SQLITE_TRANSIENT = -1;

// Initialize WASM module (must be called before any other functions)
async function initializeSqliteWasm() {
    try {
        console.log('🔧 Initializing SQLite WASM module...');
        
        // Load WASM module
        const response = await fetch('sqlite3.wasm');
        if (!response.ok) {
            throw new Error(`Failed to fetch WASM: ${response.status}`);
        }
        
        const wasmBytes = await response.arrayBuffer();
        console.log(`✅ WASM bytes loaded: ${wasmBytes.byteLength} bytes`);
        
        // Create memory
        wasmMemory = new WebAssembly.Memory({ initial: 16 });
        
        // WASI stubs - just return 0 for everything
        const wasiStub = () => 0;
        const wasiVoidStub = () => {};
        
        const imports = {
            env: { memory: wasmMemory },
            wasi_snapshot_preview1: {
                proc_exit: wasiVoidStub,
                environ_get: wasiStub,
                environ_sizes_get: wasiStub,
                clock_time_get: wasiStub,
                fd_close: wasiStub,
                fd_fdstat_get: wasiStub,
                fd_fdstat_set_flags: wasiStub,
                fd_filestat_get: wasiStub,
                fd_filestat_set_size: wasiStub,
                fd_prestat_get: wasiStub,
                fd_prestat_dir_name: wasiStub,
                fd_read: wasiStub,
                fd_seek: wasiStub,
                fd_sync: wasiStub,
                fd_write: wasiStub,
                path_create_directory: wasiStub,
                path_filestat_get: wasiStub,
                path_filestat_set_times: wasiStub,
                path_open: wasiStub,
                path_readlink: wasiStub,
                path_remove_directory: wasiStub,
                path_unlink_file: wasiStub,
                poll_oneoff: wasiStub,
            }
        };
        
        console.log('📦 Instantiating WASM module...');
        const result = await WebAssembly.instantiate(wasmBytes, imports);
        wasmInstance = result.instance;
        
        console.log('✅ WASM module instantiated successfully');
        
        // Log available exports for debugging
        console.log('📋 Available WASM exports:', Object.keys(wasmInstance.exports));
        
        // Initialize SQLite
        const initResult = wasmInstance.exports.sqlite3_initialize();
        if (initResult !== SQLITE_OK) {
            throw new Error(`SQLite initialization failed: ${initResult}`);
        }
        
        console.log('✅ SQLite initialized successfully');
        return { success: true, errorCode: SQLITE_OK };
        
    } catch (error) {
        console.error('❌ Failed to initialize SQLite WASM:', error);
        return { success: false, errorCode: SQLITE_ERROR, error: error.message };
    }
}

// Helper function to allocate UTF-8 string in WASM memory
function allocateString(str) {
    const encoder = new TextEncoder();
    const bytes = encoder.encode(str + '\0'); // null-terminated
    
    // Simple memory allocation - use a growing offset from a base address
    if (!window.wasmMemoryOffset) {
        window.wasmMemoryOffset = 1024 * 1024; // Start at 1MB to avoid low memory
    }
    
    const ptr = window.wasmMemoryOffset;
    window.wasmMemoryOffset += bytes.length;
    
    const memoryView = new Uint8Array(wasmMemory.buffer);
    memoryView.set(bytes, ptr);
    return { ptr, length: bytes.length - 1 }; // exclude null terminator from length
}

// Helper function to read UTF-8 string from WASM memory
function readString(ptr) {
    if (!ptr) return '';
    
    const memoryView = new Uint8Array(wasmMemory.buffer);
    let length = 0;
    while (memoryView[ptr + length] !== 0) {
        length++;
    }
    
    const bytes = memoryView.slice(ptr, ptr + length);
    const decoder = new TextDecoder();
    return decoder.decode(bytes);
}

// Helper function to allocate 4-byte integer in WASM memory
function allocateInt32() {
    if (!window.wasmMemoryOffset) {
        window.wasmMemoryOffset = 1024 * 1024; // Start at 1MB to avoid low memory
    }
    
    const ptr = window.wasmMemoryOffset;
    window.wasmMemoryOffset += 4; // 4 bytes for int32
    return ptr;
}

// Helper function to read 4-byte integer from WASM memory
function readInt32(ptr) {
    const memoryView = new DataView(wasmMemory.buffer);
    return memoryView.getInt32(ptr, true); // little-endian
}

// Helper function to free WASM memory (simplified - no actual freeing)
function freeMemory(ptr) {
    // In this simple implementation, we don't actually free memory
    // Real implementation would need proper memory management
    // This is acceptable for testing basic functionality
}

// 1. Open Database - Wrapper for sqlite3_open_v2()
function openDatabase(path) {
    try {
        console.log(`🔧 Opening database: ${path}`);
        
        if (!wasmInstance) {
            throw new Error('WASM not initialized. Call initializeSqliteWasm() first.');
        }
        
        // Allocate memory for database path and handle
        const { ptr: pathPtr } = allocateString(path);
        const dbHandlePtr = allocateInt32();
        
        try {
            // Call sqlite3_open_v2(path, &db, flags, zVfs)
            const flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE;
            console.log(`📋 Debug: pathPtr=${pathPtr}, dbHandlePtr=${dbHandlePtr}, flags=${flags}`);
            
            const errorCode = wasmInstance.exports.sqlite3_open_v2(
                pathPtr,      // path
                dbHandlePtr,  // &db
                flags,        // flags
                0             // zVfs (null)
            );
            
            console.log(`📋 Debug: sqlite3_open_v2 returned: ${errorCode}`);
            const dbHandle = readInt32(dbHandlePtr);
            console.log(`📋 Debug: dbHandle from memory: ${dbHandle}`);
            
            if (errorCode === SQLITE_OK) {
                console.log(`✅ Database opened successfully, handle: ${dbHandle}`);
                return { success: true, dbHandle, errorCode };
            } else {
                console.error(`❌ Failed to open database, error code: ${errorCode}`);
                // Try to get error message from the database handle if available
                if (dbHandle !== 0) {
                    try {
                        const errorMsgPtr = wasmInstance.exports.sqlite3_errmsg(dbHandle);
                        const errorMsg = readString(errorMsgPtr);
                        console.error(`📋 SQLite error message: ${errorMsg}`);
                    } catch (e) {
                        console.error('📋 Could not get SQLite error message:', e);
                    }
                }
                return { success: false, dbHandle: 0, errorCode };
            }
            
        } finally {
            // Clean up allocated memory
            freeMemory(pathPtr);
            freeMemory(dbHandlePtr);
        }
        
    } catch (error) {
        console.error('❌ Error in openDatabase:', error);
        return { success: false, dbHandle: 0, errorCode: SQLITE_ERROR };
    }
}

// 2. Close Database - Wrapper for sqlite3_close()
function closeDatabase(dbHandle) {
    try {
        console.log(`🔧 Closing database handle: ${dbHandle}`);
        
        if (!wasmInstance) {
            throw new Error('WASM not initialized');
        }
        
        // Call sqlite3_close(db)
        const errorCode = wasmInstance.exports.sqlite3_close(dbHandle);
        
        if (errorCode === SQLITE_OK) {
            console.log('✅ Database closed successfully');
            return { success: true, errorCode };
        } else {
            console.error(`❌ Failed to close database, error code: ${errorCode}`);
            return { success: false, errorCode };
        }
        
    } catch (error) {
        console.error('❌ Error in closeDatabase:', error);
        return { success: false, errorCode: SQLITE_ERROR };
    }
}

// 3. Prepare Statement - Wrapper for sqlite3_prepare_v2()
function prepareStatement(dbHandle, sql) {
    try {
        console.log(`🔧 Preparing statement: ${sql.substring(0, 50)}${sql.length > 50 ? '...' : ''}`);
        
        if (!wasmInstance) {
            throw new Error('WASM not initialized');
        }
        
        // Allocate memory for SQL string and statement handle
        const { ptr: sqlPtr, length: sqlLength } = allocateString(sql);
        const stmtHandlePtr = allocateInt32();
        
        try {
            // Call sqlite3_prepare_v2(db, zSql, nByte, &pStmt, &pzTail)
            const errorCode = wasmInstance.exports.sqlite3_prepare_v2(
                dbHandle,     // db
                sqlPtr,       // zSql
                sqlLength,    // nByte
                stmtHandlePtr, // &pStmt
                0             // &pzTail (null)
            );
            
            const stmtHandle = readInt32(stmtHandlePtr);
            
            if (errorCode === SQLITE_OK) {
                console.log(`✅ Statement prepared successfully, handle: ${stmtHandle}`);
                return { success: true, stmtHandle, errorCode };
            } else {
                console.error(`❌ Failed to prepare statement, error code: ${errorCode}`);
                return { success: false, stmtHandle: 0, errorCode };
            }
            
        } finally {
            // Clean up allocated memory
            freeMemory(sqlPtr);
            freeMemory(stmtHandlePtr);
        }
        
    } catch (error) {
        console.error('❌ Error in prepareStatement:', error);
        return { success: false, stmtHandle: 0, errorCode: SQLITE_ERROR };
    }
}

// 4. Execute Statement - Wrapper for sqlite3_step()
function executeStatement(stmtHandle) {
    try {
        console.log(`🔧 Executing statement handle: ${stmtHandle}`);
        
        if (!wasmInstance) {
            throw new Error('WASM not initialized');
        }
        
        // Call sqlite3_step(pStmt)
        const resultCode = wasmInstance.exports.sqlite3_step(stmtHandle);
        
        if (resultCode === SQLITE_DONE) {
            console.log('✅ Statement executed successfully (SQLITE_DONE)');
            return { success: true, resultCode };
        } else if (resultCode === SQLITE_ROW) {
            console.log('✅ Statement executed successfully (SQLITE_ROW)');
            return { success: true, resultCode };
        } else {
            console.error(`❌ Statement execution failed, result code: ${resultCode}`);
            return { success: false, resultCode };
        }
        
    } catch (error) {
        console.error('❌ Error in executeStatement:', error);
        return { success: false, resultCode: SQLITE_ERROR };
    }
}

// 5. Finalize Statement - Wrapper for sqlite3_finalize()
function finalizeStatement(stmtHandle) {
    try {
        console.log(`🔧 Finalizing statement handle: ${stmtHandle}`);
        
        if (!wasmInstance) {
            throw new Error('WASM not initialized');
        }
        
        // Call sqlite3_finalize(pStmt)
        const errorCode = wasmInstance.exports.sqlite3_finalize(stmtHandle);
        
        if (errorCode === SQLITE_OK) {
            console.log('✅ Statement finalized successfully');
            return { success: true, errorCode };
        } else {
            console.error(`❌ Failed to finalize statement, error code: ${errorCode}`);
            return { success: false, errorCode };
        }
        
    } catch (error) {
        console.error('❌ Error in finalizeStatement:', error);
        return { success: false, errorCode: SQLITE_ERROR };
    }
}

// 6. Get Error Message - Wrapper for sqlite3_errmsg()
function getErrorMessage(dbHandle) {
    try {
        if (!wasmInstance) {
            return 'WASM not initialized';
        }
        
        // Call sqlite3_errmsg(db)
        const errorMsgPtr = wasmInstance.exports.sqlite3_errmsg(dbHandle);
        const errorMsg = readString(errorMsgPtr);
        
        console.log(`📋 Error message: ${errorMsg}`);
        return errorMsg;
        
    } catch (error) {
        console.error('❌ Error in getErrorMessage:', error);
        return 'Failed to get error message';
    }
}

// 7. Bind Text Parameter - Wrapper for sqlite3_bind_text()
function bindTextParameter(stmtHandle, paramIndex, textValue) {
    try {
        console.log(`🔧 Binding TEXT parameter ${paramIndex}: "${textValue.substring(0, 50)}${textValue.length > 50 ? '...' : ''}"`);
        
        if (!wasmInstance) {
            throw new Error('WASM not initialized');
        }
        
        // Allocate memory for text value
        const { ptr: textPtr, length: textLength } = allocateString(textValue);
        
        try {
            // Call sqlite3_bind_text(stmt, index, text, length, destructor)
            const errorCode = wasmInstance.exports.sqlite3_bind_text(
                stmtHandle,        // stmt
                paramIndex,        // index
                textPtr,          // text
                textLength,       // length
                SQLITE_TRANSIENT  // destructor - SQLite makes copy
            );
            
            if (errorCode === SQLITE_OK) {
                console.log(`✅ TEXT parameter ${paramIndex} bound successfully`);
                return { success: true, errorCode };
            } else {
                console.error(`❌ Failed to bind TEXT parameter ${paramIndex}, error code: ${errorCode}`);
                return { success: false, errorCode };
            }
            
        } finally {
            // Clean up allocated memory
            freeMemory(textPtr);
        }
        
    } catch (error) {
        console.error('❌ Error in bindTextParameter:', error);
        return { success: false, errorCode: SQLITE_ERROR };
    }
}

// 8. Bind Integer Parameter - Wrapper for sqlite3_bind_int()
function bindIntParameter(stmtHandle, paramIndex, intValue) {
    try {
        console.log(`🔧 Binding INTEGER parameter ${paramIndex}: ${intValue}`);
        
        if (!wasmInstance) {
            throw new Error('WASM not initialized');
        }
        
        // Call sqlite3_bind_int(stmt, index, value)
        const errorCode = wasmInstance.exports.sqlite3_bind_int(
            stmtHandle,  // stmt
            paramIndex,  // index
            intValue     // value
        );
        
        if (errorCode === SQLITE_OK) {
            console.log(`✅ INTEGER parameter ${paramIndex} bound successfully`);
            return { success: true, errorCode };
        } else {
            console.error(`❌ Failed to bind INTEGER parameter ${paramIndex}, error code: ${errorCode}`);
            return { success: false, errorCode };
        }
        
    } catch (error) {
        console.error('❌ Error in bindIntParameter:', error);
        return { success: false, errorCode: SQLITE_ERROR };
    }
}

// 9. Bind BLOB Parameter - Wrapper for sqlite3_bind_blob()
function bindBlobParameter(stmtHandle, paramIndex, blobData) {
    try {
        console.log(`🔧 Binding BLOB parameter ${paramIndex}: ${blobData.length} bytes`);
        
        if (!wasmInstance) {
            throw new Error('WASM not initialized');
        }
        
        // Allocate memory for blob data
        if (!window.wasmMemoryOffset) {
            window.wasmMemoryOffset = 1024 * 1024;
        }
        
        const blobPtr = window.wasmMemoryOffset;
        window.wasmMemoryOffset += blobData.length;
        
        // Copy blob data to WASM memory
        const memoryView = new Uint8Array(wasmMemory.buffer);
        memoryView.set(blobData, blobPtr);
        
        try {
            // Call sqlite3_bind_blob(stmt, index, blob, length, destructor)
            const errorCode = wasmInstance.exports.sqlite3_bind_blob(
                stmtHandle,        // stmt
                paramIndex,        // index
                blobPtr,          // blob
                blobData.length,  // length
                SQLITE_TRANSIENT  // destructor - SQLite makes copy
            );
            
            if (errorCode === SQLITE_OK) {
                console.log(`✅ BLOB parameter ${paramIndex} bound successfully`);
                return { success: true, errorCode };
            } else {
                console.error(`❌ Failed to bind BLOB parameter ${paramIndex}, error code: ${errorCode}`);
                return { success: false, errorCode };
            }
            
        } finally {
            // Memory cleanup handled by simple allocator
        }
        
    } catch (error) {
        console.error('❌ Error in bindBlobParameter:', error);
        return { success: false, errorCode: SQLITE_ERROR };
    }
}

// 10. Bind NULL Parameter - Wrapper for sqlite3_bind_null()
function bindNullParameter(stmtHandle, paramIndex) {
    try {
        console.log(`🔧 Binding NULL parameter ${paramIndex}`);
        
        if (!wasmInstance) {
            throw new Error('WASM not initialized');
        }
        
        // Call sqlite3_bind_null(stmt, index)
        const errorCode = wasmInstance.exports.sqlite3_bind_null(
            stmtHandle,  // stmt
            paramIndex   // index
        );
        
        if (errorCode === SQLITE_OK) {
            console.log(`✅ NULL parameter ${paramIndex} bound successfully`);
            return { success: true, errorCode };
        } else {
            console.error(`❌ Failed to bind NULL parameter ${paramIndex}, error code: ${errorCode}`);
            return { success: false, errorCode };
        }
        
    } catch (error) {
        console.error('❌ Error in bindNullParameter:', error);
        return { success: false, errorCode: SQLITE_ERROR };
    }
}

// 11. Get Parameter Count - Wrapper for sqlite3_bind_parameter_count()
function getParameterCount(stmtHandle) {
    try {
        if (!wasmInstance) {
            throw new Error('WASM not initialized');
        }
        
        // Call sqlite3_bind_parameter_count(stmt)
        const paramCount = wasmInstance.exports.sqlite3_bind_parameter_count(stmtHandle);
        
        console.log(`📋 Statement has ${paramCount} parameters`);
        return paramCount;
        
    } catch (error) {
        console.error('❌ Error in getParameterCount:', error);
        return 0;
    }
}

// 12. Get Column Count - Wrapper for sqlite3_column_count()
function getColumnCount(stmtHandle) {
    try {
        if (!wasmInstance) {
            throw new Error('WASM not initialized');
        }
        
        // Call sqlite3_column_count(stmt)
        const columnCount = wasmInstance.exports.sqlite3_column_count(stmtHandle);
        
        console.log(`📋 Result set has ${columnCount} columns`);
        return columnCount;
        
    } catch (error) {
        console.error('❌ Error in getColumnCount:', error);
        return 0;
    }
}

// 13. Get Column Type - Wrapper for sqlite3_column_type()
function getColumnType(stmtHandle, columnIndex) {
    try {
        if (!wasmInstance) {
            throw new Error('WASM not initialized');
        }
        
        // Call sqlite3_column_type(stmt, index)
        const columnType = wasmInstance.exports.sqlite3_column_type(stmtHandle, columnIndex);
        
        const typeNames = {
            [SQLITE_INTEGER]: 'INTEGER',
            [SQLITE_FLOAT]: 'FLOAT', 
            [SQLITE_TEXT]: 'TEXT',
            [SQLITE_BLOB]: 'BLOB',
            [SQLITE_NULL]: 'NULL'
        };
        
        console.log(`📋 Column ${columnIndex} type: ${typeNames[columnType] || 'UNKNOWN'} (${columnType})`);
        return columnType;
        
    } catch (error) {
        console.error('❌ Error in getColumnType:', error);
        return SQLITE_NULL;
    }
}

// 14. Get Column Text - Wrapper for sqlite3_column_text()
function getColumnText(stmtHandle, columnIndex) {
    try {
        if (!wasmInstance) {
            throw new Error('WASM not initialized');
        }
        
        // Call sqlite3_column_text(stmt, index)
        const textPtr = wasmInstance.exports.sqlite3_column_text(stmtHandle, columnIndex);
        
        if (textPtr === 0) {
            console.log(`📋 Column ${columnIndex} TEXT value: null`);
            return null;
        }
        
        const textValue = readString(textPtr);
        console.log(`📋 Column ${columnIndex} TEXT value: "${textValue.substring(0, 50)}${textValue.length > 50 ? '...' : ''}"`);
        return textValue;
        
    } catch (error) {
        console.error('❌ Error in getColumnText:', error);
        return null;
    }
}

// 15. Get Column Integer - Wrapper for sqlite3_column_int()
function getColumnInt(stmtHandle, columnIndex) {
    try {
        if (!wasmInstance) {
            throw new Error('WASM not initialized');
        }
        
        // Call sqlite3_column_int(stmt, index)
        const intValue = wasmInstance.exports.sqlite3_column_int(stmtHandle, columnIndex);
        
        console.log(`📋 Column ${columnIndex} INTEGER value: ${intValue}`);
        return intValue;
        
    } catch (error) {
        console.error('❌ Error in getColumnInt:', error);
        return 0;
    }
}

// 16. Get Column BLOB - Wrapper for sqlite3_column_blob() and sqlite3_column_bytes()
function getColumnBlob(stmtHandle, columnIndex) {
    try {
        if (!wasmInstance) {
            throw new Error('WASM not initialized');
        }
        
        // Get blob data pointer and length
        const blobPtr = wasmInstance.exports.sqlite3_column_blob(stmtHandle, columnIndex);
        const blobLength = wasmInstance.exports.sqlite3_column_bytes(stmtHandle, columnIndex);
        
        if (blobPtr === 0 || blobLength === 0) {
            console.log(`📋 Column ${columnIndex} BLOB value: null or empty`);
            return new Uint8Array(0);
        }
        
        // Copy binary data from WASM memory to JavaScript Uint8Array
        const memoryView = new Uint8Array(wasmMemory.buffer);
        const blobData = memoryView.slice(blobPtr, blobPtr + blobLength);
        
        console.log(`📋 Column ${columnIndex} BLOB value: ${blobLength} bytes`);
        return blobData;
        
    } catch (error) {
        console.error('❌ Error in getColumnBlob:', error);
        return new Uint8Array(0);
    }
}

// 17. Get Column Name - Wrapper for sqlite3_column_name()
function getColumnName(stmtHandle, columnIndex) {
    try {
        if (!wasmInstance) {
            throw new Error('WASM not initialized');
        }
        
        // Call sqlite3_column_name(stmt, index)
        const namePtr = wasmInstance.exports.sqlite3_column_name(stmtHandle, columnIndex);
        
        if (namePtr === 0) {
            console.log(`📋 Column ${columnIndex} name: null`);
            return null;
        }
        
        const columnName = readString(namePtr);
        console.log(`📋 Column ${columnIndex} name: "${columnName}"`);
        return columnName;
        
    } catch (error) {
        console.error('❌ Error in getColumnName:', error);
        return null;
    }
}

// 18. Get Parameter Index - Wrapper for sqlite3_bind_parameter_index()
function getParameterIndex(stmtHandle, paramName) {
    try {
        console.log(`🔧 Resolving parameter name: "${paramName}"`);
        
        if (!wasmInstance) {
            throw new Error('WASM not initialized');
        }
        
        // Allocate memory for parameter name
        const { ptr: namePtr } = allocateString(paramName);
        
        try {
            // Call sqlite3_bind_parameter_index(stmt, name)
            const paramIndex = wasmInstance.exports.sqlite3_bind_parameter_index(stmtHandle, namePtr);
            
            if (paramIndex > 0) {
                console.log(`✅ Parameter "${paramName}" resolved to index ${paramIndex}`);
            } else {
                console.log(`❌ Parameter "${paramName}" not found`);
            }
            
            return paramIndex;
            
        } finally {
            // Clean up allocated memory
            freeMemory(namePtr);
        }
        
    } catch (error) {
        console.error('❌ Error in getParameterIndex:', error);
        return 0;
    }
}

// 19. Get Parameter Name - Wrapper for sqlite3_bind_parameter_name()
function getParameterName(stmtHandle, paramIndex) {
    try {
        if (!wasmInstance) {
            throw new Error('WASM not initialized');
        }
        
        // Call sqlite3_bind_parameter_name(stmt, index)
        const namePtr = wasmInstance.exports.sqlite3_bind_parameter_name(stmtHandle, paramIndex);
        
        if (namePtr === 0) {
            console.log(`📋 Parameter index ${paramIndex} has no name`);
            return null;
        }
        
        const paramName = readString(namePtr);
        console.log(`📋 Parameter index ${paramIndex} name: "${paramName}"`);
        return paramName;
        
    } catch (error) {
        console.error('❌ Error in getParameterName:', error);
        return null;
    }
}

// 20. Bind Parameter By Name - High-level binding function
function bindParameterByName(stmtHandle, paramName, value, dataType) {
    try {
        console.log(`🔧 Binding parameter by name: "${paramName}" = ${value} (${dataType})`);
        
        if (!wasmInstance) {
            throw new Error('WASM not initialized');
        }
        
        // Resolve parameter name to index
        const resolvedIndex = getParameterIndex(stmtHandle, paramName);
        if (resolvedIndex === 0) {
            console.error(`❌ Parameter "${paramName}" not found in statement`);
            return { success: false, errorCode: SQLITE_ERROR, resolvedIndex: 0 };
        }
        
        // Call appropriate bind function based on data type
        let bindResult;
        switch (dataType.toUpperCase()) {
            case 'TEXT':
                bindResult = bindTextParameter(stmtHandle, resolvedIndex, value);
                break;
            case 'INTEGER':
                bindResult = bindIntParameter(stmtHandle, resolvedIndex, value);
                break;
            case 'BLOB':
                bindResult = bindBlobParameter(stmtHandle, resolvedIndex, value);
                break;
            case 'NULL':
                bindResult = bindNullParameter(stmtHandle, resolvedIndex);
                break;
            default:
                throw new Error(`Unsupported data type: ${dataType}`);
        }
        
        if (bindResult.success) {
            console.log(`✅ Parameter "${paramName}" (index ${resolvedIndex}) bound successfully`);
            return { success: true, errorCode: SQLITE_OK, resolvedIndex };
        } else {
            console.error(`❌ Failed to bind parameter "${paramName}": ${bindResult.errorCode}`);
            return { success: false, errorCode: bindResult.errorCode, resolvedIndex };
        }
        
    } catch (error) {
        console.error('❌ Error in bindParameterByName:', error);
        return { success: false, errorCode: SQLITE_ERROR, resolvedIndex: 0 };
    }
}

// 21. Clear Bindings - Wrapper for sqlite3_clear_bindings()
function clearBindings(stmtHandle) {
    try {
        console.log(`🔧 Clearing all parameter bindings for statement ${stmtHandle}`);
        
        if (!wasmInstance) {
            throw new Error('WASM not initialized');
        }
        
        // Call sqlite3_clear_bindings(stmt)
        const errorCode = wasmInstance.exports.sqlite3_clear_bindings(stmtHandle);
        
        if (errorCode === SQLITE_OK) {
            console.log('✅ All parameter bindings cleared successfully');
            return { success: true, errorCode };
        } else {
            console.error(`❌ Failed to clear bindings, error code: ${errorCode}`);
            return { success: false, errorCode };
        }
        
    } catch (error) {
        console.error('❌ Error in clearBindings:', error);
        return { success: false, errorCode: SQLITE_ERROR };
    }
}

// 22. Reset Statement - Wrapper for sqlite3_reset()
function resetStatement(stmtHandle) {
    try {
        console.log(`🔧 Resetting statement ${stmtHandle} to initial state`);
        
        if (!wasmInstance) {
            throw new Error('WASM not initialized');
        }
        
        // Call sqlite3_reset(stmt)
        const errorCode = wasmInstance.exports.sqlite3_reset(stmtHandle);
        
        if (errorCode === SQLITE_OK) {
            console.log('✅ Statement reset successfully');
            return { success: true, errorCode };
        } else {
            console.error(`❌ Failed to reset statement, error code: ${errorCode}`);
            return { success: false, errorCode };
        }
        
    } catch (error) {
        console.error('❌ Error in resetStatement:', error);
        return { success: false, errorCode: SQLITE_ERROR };
    }
}

// 23. Get All Column Names - Get all column names from result set
function getAllColumnNames(stmtHandle) {
    try {
        if (!wasmInstance) {
            throw new Error('WASM not initialized');
        }
        
        const columnCount = getColumnCount(stmtHandle);
        const columnNames = [];
        
        console.log(`📋 Getting column names for ${columnCount} columns`);
        
        for (let i = 0; i < columnCount; i++) {
            const columnName = getColumnName(stmtHandle, i);
            columnNames.push(columnName || `column_${i}`);
        }
        
        console.log(`✅ Retrieved column names: [${columnNames.map(name => `"${name}"`).join(', ')}]`);
        return columnNames;
        
    } catch (error) {
        console.error('❌ Error in getAllColumnNames:', error);
        return [];
    }
}

// 24. Get All Column Types - Get all column types from current row
function getAllColumnTypes(stmtHandle) {
    try {
        if (!wasmInstance) {
            throw new Error('WASM not initialized');
        }
        
        const columnCount = getColumnCount(stmtHandle);
        const columnTypes = [];
        
        const typeNames = {
            [SQLITE_INTEGER]: 'INTEGER',
            [SQLITE_FLOAT]: 'FLOAT', 
            [SQLITE_TEXT]: 'TEXT',
            [SQLITE_BLOB]: 'BLOB',
            [SQLITE_NULL]: 'NULL'
        };
        
        console.log(`📋 Getting column types for ${columnCount} columns`);
        
        for (let i = 0; i < columnCount; i++) {
            const columnType = getColumnType(stmtHandle, i);
            columnTypes.push(columnType);
        }
        
        const typeList = columnTypes.map(type => typeNames[type] || `UNKNOWN(${type})`);
        console.log(`✅ Retrieved column types: [${typeList.join(', ')}]`);
        return columnTypes;
        
    } catch (error) {
        console.error('❌ Error in getAllColumnTypes:', error);
        return [];
    }
}

// 25. Get Current Row Values - Get all values from current row
function getCurrentRowValues(stmtHandle) {
    try {
        if (!wasmInstance) {
            throw new Error('WASM not initialized');
        }
        
        const columnCount = getColumnCount(stmtHandle);
        const rowValues = [];
        
        console.log(`📋 Getting values for ${columnCount} columns in current row`);
        
        for (let i = 0; i < columnCount; i++) {
            const columnType = getColumnType(stmtHandle, i);
            let value;
            
            switch (columnType) {
                case SQLITE_INTEGER:
                    value = getColumnInt(stmtHandle, i);
                    break;
                case SQLITE_TEXT:
                    value = getColumnText(stmtHandle, i);
                    break;
                case SQLITE_BLOB:
                    value = getColumnBlob(stmtHandle, i);
                    break;
                case SQLITE_NULL:
                    value = null;
                    break;
                case SQLITE_FLOAT:
                    // For now, treat FLOAT as INTEGER since we don't have sqlite3_column_double wrapper
                    value = getColumnInt(stmtHandle, i);
                    break;
                default:
                    console.warn(`⚠️ Unknown column type ${columnType}, treating as NULL`);
                    value = null;
            }
            
            rowValues.push(value);
        }
        
        console.log(`✅ Retrieved row values: [${rowValues.map(v => 
            v === null ? 'NULL' : 
            typeof v === 'string' ? `"${v.substring(0, 20)}${v.length > 20 ? '...' : ''}"` :
            v instanceof Uint8Array ? `BLOB(${v.length} bytes)` :
            v.toString()
        ).join(', ')}]`);
        
        return rowValues;
        
    } catch (error) {
        console.error('❌ Error in getCurrentRowValues:', error);
        return [];
    }
}

// 26. Get Current Row Object - Get current row as named object
function getCurrentRowObject(stmtHandle) {
    try {
        if (!wasmInstance) {
            throw new Error('WASM not initialized');
        }
        
        const columnNames = getAllColumnNames(stmtHandle);
        const rowValues = getCurrentRowValues(stmtHandle);
        
        if (columnNames.length !== rowValues.length) {
            throw new Error(`Column count mismatch: ${columnNames.length} names vs ${rowValues.length} values`);
        }
        
        const rowObject = {};
        const usedNames = new Set();
        
        for (let i = 0; i < columnNames.length; i++) {
            let columnName = columnNames[i] || `column_${i}`;
            
            // Handle duplicate column names by appending numeric suffix
            let finalName = columnName;
            let suffix = 1;
            while (usedNames.has(finalName)) {
                finalName = `${columnName}_${suffix}`;
                suffix++;
            }
            usedNames.add(finalName);
            
            rowObject[finalName] = rowValues[i];
        }
        
        console.log(`✅ Created row object with ${Object.keys(rowObject).length} properties`);
        return rowObject;
        
    } catch (error) {
        console.error('❌ Error in getCurrentRowObject:', error);
        return {};
    }
}

// 27. Iterate All Rows - Get complete result set as array of objects
function iterateAllRows(stmtHandle) {
    try {
        if (!wasmInstance) {
            throw new Error('WASM not initialized');
        }
        
        console.log(`🔧 Starting complete result set iteration for statement ${stmtHandle}`);
        const startTime = performance.now();
        
        const rows = [];
        let rowCount = 0;
        
        // Get column names once for efficiency
        const columnNames = getAllColumnNames(stmtHandle);
        console.log(`📋 Result set has ${columnNames.length} columns: [${columnNames.join(', ')}]`);
        
        // Iterate through all rows
        while (true) {
            const executeResult = executeStatement(stmtHandle);
            
            if (!executeResult.success) {
                throw new Error(`Failed to execute statement: ${executeResult.resultCode}`);
            }
            
            if (executeResult.resultCode === SQLITE_DONE) {
                console.log(`✅ Reached end of result set (SQLITE_DONE)`);
                break;
            } else if (executeResult.resultCode === SQLITE_ROW) {
                // Get current row data
                const rowObject = getCurrentRowObject(stmtHandle);
                rows.push(rowObject);
                rowCount++;
                
                if (rowCount % 100 === 0) {
                    console.log(`📊 Processed ${rowCount} rows...`);
                }
                
                // Safety check to prevent memory exhaustion
                if (rowCount >= 10000) {
                    console.warn('⚠️ Result set exceeds 10,000 rows, stopping iteration to prevent memory issues');
                    break;
                }
            } else {
                throw new Error(`Unexpected sqlite3_step result: ${executeResult.resultCode}`);
            }
        }
        
        const endTime = performance.now();
        const duration = endTime - startTime;
        
        console.log(`🎉 Result set iteration complete:`);
        console.log(`  📊 Rows retrieved: ${rowCount}`);
        console.log(`  ⏱️ Duration: ${duration.toFixed(2)}ms`);
        console.log(`  🚀 Average: ${rowCount > 0 ? (duration / rowCount).toFixed(3) : 0}ms per row`);
        
        return {
            rows: rows,
            rowCount: rowCount,
            columnNames: columnNames,
            durationMs: duration
        };
        
    } catch (error) {
        console.error('❌ Error in iterateAllRows:', error);
        return {
            rows: [],
            rowCount: 0,
            columnNames: [],
            durationMs: 0,
            error: error.message
        };
    }
}

// ==================== ERROR HANDLING FUNCTIONS ====================

// SQLite error code constants and mappings
const SQLITE_ERROR_CODES = {
    0: 'SQLITE_OK',
    1: 'SQLITE_ERROR', 
    2: 'SQLITE_INTERNAL',
    3: 'SQLITE_PERM',
    4: 'SQLITE_ABORT',
    5: 'SQLITE_BUSY',
    6: 'SQLITE_LOCKED',
    7: 'SQLITE_NOMEM',
    8: 'SQLITE_READONLY',
    9: 'SQLITE_INTERRUPT',
    10: 'SQLITE_IOERR',
    11: 'SQLITE_CORRUPT',
    12: 'SQLITE_NOTFOUND',
    13: 'SQLITE_FULL',
    14: 'SQLITE_CANTOPEN',
    15: 'SQLITE_PROTOCOL',
    16: 'SQLITE_EMPTY',
    17: 'SQLITE_SCHEMA',
    18: 'SQLITE_TOOBIG',
    19: 'SQLITE_CONSTRAINT',
    20: 'SQLITE_MISMATCH',
    21: 'SQLITE_MISUSE',
    22: 'SQLITE_NOLFS',
    23: 'SQLITE_AUTH',
    24: 'SQLITE_FORMAT',
    25: 'SQLITE_RANGE',
    26: 'SQLITE_NOTADB',
    27: 'SQLITE_NOTICE',
    28: 'SQLITE_WARNING',
    100: 'SQLITE_ROW',
    101: 'SQLITE_DONE'
};

// 1. Get Last Error Code - Wrapper for sqlite3_errcode()
function getLastErrorCode(dbHandle) {
    try {
        if (!wasmInstance) {
            throw new Error('WASM not initialized');
        }
        
        console.log(`🔍 Getting last error code for database handle: ${dbHandle}`);
        
        // Call sqlite3_errcode(db)
        const errorCode = wasmInstance.exports.sqlite3_errcode(dbHandle);
        const errorName = SQLITE_ERROR_CODES[errorCode] || `UNKNOWN_ERROR_${errorCode}`;
        
        console.log(`📋 Last error code: ${errorCode} (${errorName})`);
        return errorCode;
        
    } catch (error) {
        console.error('❌ Error in getLastErrorCode:', error);
        return 1; // SQLITE_ERROR
    }
}

// 2. Get Last Error Message - Wrapper for sqlite3_errmsg()
function getLastErrorMessage(dbHandle) {
    try {
        if (!wasmInstance) {
            throw new Error('WASM not initialized');
        }
        
        console.log(`🔍 Getting last error message for database handle: ${dbHandle}`);
        
        // Call sqlite3_errmsg(db) to get error message pointer
        const errorMsgPtr = wasmInstance.exports.sqlite3_errmsg(dbHandle);
        
        if (!errorMsgPtr) {
            console.log('📋 No error message available');
            return '';
        }
        
        // Convert UTF-8 string from WASM memory to JavaScript string
        const errorMessage = readStringFromMemory(errorMsgPtr);
        
        console.log(`📋 Last error message: "${errorMessage}"`);
        return errorMessage;
        
    } catch (error) {
        console.error('❌ Error in getLastErrorMessage:', error);
        return 'Failed to retrieve error message';
    }
}

// 3. Get Extended Error Code - Wrapper for sqlite3_extended_errcode()
function getExtendedErrorCode(dbHandle) {
    try {
        if (!wasmInstance) {
            throw new Error('WASM not initialized');
        }
        
        console.log(`🔍 Getting extended error code for database handle: ${dbHandle}`);
        
        // Call sqlite3_extended_errcode(db)
        const extendedErrorCode = wasmInstance.exports.sqlite3_extended_errcode(dbHandle);
        const primaryCode = extendedErrorCode & 0xFF;
        const extendedInfo = extendedErrorCode >> 8;
        
        const primaryName = SQLITE_ERROR_CODES[primaryCode] || `UNKNOWN_ERROR_${primaryCode}`;
        
        console.log(`📋 Extended error code: ${extendedErrorCode} (primary: ${primaryCode}/${primaryName}, extended: ${extendedInfo})`);
        return extendedErrorCode;
        
    } catch (error) {
        console.error('❌ Error in getExtendedErrorCode:', error);
        return 1; // SQLITE_ERROR
    }
}

// 4. Check Operation Result - Error validation helper
function checkOperationResult(dbHandle, operationName, expectedCodes) {
    try {
        if (!wasmInstance) {
            throw new Error('WASM not initialized');
        }
        
        const errorCode = getLastErrorCode(dbHandle);
        const errorMessage = getLastErrorMessage(dbHandle);
        const extendedErrorCode = getExtendedErrorCode(dbHandle);
        
        // Convert JavaScript array to actual array if needed
        const expectedArray = Array.isArray(expectedCodes) ? expectedCodes : [expectedCodes];
        const success = expectedArray.includes(errorCode);
        
        const result = {
            success: success,
            errorCode: errorCode,
            extendedErrorCode: extendedErrorCode,
            errorMessage: errorMessage,
            operationName: operationName
        };
        
        if (success) {
            console.log(`✅ Operation "${operationName}" succeeded with code ${errorCode} (${SQLITE_ERROR_CODES[errorCode] || 'UNKNOWN'})`);
        } else {
            console.error(`❌ Operation "${operationName}" failed with code ${errorCode} (${SQLITE_ERROR_CODES[errorCode] || 'UNKNOWN'}): ${errorMessage}`);
            if (extendedErrorCode !== errorCode) {
                console.error(`📋 Extended error code: ${extendedErrorCode}`);
            }
        }
        
        return result;
        
    } catch (error) {
        console.error(`❌ Error checking operation result for "${operationName}":`, error);
        return {
            success: false,
            errorCode: 1, // SQLITE_ERROR
            extendedErrorCode: 1,
            errorMessage: `Failed to check operation result: ${error.message}`,
            operationName: operationName
        };
    }
}

// 5. Enhanced Error Reporting for Existing Functions
function createEnhancedResult(dbHandle, operationName, baseResult, expectedCodes = [0]) {
    const errorCheck = checkOperationResult(dbHandle, operationName, expectedCodes);
    
    return {
        ...baseResult,
        success: errorCheck.success,
        errorCode: errorCheck.errorCode,
        extendedErrorCode: errorCheck.extendedErrorCode,
        errorMessage: errorCheck.errorMessage,
        operationName: operationName
    };
}

// Export functions to global scope for Dart interop
window.initializeSqliteWasm = initializeSqliteWasm;
window.openDatabase = openDatabase;
window.closeDatabase = closeDatabase;
window.prepareStatement = prepareStatement;
window.executeStatement = executeStatement;
window.finalizeStatement = finalizeStatement;
window.getErrorMessage = getErrorMessage;
window.bindTextParameter = bindTextParameter;
window.bindIntParameter = bindIntParameter;
window.bindBlobParameter = bindBlobParameter;
window.bindNullParameter = bindNullParameter;
window.getParameterCount = getParameterCount;
window.getColumnCount = getColumnCount;
window.getColumnType = getColumnType;
window.getColumnText = getColumnText;
window.getColumnInt = getColumnInt;
window.getColumnBlob = getColumnBlob;
window.getColumnName = getColumnName;
window.getParameterIndex = getParameterIndex;
window.getParameterName = getParameterName;
window.bindParameterByName = bindParameterByName;
window.clearBindings = clearBindings;
window.resetStatement = resetStatement;
window.getAllColumnNames = getAllColumnNames;
window.getAllColumnTypes = getAllColumnTypes;
window.getCurrentRowValues = getCurrentRowValues;
window.getCurrentRowObject = getCurrentRowObject;
window.iterateAllRows = iterateAllRows;
window.getLastErrorCode = getLastErrorCode;
window.getLastErrorMessage = getLastErrorMessage;
window.getExtendedErrorCode = getExtendedErrorCode;
window.checkOperationResult = checkOperationResult;
window.createEnhancedResult = createEnhancedResult;

// ==================== MEMORY MANAGEMENT FUNCTIONS ====================

// Global memory monitoring state
let memoryMonitoringInterval = null;
let memoryUsageHistory = [];
let memoryBaseline = null;

// 1. Get current WASM memory usage
function getWasmMemoryUsage() {
    try {
        if (!wasmMemory) {
            return {
                totalBytes: 0,
                usedBytes: 0,
                freeBytes: 0,
                utilizationPercent: 0,
                error: 'WASM memory not initialized'
            };
        }
        
        const totalBytes = wasmMemory.buffer.byteLength;
        const usedBytes = window.wasmMemoryOffset || 0;
        const freeBytes = totalBytes - usedBytes;
        const utilizationPercent = totalBytes > 0 ? (usedBytes / totalBytes) * 100 : 0;
        
        const usage = {
            totalBytes,
            usedBytes,
            freeBytes,
            utilizationPercent: parseFloat(utilizationPercent.toFixed(2)),
            timestamp: Date.now()
        };
        
        console.log(`📊 WASM Memory Usage: ${usage.usedBytes}/${usage.totalBytes} bytes (${usage.utilizationPercent}%)`);
        return usage;
        
    } catch (error) {
        console.error('❌ Error getting WASM memory usage:', error);
        return {
            totalBytes: 0,
            usedBytes: 0,
            freeBytes: 0,
            utilizationPercent: 0,
            error: error.message
        };
    }
}

// 2. Start continuous memory monitoring
function startMemoryMonitoring(intervalMs = 1000) {
    try {
        // Stop any existing monitoring
        if (memoryMonitoringInterval) {
            stopMemoryMonitoring(memoryMonitoringInterval);
        }
        
        console.log(`🔍 Starting memory monitoring (interval: ${intervalMs}ms)`);
        
        // Reset monitoring state
        memoryUsageHistory = [];
        
        // Start periodic monitoring
        memoryMonitoringInterval = setInterval(() => {
            const usage = getWasmMemoryUsage();
            if (!usage.error) {
                memoryUsageHistory.push(usage);
                
                // Log significant memory changes
                if (memoryUsageHistory.length > 1) {
                    const previous = memoryUsageHistory[memoryUsageHistory.length - 2];
                    const change = usage.usedBytes - previous.usedBytes;
                    
                    if (Math.abs(change) > 1024) { // Log changes > 1KB
                        console.log(`📈 Memory change: ${change > 0 ? '+' : ''}${change} bytes`);
                    }
                }
                
                // Keep history manageable (last 1000 entries)
                if (memoryUsageHistory.length > 1000) {
                    memoryUsageHistory = memoryUsageHistory.slice(-1000);
                }
            }
        }, intervalMs);
        
        return {
            handle: memoryMonitoringInterval,
            intervalMs: intervalMs,
            startTime: Date.now()
        };
        
    } catch (error) {
        console.error('❌ Error starting memory monitoring:', error);
        return { handle: null, error: error.message };
    }
}

// 3. Stop memory monitoring and generate report
function stopMemoryMonitoring(handle) {
    try {
        if (!handle || handle !== memoryMonitoringInterval) {
            console.warn('⚠️ Invalid monitoring handle or monitoring not active');
            return { success: false, error: 'Invalid handle' };
        }
        
        clearInterval(memoryMonitoringInterval);
        memoryMonitoringInterval = null;
        
        console.log('🔍 Stopping memory monitoring');
        
        // Generate comprehensive report
        if (memoryUsageHistory.length === 0) {
            return {
                success: true,
                report: {
                    duration: 0,
                    samples: 0,
                    peak: null,
                    average: null,
                    trend: 'insufficient_data'
                }
            };
        }
        
        const startTime = memoryUsageHistory[0].timestamp;
        const endTime = memoryUsageHistory[memoryUsageHistory.length - 1].timestamp;
        const duration = endTime - startTime;
        
        const usageValues = memoryUsageHistory.map(h => h.usedBytes);
        const peak = Math.max(...usageValues);
        const average = usageValues.reduce((sum, val) => sum + val, 0) / usageValues.length;
        
        // Calculate trend (simple linear regression)
        let trend = 'stable';
        if (memoryUsageHistory.length >= 10) {
            const recent = usageValues.slice(-10);
            const early = usageValues.slice(0, 10);
            const recentAvg = recent.reduce((sum, val) => sum + val, 0) / recent.length;
            const earlyAvg = early.reduce((sum, val) => sum + val, 0) / early.length;
            
            const change = ((recentAvg - earlyAvg) / earlyAvg) * 100;
            if (change > 5) trend = 'increasing';
            else if (change < -5) trend = 'decreasing';
        }
        
        const report = {
            success: true,
            report: {
                duration: duration,
                samples: memoryUsageHistory.length,
                peak: peak,
                average: Math.round(average),
                trend: trend,
                startUsage: memoryUsageHistory[0],
                endUsage: memoryUsageHistory[memoryUsageHistory.length - 1],
                history: memoryUsageHistory.slice() // Copy for caller
            }
        };
        
        console.log(`📊 Memory monitoring report:`, report.report);
        
        // Clear history
        memoryUsageHistory = [];
        
        return report;
        
    } catch (error) {
        console.error('❌ Error stopping memory monitoring:', error);
        return { success: false, error: error.message };
    }
}

// 4. Detect memory leaks by comparing usage
function detectMemoryLeaks(baselineUsage, currentUsage, toleranceBytes = 1024) {
    try {
        console.log('🔍 Detecting memory leaks...');
        
        if (!baselineUsage || !currentUsage) {
            return {
                hasLeak: false,
                error: 'Invalid baseline or current usage data'
            };
        }
        
        const memoryGrowth = currentUsage.usedBytes - baselineUsage.usedBytes;
        const hasLeak = memoryGrowth > toleranceBytes;
        
        const result = {
            hasLeak: hasLeak,
            memoryGrowth: memoryGrowth,
            toleranceBytes: toleranceBytes,
            baseline: baselineUsage,
            current: currentUsage,
            growthPercent: baselineUsage.usedBytes > 0 ? 
                ((memoryGrowth / baselineUsage.usedBytes) * 100) : 0,
            recommendation: hasLeak ? 
                'Potential memory leak detected - check resource cleanup' : 
                'Memory usage within acceptable range'
        };
        
        if (hasLeak) {
            console.warn(`⚠️ Potential memory leak detected: +${memoryGrowth} bytes (tolerance: ${toleranceBytes})`);
        } else {
            console.log(`✅ No memory leak detected: ${memoryGrowth > 0 ? '+' : ''}${memoryGrowth} bytes (within tolerance)`);
        }
        
        return result;
        
    } catch (error) {
        console.error('❌ Error detecting memory leaks:', error);
        return {
            hasLeak: false,
            error: error.message
        };
    }
}

// 5. Reset memory baseline for leak detection
function resetMemoryBaseline() {
    try {
        console.log('🔄 Resetting memory baseline...');
        
        // Force garbage collection if available (browser-specific)
        if (window.gc) {
            window.gc();
            console.log('🗑️ Forced garbage collection');
        }
        
        // Small delay to let GC complete
        return new Promise((resolve) => {
            setTimeout(() => {
                const baseline = getWasmMemoryUsage();
                if (!baseline.error) {
                    memoryBaseline = baseline;
                    console.log(`📏 Memory baseline established: ${baseline.usedBytes} bytes`);
                    resolve({
                        success: true,
                        baseline: baseline
                    });
                } else {
                    console.error('❌ Failed to establish memory baseline:', baseline.error);
                    resolve({
                        success: false,
                        error: baseline.error
                    });
                }
            }, 100);
        });
        
    } catch (error) {
        console.error('❌ Error resetting memory baseline:', error);
        return Promise.resolve({
            success: false,
            error: error.message
        });
    }
}

// Export memory monitoring functions to window
window.getWasmMemoryUsage = getWasmMemoryUsage;
window.startMemoryMonitoring = startMemoryMonitoring;
window.stopMemoryMonitoring = stopMemoryMonitoring;
window.detectMemoryLeaks = detectMemoryLeaks;
window.resetMemoryBaseline = resetMemoryBaseline;

console.log('📦 SQLite WASM Core JavaScript wrapper functions loaded successfully (with error handling + memory monitoring)');