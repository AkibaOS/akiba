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

// Letter types
pub const Letter = struct {
    pub const NONE: u8 = 0;
    pub const NAVIGATE: u8 = 1;
};

pub fn attach(path: []const u8, flags: u32) Error!FileDescriptor {
    const result = sys.syscall(.attach, .{ @intFromPtr(path.ptr), flags });
    if (result == @as(u64, @bitCast(@as(i64, -1)))) {
        return Error.NotFound;
    }
    return @truncate(result);
}

pub fn seal(fd: FileDescriptor) void {
    _ = sys.syscall(.seal, .{fd});
}

pub fn view(fd: FileDescriptor, buffer: []u8) Error!usize {
    const result = sys.syscall(.view, .{ fd, @intFromPtr(buffer.ptr), buffer.len });
    if (result == @as(u64, @bitCast(@as(i64, -1)))) {
        return Error.ReadFailed;
    }
    return result;
}

pub fn viewstack(path: []const u8, entries: []StackEntry) !usize {
    const result = sys.syscall(.viewstack, .{
        @intFromPtr(path.ptr),
        path.len,
        @intFromPtr(entries.ptr),
        entries.len,
    });

    // Check for error (-1)
    if (result == @as(u64, @bitCast(@as(i64, -1)))) {
        return error.InvalidPath;
    }

    return @intCast(result);
}

pub fn mark(fd: FileDescriptor, data: []const u8, color: u32) Error!usize {
    const result = sys.syscall(.mark, .{ fd, @intFromPtr(data.ptr), data.len, color });
    if (result == @as(u64, @bitCast(@as(i64, -1)))) {
        return Error.WriteFailed;
    }
    return result;
}

pub fn getchar() !u8 {
    // Loop until character is available
    while (true) {
        const result = sys.syscall(.getkeychar, .{});
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

pub fn getlocation(buffer: []u8) ![]u8 {
    const result = sys.syscall(.getlocation, .{
        @intFromPtr(buffer.ptr),
        buffer.len,
    });

    if (result == @as(u64, @bitCast(@as(i64, -1)))) {
        return error.GetLocationFailed;
    }

    return buffer[0..@intCast(result)];
}

pub fn setlocation(path: []const u8) !void {
    const result = sys.syscall(.setlocation, .{
        @intFromPtr(path.ptr),
        path.len,
    });

    if (result == @as(u64, @bitCast(@as(i64, -1)))) {
        return error.InvalidPath;
    }
}

/// Send a letter to parent Kata
pub fn send_letter(letter_type: u8, data: []const u8) !void {
    const result = sys.syscall(.postman, .{
        @as(u64, 0), // MODE_SEND
        @as(u64, letter_type),
        @intFromPtr(data.ptr),
        data.len,
    });

    if (result == @as(u64, @bitCast(@as(i64, -1)))) {
        return error.SendFailed;
    }
}

/// Read letter from inbox
/// Returns letter type (0 = no letter), copies data to buffer
pub fn read_letter(buffer: []u8) !u8 {
    const result = sys.syscall(.postman, .{
        @as(u64, 1), // MODE_READ
        @intFromPtr(buffer.ptr),
        buffer.len,
    });

    if (result == @as(u64, @bitCast(@as(i64, -1)))) {
        return error.ReadFailed;
    }

    return @intCast(result);
}

pub fn wipe() void {
    _ = sys.syscall(.wipe, .{});
}

pub fn print(text: []const u8) Error!void {
    _ = try mark(stream, text, 0x00FFFFFF);
}

pub fn println(text: []const u8) Error!void {
    _ = try mark(stream, text, 0x00FFFFFF);
    _ = try mark(stream, "\n", 0x00FFFFFF);
}
