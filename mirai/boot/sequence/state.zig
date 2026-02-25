//! Boot Sequence State

const constants = @import("constants/constants.zig");
const types = @import("types/types.zig");

const Phase = constants.Phase;
const BootInfo = types.BootInfo;

var current_phase: Phase = Phase.cpu;
var boot_info_ptr: ?*const BootInfo = null;
var boot_failed: bool = false;
var failure_phase: Phase = Phase.cpu;
var failure_message: []const u8 = "";

pub fn get_current_phase() Phase {
    return current_phase;
}

pub fn set_current_phase(phase: Phase) void {
    current_phase = phase;
}

pub fn advance_phase() void {
    const next = @intFromEnum(current_phase) + 1;
    if (next <= @intFromEnum(Phase.complete)) {
        current_phase = @enumFromInt(next);
    }
}

pub fn set_boot_info(info: *const BootInfo) void {
    boot_info_ptr = info;
}

pub fn get_boot_info() ?*const BootInfo {
    return boot_info_ptr;
}

pub fn set_failure(phase: Phase, message: []const u8) void {
    boot_failed = true;
    failure_phase = phase;
    failure_message = message;
}

pub fn has_failed() bool {
    return boot_failed;
}

pub fn get_failure_phase() Phase {
    return failure_phase;
}

pub fn get_failure_message() []const u8 {
    return failure_message;
}

pub fn is_complete() bool {
    return current_phase == Phase.complete;
}
