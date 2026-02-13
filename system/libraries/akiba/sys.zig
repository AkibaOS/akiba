//! Low-level syscall interface

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
};

/// System call interface - handles variable parameter counts
/// Always sets all 6 parameter registers (unused ones are zero)
pub fn syscall(inv: Invocation, params: anytype) u64 {
    const params_type = @typeInfo(@TypeOf(params));

    if (params_type != .@"struct") {
        @compileError("syscall params must be a tuple");
    }

    const fields = params_type.@"struct".fields;

    // Convert parameters to u64 at comptime
    var param_values: [6]u64 = .{0} ** 6;

    inline for (fields, 0..) |field, i| {
        if (i >= 6) @compileError("Maximum 6 syscall parameters");

        param_values[i] = switch (@typeInfo(field.type)) {
            .int, .comptime_int => @intCast(@field(params, field.name)),
            .pointer => @intFromPtr(@field(params, field.name)),
            .@"enum" => @intFromEnum(@field(params, field.name)),
            else => @compileError("Unsupported syscall parameter type"),
        };
    }

    // Always set all 6 registers
    var result: u64 = undefined;
    asm volatile ("syscall"
        : [ret] "={rax}" (result),
        : [num] "{rax}" (@intFromEnum(inv)),
          [p0] "{rdi}" (param_values[0]),
          [p1] "{rsi}" (param_values[1]),
          [p2] "{rdx}" (param_values[2]),
          [p3] "{r10}" (param_values[3]),
          [p4] "{r8}" (param_values[4]),
          [p5] "{r9}" (param_values[5]),
        : .{ .rcx = true, .r11 = true, .memory = true });
    return result;
}

/// Spawn a new process with arguments
/// argv should be an array of null-terminated string pointers
pub fn spawn_with_args(path: []const u8, argv: []const [*:0]const u8) u64 {
    return syscall(.spawn, .{
        @intFromPtr(path.ptr),
        path.len,
        @intFromPtr(argv.ptr),
        argv.len,
    });
}
