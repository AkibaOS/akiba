//! Kernel Stack Reservation Failure And Cached Mapping Refusal

const std = @import("std");

const budget = @import("tests").guest.support.allocation;
const common = @import("common");
const cpu = @import("asm").cpu;
const guard = @import("asm").interrupts.guard;
const kagami = @import("mirai").kagami;
const labels = @import("tests").strings.stack;
const memory = @import("mirai").memory;
const pmm = @import("mirai").pmm;
const verify = @import("tests").verify;

const limits = memory.constants.stack.limits;
const sizes = common.constants.memory.sizes;
const KernelStack = memory.types.stack.kernel.KernelStack;

pub fn run() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    defer budget.clear();
    try pressure();
    try refusal();
}

fn pressure() !void {
    _ = memory.stack.collect.collect();
    const before = pmm.state.getStatistics();
    const original = memory.stack.state.getState().TotalCount;
    var held = [_]?KernelStack{null} ** limits.CACHE_TARGET;
    defer for (held) |stack| {
        if (stack) |live| memory.stack.free.free(live);
    };
    for (&held) |*stack| stack.* = try memory.stack.allocate.allocate();
    const probe = try memory.stack.state.reserve();
    const expected = probe.Stack;
    memory.stack.state.discard(probe);
    const snapshot = pmm.state.getStatistics();
    const search = pmm.state.getState().SearchStart;
    const total = memory.stack.state.getState().TotalCount;
    const tables = kagami.state.getKernelKagami().TablePages;
    var failures: usize = 0;
    var accepted: ?KernelStack = null;
    while (true) : (failures += 1) {
        budget.arm(failures);
        if (memory.stack.allocate.allocate()) |stack| {
            accepted = stack;
            budget.clear();
            break;
        } else |failure| {
            budget.clear();
            var absent = true;
            for (0..limits.STACK_PAGES) |index|
                absent = absent and !kagami.extract.isMapped(kagami.state.getKernelKagami(), expected.Base + index * sizes.PAGE_SIZE);
            verify.require(failure == error.OutOfMemory and absent and memory.stack.state.find(expected.Base) == null and
                memory.stack.state.getState().FreeCount == 0 and memory.stack.state.getState().TotalCount == total and
                kagami.state.getKernelKagami().TablePages == tables and search == pmm.state.getState().SearchStart and
                std.meta.eql(snapshot, pmm.state.getStatistics()), labels.FAILURE);
        }
    }
    verify.require(failures != 0 and accepted.?.Base == expected.Base and
        memory.stack.mapping.validate(memory.stack.state.find(expected.Base).?), labels.RECOVERY);
    budget.arm(0);
    memory.stack.free.free(accepted.?);
    for (&held) |*stack| {
        memory.stack.free.free(stack.*.?);
        stack.* = null;
    }
    _ = memory.stack.collect.collect();
    budget.clear();
    verify.require(memory.stack.state.getState().TotalCount == original and
        std.meta.eql(before, pmm.state.getStatistics()), labels.RESTORED);
}

fn refusal() !void {
    const before = pmm.state.getStatistics();
    const state = memory.stack.state.getState();
    const kernel = kagami.state.getKernelKagami();
    var stacks = [_]?KernelStack{null} ** (limits.CACHE_TARGET + 1);
    defer for (stacks) |stack| {
        if (stack) |live| memory.stack.free.free(live);
    };
    for (&stacks) |*stack| stack.* = try memory.stack.allocate.allocate();
    for (&stacks) |*stack| {
        memory.stack.free.free(stack.*.?);
        stack.* = null;
    }
    const cached = state.FreeList.?;
    const leaf = kagami.tables.walk.walkToOwnedEntry(kernel.PML4Physical, cached.Stack.Base).?;
    const original = leaf.*;
    const replacement = try pmm.allocate.single.allocatePageZeroed();
    const snapshot = pmm.state.getStatistics();
    const free = state.FreeCount;
    const total = state.TotalCount;
    leaf.setPhysicalAddress(replacement);
    cpu.control.flushAllTLB();
    budget.arm(0);
    const collected = memory.stack.collect.collect();
    var rejected = false;
    if (memory.stack.allocate.allocate()) |_| {
        verify.require(false, labels.ADMISSION);
    } else |failure| rejected = failure == error.InvalidSize;
    const preserved = state.FreeList == cached and state.FreeCount == free and state.TotalCount == total and
        std.meta.eql(snapshot, pmm.state.getStatistics());
    leaf.* = original;
    cpu.control.flushAllTLB();
    pmm.free.single.freePage(replacement);
    verify.require(collected == 0 and preserved, labels.PREFLIGHT);
    verify.require(rejected, labels.ADMISSION);
    _ = memory.stack.collect.collect();
    budget.clear();
    verify.require(std.meta.eql(before, pmm.state.getStatistics()), labels.RESTORED);
}
