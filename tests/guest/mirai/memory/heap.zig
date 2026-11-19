//! Large Kernel Allocations With Fragmented Physical Backing

const std = @import("std");

const common = @import("common");
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").guest.constants.heap;
const kagami = @import("mirai").kagami;
const labels = @import("tests").guest.strings.heap;
const memory = @import("mirai").memory;
const pmm = @import("mirai").pmm;
const values = @import("tests").guest.constants.memory;
const verify = @import("tests").guest.support.verify;

const layout = common.constants.memory.layout;
const sizes = common.constants.memory.sizes;

pub fn run() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const warm = try memory.kalloc.kallocZeroed(inputs.LARGE_BYTES);
    memory.kalloc.kfree(warm, inputs.LARGE_BYTES);
    const before = pmm.state.getStatistics();
    const first = try memory.kalloc.kallocZeroed(inputs.LARGE_BYTES);
    var live_first = true;
    defer if (live_first) memory.kalloc.kfree(first, inputs.LARGE_BYTES);
    const second = try memory.kalloc.kallocZeroed(inputs.SECOND_BYTES);
    var live_second = true;
    defer if (live_second) memory.kalloc.kfree(second, inputs.SECOND_BYTES);
    const first_bytes: [*]u8 = @ptrCast(first);
    const second_bytes: [*]u8 = @ptrCast(second);
    var valid = @intFromPtr(first) >= layout.KERNEL_HEAP and @intFromPtr(second) >= layout.KERNEL_HEAP and
        @intFromPtr(first) < layout.MMIO_BASE and @intFromPtr(second) < layout.MMIO_BASE and
        std.mem.allEqual(u8, first_bytes[0..inputs.LARGE_BYTES], 0) and
        std.mem.allEqual(u8, second_bytes[0..inputs.SECOND_BYTES], 0);
    for (0..(inputs.SECOND_BYTES + sizes.PAGE_MASK) / sizes.PAGE_SIZE) |index| {
        const mapped = kagami.extract.lookup(kagami.state.getKernelKagami(), @intFromPtr(second) + index * sizes.PAGE_SIZE).?;
        valid = valid and mapped.Writable and !mapped.Executable and !mapped.UserAccessible;
    }
    @memset(first_bytes[0..inputs.LARGE_BYTES], values.DIRTY_BYTE);
    @memset(second_bytes[0..inputs.SECOND_BYTES], values.UNCHANGED_BYTE);
    verify.require(valid and std.mem.allEqual(u8, first_bytes[0..inputs.LARGE_BYTES], values.DIRTY_BYTE) and
        std.mem.allEqual(u8, second_bytes[0..inputs.SECOND_BYTES], values.UNCHANGED_BYTE), labels.LARGE);
    memory.kalloc.kfree(first, inputs.LARGE_BYTES);
    live_first = false;
    memory.kalloc.kfree(second, inputs.SECOND_BYTES);
    live_second = false;
    verify.require(std.meta.eql(before, pmm.state.getStatistics()), labels.RELEASE);
    try fragmented();
}

fn fragmented() !void {
    const before = pmm.state.getStatistics();
    const search = pmm.state.getState().SearchStart;
    defer pmm.state.getState().SearchStart = search;
    var frames = [_]u64{0} ** inputs.FRAGMENT_FRAMES;
    var held = [_]bool{false} ** inputs.FRAGMENT_FRAMES;
    defer for (frames, held) |physical, live| {
        if (live) pmm.free.single.freePage(physical);
    };
    for (&frames, &held) |*physical, *live| {
        physical.* = try pmm.allocate.single.allocatePageZeroed();
        live.* = true;
    }
    for (frames, &held, 0..) |physical, *live, index| {
        if (index % 2 != 0) continue;
        pmm.free.single.freePage(physical);
        live.* = false;
    }
    pmm.state.getState().SearchStart = frames[0] / sizes.PAGE_SIZE;
    const pointer = try memory.kalloc.kallocZeroed(inputs.SECOND_BYTES);
    var live_pointer = true;
    defer if (live_pointer) memory.kalloc.kfree(pointer, inputs.SECOND_BYTES);
    var previous: ?u64 = null;
    var scattered = false;
    for (0..(inputs.SECOND_BYTES + sizes.PAGE_MASK) / sizes.PAGE_SIZE) |index| {
        const mapped = kagami.extract.lookup(kagami.state.getKernelKagami(), @intFromPtr(pointer) + index * sizes.PAGE_SIZE).?;
        if (previous) |physical| scattered = scattered or mapped.PhysicalAddress != physical + sizes.PAGE_SIZE;
        previous = mapped.PhysicalAddress;
    }
    const bytes: [*]u8 = @ptrCast(pointer);
    @memset(bytes[0..inputs.SECOND_BYTES], values.DIRTY_BYTE);
    verify.require(scattered and std.mem.allEqual(u8, bytes[0..inputs.SECOND_BYTES], values.DIRTY_BYTE), labels.FRAGMENTED);
    memory.kalloc.kfree(pointer, inputs.SECOND_BYTES);
    live_pointer = false;
    for (frames, &held) |physical, *live| {
        if (!live.*) continue;
        pmm.free.single.freePage(physical);
        live.* = false;
    }
    verify.require(std.meta.eql(before, pmm.state.getStatistics()), labels.RELEASE);
}
