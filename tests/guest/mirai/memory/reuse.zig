//! Collected Kernel Stack Virtual Extent Reuse

const std = @import("std");

const common = @import("common");
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").constants.stack;
const kagami = @import("mirai").kagami;
const labels = @import("tests").strings.stack;
const memory = @import("mirai").memory;
const pmm = @import("mirai").pmm;
const values = @import("tests").constants.memory;
const verify = @import("tests").verify;

const limits = memory.constants.stack.limits;
const sizes = common.constants.memory.sizes;
const KernelStack = memory.types.stack.kernel.KernelStack;

pub fn run() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    _ = memory.stack.collect.collect();
    const before = pmm.state.getStatistics();
    const total = memory.stack.state.getState().TotalCount;
    const kernel = kagami.state.getKernelKagami();
    var stacks = [_]?KernelStack{null} ** (limits.CACHE_TARGET + 1);
    defer for (stacks) |stack| {
        if (stack) |allocated| memory.stack.free.free(allocated);
    };
    for (0..inputs.REUSE_ROUNDS) |_| {
        for (&stacks) |*stack| stack.* = try memory.stack.allocate.allocate();
        const evicted = stacks[stacks.len - 1].?;
        const dirty: [*]u8 = @ptrFromInt(evicted.Base);
        @memset(dirty[0..limits.STACK_SIZE], values.DIRTY_BYTE);
        for (&stacks) |*stack| {
            memory.stack.free.free(stack.*.?);
            stack.* = null;
        }
        const released = memory.stack.collect.collect();
        verify.require(released >= limits.STACK_PAGES and !kagami.extract.isMapped(kernel, evicted.Base) and
            !kagami.extract.isMapped(kernel, evicted.Base - sizes.PAGE_SIZE) and !kagami.extract.isMapped(kernel, evicted.Top), labels.COLLECTED);
        for (&stacks) |*stack| stack.* = try memory.stack.allocate.allocate();
        const replacement = stacks[stacks.len - 1].?;
        verify.require(replacement.Base == evicted.Base and replacement.Top == evicted.Top, labels.REUSED);
        const zeroed: [*]const u8 = @ptrFromInt(replacement.Base);
        verify.require(std.mem.allEqual(u8, zeroed[0..limits.STACK_SIZE], 0) and
            !kagami.extract.isMapped(kernel, replacement.Base - sizes.PAGE_SIZE) and !kagami.extract.isMapped(kernel, replacement.Top), labels.ZEROED);
        for (&stacks) |*stack| {
            memory.stack.free.free(stack.*.?);
            stack.* = null;
        }
        _ = memory.stack.collect.collect();
    }
    verify.require(memory.stack.state.getState().TotalCount == total and
        std.meta.eql(before, pmm.state.getStatistics()), labels.RESTORED);
}
