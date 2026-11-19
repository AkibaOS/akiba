//! Native Standard Allocator Kernel Adapter Checks

const std = @import("std");

const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").guest.constants.heap;
const labels = @import("tests").guest.strings.heap;
const memory = @import("mirai").memory;
const pmm = @import("mirai").pmm;
const values = @import("tests").guest.constants.memory;
const verify = @import("tests").guest.support.verify;

pub fn run() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const allocator = memory.allocator.native.get();
    const before = pmm.state.getStatistics();
    const small = try allocator.alloc(u8, inputs.TINY_BYTES);
    var live_small = true;
    defer if (live_small) allocator.free(small);
    @memset(small, values.DIRTY_BYTE);
    const grown = try allocator.realloc(small, inputs.SECOND_BYTES);
    live_small = false;
    var live_grown = true;
    defer if (live_grown) allocator.free(grown);
    const aligned = try allocator.alignedAlloc(u8, .fromByteUnits(inputs.ALIGNMENT), inputs.LARGE_BYTES);
    var live_aligned = true;
    defer if (live_aligned) allocator.free(aligned);
    const tiny = try allocator.alignedAlloc(u8, .fromByteUnits(inputs.ALIGNMENT), inputs.TINY_BYTES);
    var live_tiny = true;
    defer if (live_tiny) allocator.free(tiny);
    @memset(aligned, values.UNCHANGED_BYTE);
    @memset(tiny, values.DIRTY_BYTE);
    verify.require(@intFromPtr(aligned.ptr) % inputs.ALIGNMENT == 0 and @intFromPtr(tiny.ptr) % inputs.ALIGNMENT == 0 and
        std.mem.allEqual(u8, grown[0..inputs.TINY_BYTES], values.DIRTY_BYTE) and
        std.mem.allEqual(u8, aligned, values.UNCHANGED_BYTE) and tiny[0] == values.DIRTY_BYTE, labels.ADAPTER);
    verify.require(!allocator.rawResize(aligned, .fromByteUnits(inputs.ALIGNMENT), inputs.SECOND_BYTES, 0) and
        allocator.rawRemap(aligned, .fromByteUnits(inputs.ALIGNMENT), inputs.SECOND_BYTES, 0) == null and
        std.mem.allEqual(u8, aligned, values.UNCHANGED_BYTE), labels.ADAPTER_REFUSAL);
    allocator.free(tiny);
    live_tiny = false;
    allocator.free(aligned);
    live_aligned = false;
    allocator.free(grown);
    live_grown = false;
    verify.require(std.meta.eql(before, pmm.state.getStatistics()), labels.RELEASE);
}
