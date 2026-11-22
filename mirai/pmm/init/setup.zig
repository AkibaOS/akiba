//! Cold Physical Memory Manager Setup

const address = @import("common").memory;
const emission = @import("mirai").pmm.init.emission;
const guard = @import("asm").interrupts.guard;
const state = @import("mirai").pmm.state;
const types = @import("mirai").pmm.types;

pub fn initializeFromMemoryMap(
    memory_map: []const types.region.MemoryRegion,
    physical_limit: u64,
    exclusions: []const types.storage.layout.Range,
) bool {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    if (state.isInitialized()) return false;
    const initialized = emission.build(memory_map, physical_limit, exclusions, {}, directFrame) orelse return false;
    state.getState().* = initialized;
    return true;
}

fn directFrame(_: void, physical: u64) *types.storage.layout.Frame {
    return @ptrFromInt(address.translate.physToVirt(physical));
}
