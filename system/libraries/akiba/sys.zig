//! Low-level invocation interface

pub const Invocation = enum(u64) {
    exit = 0x01,
    attach = 0x02,
    seal = 0x03,
    view = 0x04,
    mark = 0x05,
    spawn = 0x06,
    wait = 0x07,
    yield = 0x08,
    getkeychar = 0x09,
    viewstack = 0x0A,
    getlocation = 0x0B,
    setlocation = 0x0C,
    postman = 0x0D,
};

/// Perform a system invocation with variable arguments
/// Uses comptime to handle different argument counts
pub inline fn syscall(invocation: Invocation, args: anytype) u64 {
    const Args = @TypeOf(args);
    const fields = @typeInfo(Args).@"struct".fields;

    // Always set all 6 argument registers, defaulting unused ones to 0
    const arg0: u64 = if (fields.len > 0) @as(u64, @bitCast(toU64(args[0]))) else 0;
    const arg1: u64 = if (fields.len > 1) @as(u64, @bitCast(toU64(args[1]))) else 0;
    const arg2: u64 = if (fields.len > 2) @as(u64, @bitCast(toU64(args[2]))) else 0;
    const arg3: u64 = if (fields.len > 3) @as(u64, @bitCast(toU64(args[3]))) else 0;
    const arg4: u64 = if (fields.len > 4) @as(u64, @bitCast(toU64(args[4]))) else 0;
    const arg5: u64 = if (fields.len > 5) @as(u64, @bitCast(toU64(args[5]))) else 0;

    return asm volatile ("syscall"
        : [ret] "={rax}" (-> u64),
        : [number] "{rax}" (@intFromEnum(invocation)),
          [arg0] "{rdi}" (arg0),
          [arg1] "{rsi}" (arg1),
          [arg2] "{rdx}" (arg2),
          [arg3] "{r10}" (arg3),
          [arg4] "{r8}" (arg4),
          [arg5] "{r9}" (arg5),
        : .{ .rcx = true, .r11 = true, .memory = true });
}

/// Convert various types to u64 for syscall arguments
inline fn toU64(value: anytype) u64 {
    const T = @TypeOf(value);
    return switch (@typeInfo(T)) {
        .int, .comptime_int => @as(u64, @intCast(value)),
        .pointer => @intFromPtr(value),
        .@"enum" => @intFromEnum(value),
        else => @as(u64, @bitCast(value)),
    };
}
