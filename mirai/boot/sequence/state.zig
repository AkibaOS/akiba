//! Boot Sequence State

const types = @import("mirai").boot.types;

const BootInfo = types.sequence.info.BootInfo;
const Phase = types.sequence.phase.Phase;

var current_phase: Phase = Phase.CPU;
var boot_info: BootInfo = undefined;
var boot_info_ready: bool = false;
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
    boot_info = info.*;
    boot_info_ready = true;
}

pub fn getBootInfo() ?*const BootInfo {
    return if (boot_info_ready) &boot_info else null;
}

pub fn updateMemory(root_physical: u64, stack_top: u64, stack_size: u64) void {
    boot_info.PML4Physical = root_physical;
    boot_info.BootStackTop = stack_top;
    boot_info.BootStackSize = stack_size;
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
