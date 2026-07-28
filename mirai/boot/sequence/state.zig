//! Boot Sequence State

const types = @import("mirai").boot.types;

const BootInfo = types.sequence.info.BootInfo;
const Phase = types.sequence.phase.Phase;

var current_phase: Phase = Phase.CPU;
var boot_info_pointer: ?*const BootInfo = null;
var boot_failed: bool = false;
var failure_phase: Phase = Phase.CPU;
var failure_message: []const u8 = "";

pub fn getCurrentPhase() Phase {
    return current_phase;
}

pub fn setCurrentPhase(phase: Phase) void {
    current_phase = phase;
}

pub fn advancePhase() void {
    const next = @intFromEnum(current_phase) + 1;
    if (next <= @intFromEnum(Phase.Complete)) {
        current_phase = @enumFromInt(next);
    }
}

pub fn setBootInfo(info: *const BootInfo) void {
    boot_info_pointer = info;
}

pub fn getBootInfo() ?*const BootInfo {
    return boot_info_pointer;
}

pub fn setFailure(phase: Phase, message: []const u8) void {
    boot_failed = true;
    failure_phase = phase;
    failure_message = message;
}

pub fn hasFailed() bool {
    return boot_failed;
}

pub fn getFailurePhase() Phase {
    return failure_phase;
}

pub fn getFailureMessage() []const u8 {
    return failure_message;
}

pub fn isComplete() bool {
    return current_phase == Phase.Complete;
}
