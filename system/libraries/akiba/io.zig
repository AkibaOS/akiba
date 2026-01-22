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

pub fn mark(fd: FileDescriptor, data: []const u8) Error!usize {
    const result = sys.syscall3(.mark, fd, @intFromPtr(data.ptr), data.len);
    if (result == @as(u64, @bitCast(@as(i64, -1)))) {
        return Error.WriteFailed;
    }
    return result;
}

pub fn getchar() !u8 {
    // Loop until character is available, yielding CPU
    while (true) {
        const result = sys.syscall0(.getkeychar);
        if (result != @as(u64, @bitCast(@as(i64, -2)))) {
            if (result != @as(u64, @bitCast(@as(i64, -1)))) {
                return @truncate(result);
            }
            return error.ReadFailed;
        }
        // No input yet (-2 = EAGAIN), yield and try again
        kata.yield();
    }
}

pub fn print(text: []const u8) Error!void {
    _ = try mark(stream, text);
}

pub fn println(text: []const u8) Error!void {
    _ = try mark(stream, text);
    _ = try mark(stream, "\n");
}
