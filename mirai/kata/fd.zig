//! File Descriptor Management for Kata
//! Tracks open files and device access for each running Kata

const afs = @import("../fs/afs/afs.zig");
const serial = @import("../drivers/serial/serial.zig");
const terminal = @import("../graphics/terminal/terminal.zig");

pub const FDType = enum {
    Regular, // Normal AFS file
    Device, // Device file in /system/devices/
    Closed, // Free slot
};

pub const DeviceType = enum {
    Source, // /system/devices/source (input stream)
    Stream, // /system/devices/stream (output stream)
    Trace, // /system/devices/trace (error stream)
    Void, // /system/devices/void (discards all writes)
    Chaos, // /system/devices/chaos (random data)
    Zero, // /system/devices/zero (infinite zeros)
    Console, // /system/devices/console (terminal)
};

pub const FileDescriptor = struct {
    fd_type: FDType = .Closed,

    // For regular files
    path: [256]u8 = undefined,
    path_len: usize = 0,
    position: u64 = 0, // Current read/write offset
    file_size: u64 = 0, // Total file size
    buffer: ?[]u8 = null, // File contents in kernel memory
    flags: u32 = 0, // Access mode flags
    dirty: bool = false, // True if buffer modified, needs writeback

    // For device files
    device_type: ?DeviceType = null,
};

// File access mode flags
pub const VIEW_ONLY: u32 = 0x01; // Read only
pub const MARK_ONLY: u32 = 0x02; // Write only
pub const BOTH: u32 = 0x03; // Read and write

// File open behavior flags
pub const CREATE: u32 = 0x0100; // Create if doesn't exist
pub const CLEAR: u32 = 0x0200; // Truncate to zero on open
pub const EXTEND: u32 = 0x0400; // Start at end of file

// Default flag combinations
pub const DEFAULT_VIEW: u32 = VIEW_ONLY;
pub const DEFAULT_MARK: u32 = MARK_ONLY | CREATE;
pub const DEFAULT_BOTH: u32 = BOTH | CREATE;
