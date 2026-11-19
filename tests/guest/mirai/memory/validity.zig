//! Zone Element Ownership Regressions

const std = @import("std");

const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").guest.constants.memory;
const labels = @import("tests").guest.strings.memory;
const memory = @import("mirai").memory;
const verify = @import("tests").guest.support.verify;

const Zone = memory.types.zone.Zone;

var retained_zone: ?*Zone = null;

pub fn run() !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (retained_zone == null) retained_zone = try memory.zone.create.create(labels.ZONE_VALIDITY_NAME, inputs.ZONE_VALIDITY_SIZE);
    const fixture = retained_zone.?;
    try duplicate(fixture);
    try interior(fixture);
}

fn interior(fixture: *Zone) !void {
    const pointer = try memory.zone.alloc.zalloc(fixture);
    defer {
        memory.zone.alloc.zfree(fixture, pointer);
        _ = memory.zone.gc.collect(fixture);
    }
    const bytes: [*]u8 = @ptrCast(pointer);
    @memset(bytes[0..fixture.ElementSize], inputs.DIRTY_BYTE);
    const live = fixture.inUse();
    const freed = fixture.FreeCount;
    const invalid: *anyopaque = @ptrFromInt(@intFromPtr(pointer) + inputs.ZONE_INTERIOR_OFFSET);
    memory.zone.alloc.zfree(fixture, invalid);
    verify.require(memory.zone.alloc.owns(fixture, pointer) and !memory.zone.alloc.owns(fixture, invalid) and
        !memory.zone.alloc.owns(fixture, @ptrCast(fixture)) and fixture.inUse() == live and fixture.FreeCount == freed and
        std.mem.allEqual(u8, bytes[0..fixture.ElementSize], inputs.DIRTY_BYTE), labels.ZONE_INTERIOR);
}

fn duplicate(fixture: *Zone) !void {
    const released = try memory.zone.alloc.zalloc(fixture);
    var live = true;
    defer if (live) memory.zone.alloc.zfree(fixture, released);
    const retained = try memory.zone.alloc.zalloc(fixture);
    defer {
        memory.zone.alloc.zfree(fixture, retained);
        _ = memory.zone.gc.collect(fixture);
    }
    const bytes: [*]u8 = @ptrCast(retained);
    @memset(bytes[0..fixture.ElementSize], inputs.DIRTY_BYTE);
    memory.zone.alloc.zfree(fixture, released);
    live = false;
    const count = fixture.inUse();
    const freed = fixture.FreeCount;
    memory.zone.alloc.zfree(fixture, released);
    verify.require(!memory.zone.alloc.owns(fixture, released) and memory.zone.alloc.owns(fixture, retained) and
        fixture.inUse() == count and fixture.FreeCount == freed and
        std.mem.allEqual(u8, bytes[0..fixture.ElementSize], inputs.DIRTY_BYTE), labels.ZONE_DUPLICATE);
}
