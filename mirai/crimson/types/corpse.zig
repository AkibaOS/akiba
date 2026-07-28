//! Corpse Structure

const constants = @import("mirai").crimson.constants;
const context = @import("mirai").crimson.types.context;
const flavor = @import("mirai").crimson.types.flavor;
const identity = @import("mirai").crimson.types.identity;
const kind = @import("mirai").crimson.types.kind;

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
