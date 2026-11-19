//! Position Independent Persona Invocation Probe

const std = @import("std");

const inputs = @import("tests").guest.constants.persona;
const strings = @import("tests").guest.strings.persona;
const types = @import("tests").guest.types.persona;
const Floating = @import("tests").guest.types.context.Floating;

extern var akiba_test_persona_end: u8;

pub fn image() []const u8 {
    const start = @intFromPtr(&akiba_test_persona_start);
    const finish = @intFromPtr(&akiba_test_persona_end);
    return @as([*]const u8, @ptrCast(&akiba_test_persona_start))[0 .. finish - start];
}

fn offsets(comptime prefix: []const u8, comptime value: type) []const u8 {
    comptime var result: []const u8 = strings.EMPTY;
    inline for (@typeInfo(value).@"struct".fields) |field| {
        result = result ++ std.fmt.comptimePrint(strings.OFFSET, .{ prefix, field.name, @offsetOf(value, field.name) });
    }
    return result;
}

fn registers(comptime seed: bool) []const u8 {
    comptime var result: []const u8 = strings.EMPTY;
    inline for (@typeInfo(types.Registers).@"struct".fields) |field| {
        var buffer: [field.name.len]u8 = undefined;
        const lower = std.ascii.lowerString(&buffer, field.name);
        result = result ++ if (seed)
            std.fmt.comptimePrint(strings.SEED_REGISTER, .{ field.name, lower })
        else
            std.fmt.comptimePrint(strings.SAVE_REGISTER, .{ lower, field.name });
    }
    return result;
}

fn assembly() []const u8 {
    @setEvalBranchQuota(100000);
    return offsets(strings.FRAME_PREFIX, types.Frame) ++
        offsets(strings.SNAPSHOT_PREFIX, types.Snapshot) ++
        offsets(strings.REGISTER_PREFIX, types.Registers) ++
        offsets(strings.FLOAT_PREFIX, Floating) ++
        std.fmt.comptimePrint(strings.VALUES, .{ inputs.DATA_ADDRESS, inputs.QUERY_SERVICE, inputs.YIELD_SERVICE }) ++
        strings.SEED_BEGIN ++ registers(true) ++ strings.SEED_END ++
        strings.SAVE_BEGIN ++ registers(false) ++ strings.SAVE_END ++ strings.BODY;
}

export fn akiba_test_persona_start() callconv(.naked) void {
    asm volatile (assembly() ::: .{ .memory = true });
}
