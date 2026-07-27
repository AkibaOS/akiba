//! Corpse Structure

const constants = @import("../constants/constants.zig");
const context = @import("context.zig");
const flavor = @import("flavor.zig");
const identity = @import("identity.zig");
const kind = @import("kind.zig");

const limits = constants.limits;

pub const Corpse = struct {
    KataId: u64,
    ThreadId: u64,
    ExceptionType: kind.ExceptionType,
    ExceptionCode: u64,
    ExceptionSubcode: u64,
    FaultAddress: u64,
    Identity: identity.Identity,
    Context: context.Context,
    FloatState: flavor.FloatState,
    DebugState: flavor.DebugState,
    StackSnapshot: [limits.SNAPSHOT_SIZE]u8,
    StackSnapshotSize: u64,
    MemorySnapshot: [limits.SNAPSHOT_SIZE]u8,
    MemorySnapshotAddress: u64,
    MemorySnapshotSize: u64,
    Timestamp: u64,
    Valid: bool,

    pub fn clear(self: *Corpse) void {
        self.Valid = false;
        self.StackSnapshotSize = 0;
        self.MemorySnapshotSize = 0;
    }

    pub fn isValid(self: *const Corpse) bool {
        return self.Valid;
    }

    pub fn markValid(self: *Corpse) void {
        self.Valid = true;
    }
};
