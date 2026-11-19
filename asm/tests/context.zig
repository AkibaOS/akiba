//! Native Context Regression Probe Boundaries

const std = @import("std");

const constants = @import("tests").guest.constants.context;
const strings = @import("tests").strings.context;
const types = @import("tests").guest.types.context;

pub fn cooperative(state: *types.Cooperative, callback: types.Yield, argument: ?*anyopaque) void {
    const boundary = @extern(types.CooperativeBoundary, .{ .name = strings.COOPERATIVE_SYMBOL });
    @call(.never_tail, boundary, .{ state, callback, argument });
}

pub fn preemptive(state: *types.Preemptive, peer: *const types.Preemptive) void {
    const boundary = @extern(types.PreemptiveBoundary, .{ .name = strings.PREEMPTIVE_SYMBOL });
    @call(.never_tail, boundary, .{ state, peer });
}

fn offsets(comptime prefix: []const u8, comptime value: type) []const u8 {
    comptime var declarations: []const u8 = strings.EMPTY;
    inline for (@typeInfo(value).@"struct".fields) |field| {
        declarations = declarations ++ std.fmt.comptimePrint(strings.OFFSET_FORMAT, .{ prefix, field.name, @offsetOf(value, field.name) });
    }
    return declarations;
}

fn layout() []const u8 {
    @setEvalBranchQuota(10000);
    return offsets(strings.COOPERATIVE_PREFIX, types.Cooperative) ++
        offsets(strings.PREEMPTIVE_PREFIX, types.Preemptive) ++
        offsets(strings.REGISTERS_PREFIX, types.Registers) ++
        offsets(strings.FLOATING_PREFIX, types.Floating) ++
        std.fmt.comptimePrint(strings.FRAME_FORMAT, .{
            constants.COOPERATIVE_FRAME_SIZE,
            constants.FPU_FRAME_SIZE,
            constants.ARMED_STAGE,
            constants.PROGRESSED_STAGE,
        });
}

export fn akiba_test_context_cooperative() callconv(.naked) void {
    asm volatile (layout() ++ strings.COOPERATIVE ::: .{ .memory = true });
}

export fn akiba_test_context_preemptive() callconv(.naked) void {
    asm volatile (layout() ++ strings.PREEMPTIVE ::: .{ .memory = true });
}
