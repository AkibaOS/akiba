//! Kernel Stack Allocator State

const bits = @import("utils").bits;
const common = @import("common");
const cpu = @import("asm").cpu;
const guard = @import("asm").interrupts.guard;
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
    bits.operations.setBit(&global_state.AllocatedSlots, 0);
    global_state.BootStackBase = base;
    global_state.BootStackTop = top;
    global_state.NextSlot = 1;
    global_state.TotalCount = 1;
    global_state.HighWatermark = 1;
    return true;
}

pub fn retain(base: u64) bool {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    const index = slotIndex(base) orelse return false;
    if (!bits.operations.testBit(&global_state.AllocatedSlots, index) or
        bits.operations.testBit(&global_state.RetainedSlots, index) or
        base == global_state.BootStackBase) return false;
    bits.operations.setBit(&global_state.RetainedSlots, index);
    return true;
}

pub fn release(base: u64) bool {
    const previous_flags = guard.acquire();
    defer guard.release(previous_flags);
    const index = slotIndex(base) orelse return false;
    if (!bits.operations.testBit(&global_state.AllocatedSlots, index) or
        !bits.operations.testBit(&global_state.RetainedSlots, index) or isLive(base)) return false;
    bits.operations.clearBit(&global_state.RetainedSlots, index);
    return true;
}

pub fn isPinned(base: u64) bool {
    if (slotIndex(base)) |index| {
        if (bits.operations.testBit(&global_state.RetainedSlots, index)) return true;
    }
    return isLive(base);
}

pub fn isAllocatedBase(base: u64) bool {
    const index = slotIndex(base) orelse return false;
    return bits.operations.testBit(&global_state.AllocatedSlots, index);
}

fn isLive(base: u64) bool {
    if (base == global_state.BootStackBase) return true;
    const stack_pointer = cpu.state.readStackPointer();
    return base <= stack_pointer and stack_pointer - base < limits.STACK_SIZE;
}

fn slotIndex(base: u64) ?u64 {
    const first_base = limits.AREA_BASE + limits.GUARD_PAGES * sizes.PAGE_SIZE;
    if (base < first_base) return null;
    const offset = base - first_base;
    const index = offset / limits.SLOT_SIZE;
    if (offset % limits.SLOT_SIZE != 0 or index >= limits.MAX_SLOTS or index >= global_state.NextSlot) return null;
    return index;
}
