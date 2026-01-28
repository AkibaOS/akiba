//! File I/O operations

const sys = @import("sys.zig");
const kata = @import("kata.zig");

pub const Error = error{
    NotFound,
    PermissionDenied,
    InvalidDescriptor,
    ReadFailed,
    WriteFailed,
};

pub const FileDescriptor = u32;

// Standard file descriptors
pub const source: FileDescriptor = 0; // Input stream
pub const stream: FileDescriptor = 1; // Output stream
pub const trace: FileDescriptor = 2; // Error/trace stream

// Open modes
pub const VIEW_ONLY: u32 = 0x01;
pub const MARK_ONLY: u32 = 0x02;
pub const BOTH: u32 = 0x03;
pub const CREATE: u32 = 0x0100;

pub fn attach(path: []const u8, flags: u32) Error!FileDescriptor {
    const result = sys.syscall2(.attach, @intFromPtr(path.ptr), flags);
    if (result == @as(u64, @bitCast(@as(i64, -1)))) {
        return Error.NotFound;
    }
    return @truncate(result);
}

pub fn seal(fd: FileDescriptor) void {
    _ = sys.syscall1(.seal, fd);
}

pub fn view(fd: FileDescriptor, buffer: []u8) Error!usize {
    const result = sys.syscall3(.view, fd, @intFromPtr(buffer.ptr), buffer.len);
    if (result == @as(u64, @bitCast(@as(i64, -1)))) {
        return Error.ReadFailed;
    }
    return result;
}

pub fn mark(fd: FileDescriptor, data: []const u8, color: u32) Error!usize {
    const result = sys.syscall4(.mark, fd, @intFromPtr(data.ptr), data.len, color);
    if (result == @as(u64, @bitCast(@as(i64, -1)))) {
        return Error.WriteFailed;
    }
    return result;
}

pub fn getchar() !u8 {
    // Loop until character is available
    while (true) {
        const result = sys.syscall0(.getkeychar);
        if (result != @as(u64, @bitCast(@as(i64, -2)))) {
            if (result != @as(u64, @bitCast(@as(i64, -1)))) {
                return @truncate(result);
            }
            return error.ReadFailed;
        }
        // No input yet (-2 = EAGAIN), yield to kernel
        kata.yield();
    }
}

pub fn print(text: []const u8) Error!void {
    _ = try mark(stream, text, 0x00FFFFFF);
}

pub fn println(text: []const u8) Error!void {
    _ = try mark(stream, text, 0x00FFFFFF);
    _ = try mark(stream, "\n", 0x00FFFFFF);
}

pub fn viewstack(path: []const u8, entries: []StackEntry) Error!usize {
    const result = sys.syscall4(.viewstack, @intFromPtr(path.ptr), path.len, @intFromPtr(entries.ptr), entries.len);
    if (result == @as(u64, @bitCast(@as(i64, -1)))) {
        return Error.ReadFailed;
    }
    return result;
}

pub const StackEntry = extern struct {
    identity: [64]u8,
    identity_len: u8,
    is_stack: bool,
    owner_name_len: u8,
    permission_type: u8,
    size: u32,
    modified_time: u64,
    owner_name: [64]u8,
};
