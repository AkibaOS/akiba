//! Guarded Physical Memory Manager State And Queries

const common = @import("common");
const guard = @import("asm").interrupts.guard;
const storage = @import("mirai").pmm.storage;
const types = @import("mirai").pmm.types;

const sizes = common.constants.memory.sizes;
const State = types.state.State;

var global_state: State = .{};

pub fn getState() *State {
    return &global_state;
}

pub fn isInitialized() bool {
    const flags = guard.acquire();
    defer guard.release(flags);
    return global_state.Index.Root != null;
}

pub fn getStatistics() types.statistics.Statistics {
    const flags = guard.acquire();
    defer guard.release(flags);
    return global_state.Statistics;
}

pub fn getRole(physical: u64) types.storage.Role {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (physical & sizes.PAGE_MASK != 0) return .Hole;
    return storage.access.read(global_state.Index, physical / sizes.PAGE_SIZE);
}

pub fn isAllocated(physical: u64) bool {
    return getRole(physical) == .Allocated;
}

pub fn firstFreeAtOrAfter(physical: u64) ?u64 {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (physical & sizes.PAGE_MASK != 0) return null;
    const index = global_state.Index;
    const page = storage.search.find(index, physical / sizes.PAGE_SIZE, index.PhysicalPages, 1, 1) orelse return null;
    return page * sizes.PAGE_SIZE;
}
