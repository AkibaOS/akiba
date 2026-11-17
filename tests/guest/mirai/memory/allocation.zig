//! Kernel Size Class Regressions

const std = @import("std");

const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").constants.memory;
const labels = @import("tests").strings.memory;
const memory = @import("mirai").memory;
const pmm = @import("mirai").pmm;
const verify = @import("tests").verify;

pub fn run() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    var allocations = [_]?*anyopaque{null} ** inputs.ALLOCATION_CASES.len;
    defer {
        for (allocations, inputs.ALLOCATION_CASES) |allocation, fixture| {
            if (allocation) |pointer| memory.kalloc.kfree(pointer, fixture.Request);
        }
    }
    for (inputs.ALLOCATION_CASES, 0..) |fixture, index| {
        const pointer = try memory.kalloc.kallocZeroed(fixture.Request);
        allocations[index] = pointer;
        const bytes: [*]u8 = @ptrCast(pointer);
        verify.require(@intFromPtr(pointer) % memory.constants.zone.limits.ELEMENT_ALIGNMENT == 0 and
            std.mem.allEqual(u8, bytes[0..fixture.Capacity], 0), labels.KALLOC_ZERO);
        for (allocations[0..index], inputs.ALLOCATION_CASES[0..index]) |other, other_fixture| {
            verify.require(@intFromPtr(pointer) + fixture.Capacity <= @intFromPtr(other.?) or
                @intFromPtr(other.?) + other_fixture.Capacity <= @intFromPtr(pointer), labels.KALLOC_SEPARATION);
        }
        @memset(bytes[0..fixture.Capacity], @intCast(index + 1));
    }
    for (allocations, inputs.ALLOCATION_CASES, 0..) |allocation, fixture, index| {
        const bytes: [*]const u8 = @ptrCast(allocation.?);
        verify.require(std.mem.allEqual(u8, bytes[0..fixture.Capacity], @intCast(index + 1)), labels.KALLOC_CONTENTS);
    }
    var index: usize = 0;
    while (index < inputs.ALLOCATION_CASES.len) : (index += 2) {
        const lower = inputs.ALLOCATION_CASES[index];
        const upper = inputs.ALLOCATION_CASES[index + 1];
        const released = allocations[index + 1].?;
        memory.kalloc.kfree(released, upper.Request);
        allocations[index + 1] = null;
        const reused = try memory.kalloc.kallocZeroed(lower.Request);
        allocations[index + 1] = reused;
        const bytes: [*]const u8 = @ptrCast(reused);
        verify.require(reused == released and std.mem.allEqual(u8, bytes[0..upper.Capacity], 0), labels.KALLOC_REUSE);
    }
    const before = pmm.state.getStatistics();
    var rejected_zero = false;
    if (memory.kalloc.kalloc(0)) |unexpected| {
        memory.kalloc.kfree(unexpected, 0);
    } else |failure| {
        rejected_zero = failure == error.SizeTooLarge;
    }
    verify.require(rejected_zero and std.meta.eql(before, pmm.state.getStatistics()), labels.KALLOC_REJECTIONS);
}
