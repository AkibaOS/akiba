//! Corpse Structure

const Context = @import("context.zig").Context;
const FloatState = @import("flavor.zig").FloatState;
const DebugState = @import("flavor.zig").DebugState;
const Identity = @import("identity.zig").Identity;
const constants = @import("../constants/constants.zig");
const ExceptionType = constants.ExceptionType;

pub const Corpse = struct {
    kata_id: u64, thread_id: u64, exception_type: ExceptionType, exception_code: u64, exception_subcode: u64,
    fault_address: u64, identity: Identity, context: Context, float_state: FloatState, debug_state: DebugState,
    stack_snapshot: [4096]u8, stack_snapshot_size: u64, memory_snapshot: [4096]u8,
    memory_snapshot_address: u64, memory_snapshot_size: u64, timestamp: u64, valid: bool,
    pub fn clear(self: *Corpse) void { self.valid = false; self.stack_snapshot_size = 0; self.memory_snapshot_size = 0; }
    pub fn is_valid(self: *const Corpse) bool { return self.valid; }
    pub fn mark_valid(self: *Corpse) void { self.valid = true; }
};
