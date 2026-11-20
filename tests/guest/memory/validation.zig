//! Kernel Heap Geometry Release And Failure Validation

const std = @import("std");

const budget = @import("tests").guest.support.allocation;
const common = @import("common");
const cpu = @import("asm").cpu;
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").guest.constants.heap;
const kagami = @import("mirai").kagami;
const labels = @import("tests").guest.strings.heap;
const memory = @import("mirai").memory;
const pmm = @import("mirai").pmm;
const values = @import("tests").guest.constants.memory.fixtures;
const verify = @import("tests").guest.support.verify;

const layout = common.constants.memory.layout;
const sizes = common.constants.memory.sizes;
const heap = memory.heap;

pub fn run() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    defer budget.clear();
    const before = pmm.state.getStatistics();
    verify.require(reject(0, sizes.PAGE_SIZE, error.SizeTooLarge) and
        reject(std.math.maxInt(usize), sizes.PAGE_SIZE, error.SizeTooLarge) and
        reject(inputs.LARGE_BYTES, 0, error.InvalidAlignment) and
        reject(inputs.LARGE_BYTES, sizes.PAGE_SIZE + 1, error.InvalidAlignment) and
        std.meta.eql(before, pmm.state.getStatistics()), labels.GEOMETRY);
    const seed = try heap.allocate.allocate(sizes.PAGE_SIZE, sizes.PAGE_SIZE);
    var live_seed = true;
    defer if (live_seed) memory.kalloc.kfree(seed, sizes.PAGE_SIZE);
    const aligned = try heap.allocate.allocate(inputs.LARGE_BYTES, inputs.ALIGNMENT);
    var live_aligned = true;
    defer if (live_aligned) memory.kalloc.kfree(aligned, inputs.LARGE_BYTES);
    const bytes: [*]u8 = @ptrCast(aligned);
    @memset(bytes[0..inputs.LARGE_BYTES], values.DIRTY_BYTE);
    verify.require(@intFromPtr(aligned) % inputs.ALIGNMENT == 0 and @intFromPtr(aligned) > @intFromPtr(seed) and
        kagami.extract.isMapped(kagami.state.getKernelKagami(), @intFromPtr(seed)), labels.ALIGNMENT);
    const snapshot = pmm.state.getStatistics();
    const interior: *anyopaque = @ptrFromInt(@intFromPtr(aligned) + 1);
    const foreign: *anyopaque = @ptrFromInt(layout.MMIO_BASE - sizes.PAGE_SIZE);
    memory.kalloc.kfree(aligned, inputs.TINY_BYTES);
    verify.require(!heap.free.free(interior, inputs.LARGE_BYTES) and !heap.free.free(foreign, inputs.LARGE_BYTES) and
        !heap.free.free(aligned, inputs.LARGE_BYTES + 1) and !heap.free.free(aligned, 0) and
        std.meta.eql(snapshot, pmm.state.getStatistics()) and std.mem.allEqual(u8, bytes[0..inputs.LARGE_BYTES], values.DIRTY_BYTE), labels.INVALID);
    try preflight(aligned);
    budget.arm(0);
    verify.require(heap.free.free(aligned, inputs.LARGE_BYTES) and !heap.free.free(aligned, inputs.LARGE_BYTES), labels.INVALID);
    live_aligned = false;
    verify.require(heap.free.free(seed, sizes.PAGE_SIZE), labels.RELEASE);
    live_seed = false;
    budget.clear();
    const tiny = try heap.allocate.allocate(inputs.TINY_BYTES, sizes.PAGE_SIZE);
    memory.kalloc.kfree(tiny, inputs.TINY_BYTES);
    verify.require(heap.state.find(@intFromPtr(tiny)) == null and std.meta.eql(before, pmm.state.getStatistics()), labels.RELEASE);
    try pressure();
}

fn reject(size: usize, alignment: usize, expected: anyerror) bool {
    if (heap.allocate.allocate(size, alignment)) |unexpected| {
        _ = heap.free.free(unexpected, size);
        return false;
    } else |failure| return failure == expected;
}

fn preflight(pointer: *anyopaque) !void {
    const kernel = kagami.state.getKernelKagami();
    const leaf = kagami.tables.walk.walkToOwnedEntry(kernel.PML4Physical, @intFromPtr(pointer)).?;
    const original = leaf.*;
    const replacement = try pmm.allocate.single.allocatePageZeroed();
    defer pmm.free.single.freePage(replacement);
    const before = pmm.state.getStatistics();
    leaf.setPhysicalAddress(replacement);
    cpu.control.flushAllTLB();
    const refused = !heap.free.free(pointer, inputs.LARGE_BYTES);
    const preserved = heap.state.find(@intFromPtr(pointer)) != null and std.meta.eql(before, pmm.state.getStatistics());
    leaf.* = original;
    cpu.control.flushAllTLB();
    verify.require(refused and preserved and kagami.extract.isMapped(kernel, @intFromPtr(pointer) + sizes.PAGE_SIZE), labels.PREFLIGHT);
}

fn pressure() !void {
    const before = pmm.state.getStatistics();
    const search = pmm.state.getState().SearchStart;
    const kernel = kagami.state.getKernelKagami();
    const tables = kernel.TablePages;
    var failures: usize = 0;
    var accepted: ?*anyopaque = null;
    while (true) : (failures += 1) {
        budget.arm(failures);
        if (heap.allocate.allocate(inputs.SECOND_BYTES, sizes.PAGE_SIZE)) |pointer| {
            accepted = pointer;
            budget.clear();
            break;
        } else |failure| {
            budget.clear();
            verify.require(failure == error.OutOfMemory and kernel.TablePages == tables and
                heap.state.find(layout.KERNEL_HEAP) == null and !kagami.extract.isMapped(kernel, layout.KERNEL_HEAP) and
                search == pmm.state.getState().SearchStart and std.meta.eql(before, pmm.state.getStatistics()), labels.FAILURE);
        }
    }
    verify.require(failures != 0 and @intFromPtr(accepted.?) == layout.KERNEL_HEAP, labels.RECOVERY);
    budget.arm(0);
    verify.require(heap.free.free(accepted.?, inputs.SECOND_BYTES), labels.RELEASE);
    budget.clear();
    verify.require(std.meta.eql(before, pmm.state.getStatistics()), labels.RELEASE);
}
