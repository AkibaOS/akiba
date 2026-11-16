//! Disposable Guarded Stack Regressions

const common = @import("common");
const guard = @import("asm").interrupts.guard;
const kagami = @import("mirai").kagami;
const labels = @import("tests").strings.memory;
const memory = @import("mirai").memory;
const pmm = @import("mirai").pmm;
const verify = @import("tests").verify;

const limits = memory.constants.stack.limits;
const sizes = common.constants.memory.sizes;
const KernelStack = memory.types.stack.kernel.KernelStack;

pub fn run() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const state = memory.stack.state.getState();
    const boot_base = state.BootStackBase;
    const boot_top = state.BootStackTop;
    const kernel = kagami.state.getKernelKagami();
    var stacks = [_]?KernelStack{null} ** (limits.CACHE_TARGET + 1);
    var bases: [stacks.len]u64 = undefined;
    defer {
        for (stacks) |stack| {
            if (stack) |allocated| memory.stack.free.free(allocated);
        }
    }
    for (&stacks, &bases, 0..) |*stack, *base, index| {
        const allocated = try memory.stack.allocate.allocate();
        stack.* = allocated;
        base.* = allocated.Base;
        verify.require(allocated.Top == allocated.Base + limits.STACK_SIZE and
            (allocated.Base & sizes.PAGE_MASK) == 0 and
            (allocated.Base - limits.AREA_BASE) % limits.SLOT_SIZE == limits.GUARD_PAGES * sizes.PAGE_SIZE and
            !kagami.extract.isMapped(kernel, allocated.Base - sizes.PAGE_SIZE) and
            !kagami.extract.isMapped(kernel, allocated.Top), labels.STACK_GEOMETRY);
        for (bases[0..index]) |other| verify.require(other != allocated.Base, labels.STACK_SEPARATION);
        var offset: u64 = 0;
        while (offset < limits.STACK_SIZE) : (offset += sizes.PAGE_SIZE) {
            const mapping = kagami.extract.lookup(kernel, allocated.Base + offset).?;
            verify.require(mapping.PageSize == sizes.PAGE_SIZE and mapping.Writable and !mapping.UserAccessible and
                !mapping.Executable and mapping.Entry.isWired(), labels.STACK_PERMISSIONS);
        }
    }
    const first = stacks[0].?;
    const free_before_pin = state.FreeCount;
    verify.require(memory.stack.state.retain(first.Base) and memory.stack.state.isPinned(first.Base) and
        !memory.stack.state.retain(first.Base), labels.STACK_PIN);
    memory.stack.free.free(first);
    verify.require(memory.stack.state.isAllocatedBase(first.Base) and state.FreeCount == free_before_pin, labels.STACK_PIN);
    verify.require(memory.stack.state.release(first.Base) and !memory.stack.state.release(first.Base) and
        !memory.stack.state.isPinned(first.Base), labels.STACK_RELEASE);
    memory.stack.free.free(.{ .Base = first.Base, .Top = first.Top - sizes.PAGE_SIZE });
    verify.require(memory.stack.state.isAllocatedBase(first.Base) and state.FreeCount == free_before_pin, labels.STACK_INVALID);
    memory.stack.free.free(first);
    stacks[0] = null;
    memory.stack.free.free(first);
    verify.require(!memory.stack.state.isAllocatedBase(first.Base) and state.FreeCount == free_before_pin + 1 and
        !memory.stack.state.retain(first.Base), labels.STACK_CACHE);
    const reused = try memory.stack.allocate.allocate();
    stacks[0] = reused;
    verify.require(reused.Base == first.Base and reused.Top == first.Top and
        memory.stack.state.isAllocatedBase(reused.Base) and state.FreeCount == free_before_pin, labels.STACK_CACHE);
    for (&stacks) |*stack| {
        memory.stack.free.free(stack.*.?);
        stack.* = null;
    }
    const free_before_collect = state.FreeCount;
    const total_before_collect = state.TotalCount;
    const tables_before_collect = kernel.TablePages;
    const pages_before_collect = pmm.state.getStatistics();
    const released_stacks = free_before_collect - limits.CACHE_TARGET;
    const released_pages = memory.stack.collect.collect();
    const pages_after_collect = pmm.state.getStatistics();
    verify.require(released_pages == released_stacks * limits.STACK_PAGES and state.FreeCount == limits.CACHE_TARGET and
        state.TotalCount + released_stacks == total_before_collect and state.HighWatermark >= state.TotalCount and
        kernel.TablePages <= tables_before_collect and
        pages_after_collect.FreePages == pages_before_collect.FreePages + released_pages + tables_before_collect - kernel.TablePages and
        pages_after_collect.UsedPages + released_pages + tables_before_collect - kernel.TablePages == pages_before_collect.UsedPages and
        memory.stack.collect.collect() == 0, labels.STACK_COLLECT);
    var index: usize = 0;
    while (index < @min(released_stacks, bases.len)) : (index += 1) {
        const base = bases[bases.len - index - 1];
        var offset: u64 = 0;
        while (offset < limits.STACK_SIZE) : (offset += sizes.PAGE_SIZE) {
            verify.require(!kagami.extract.isMapped(kernel, base + offset), labels.STACK_PRUNE);
        }
    }
    const cached = state.FreeList.?;
    const cached_base = @intFromPtr(cached);
    verify.require(kagami.extract.isMapped(kernel, cached_base) and
        !memory.stack.state.isAllocatedBase(cached_base) and state.BootStackBase == boot_base and
        state.BootStackTop == boot_top and cached_base != boot_base, labels.STACK_RETAINED);
}
