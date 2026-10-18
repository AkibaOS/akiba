//! Kernel Stack Allocator State

const common = @import("common");
const cpu = @import("asm").cpu;
const limits = @import("mirai").memory.constants.stack.limits;
const types = @import("mirai").memory.types.stack;

const sizes = common.constants.memory.sizes;

var global_state: types.state.State = .{};

pub fn getState() *types.state.State {
    return &global_state;
}

pub fn canCommitBoot() bool {
    return global_state.NextSlot == 0 and global_state.FreeList == null and
        global_state.FreeCount == 0 and global_state.TotalCount == 0 and
        global_state.BootStackBase == 0;
}

pub fn commitBoot(base: u64, top: u64) bool {
    const expected_base = limits.AREA_BASE + limits.GUARD_PAGES * sizes.PAGE_SIZE;
    if (!canCommitBoot() or base != expected_base or top != base + limits.STACK_SIZE) return false;
    global_state.BootStackBase = base;
    global_state.BootStackTop = top;
    global_state.NextSlot = 1;
    global_state.TotalCount = 1;
    global_state.HighWatermark = 1;
    return true;
}

pub fn isPinned(base: u64) bool {
    if (base == global_state.BootStackBase) return true;
    const stack_pointer = cpu.state.readStackPointer();
    return base <= stack_pointer and stack_pointer - base < limits.STACK_SIZE;
}

pub fn isAllocatedBase(base: u64) bool {
    const first_base = limits.AREA_BASE + limits.GUARD_PAGES * sizes.PAGE_SIZE;
    if (base < first_base) return false;
    const offset = base - first_base;
    return offset % limits.SLOT_SIZE == 0 and offset / limits.SLOT_SIZE < global_state.NextSlot;
}
