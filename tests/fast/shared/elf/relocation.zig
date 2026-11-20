//! Native ELF Relocation Plan Cases

const std = @import("std");

const dynamic = @import("tests").fast.shared.elf.dynamic;
const elf = @import("shared").elf;
const fixture = @import("tests").fixtures.bytes.elf;
const inputs = @import("tests").fixtures.constants.elf.layout;

const POLICY: elf.types.image.Policy = .{ .MinimumAddress = inputs.PAGE_BYTES, .MaximumAddress = inputs.USER_END, .MaximumPages = inputs.MAXIMUM_PAGES };
const ALLOCATOR = std.testing.allocator;
const BINDINGS = [_]?u64{ null, 0x701238 };
const GENERAL = inputs.PAGE_BYTES + inputs.DYNAMIC_RELA;
const PROCEDURE = inputs.PAGE_BYTES + inputs.DYNAMIC_PLT;
const DYNAMIC = inputs.PAGE_BYTES + inputs.DYNAMIC_TABLE;

pub fn plansWrites() !void {
    const plan = elf.validate.relocation.plan;
    var bytes = dynamic.loadImage();
    record(&bytes, GENERAL, 0x53f8, 8, -0x1000);
    record(&bytes, PROCEDURE, 0x5400, 0x100000007, 0);
    const original = bytes;
    var image = try place(&bytes);
    defer image.Image.deinit();
    var writes = try plan(ALLOCATOR, &image, &BINDINGS);
    defer writes.deinit();
    try std.testing.expectEqual(@as(usize, 2), writes.Writes.len);
    try std.testing.expectEqual(@as(u64, 0x2053f8), writes.Writes[0].Address);
    try std.testing.expectEqual(@as(u64, 0x1ff000), writes.Writes[0].Value);
    try std.testing.expectEqual(@as(u64, 0x205400), writes.Writes[1].Address);
    try std.testing.expectEqual(@as(u64, 0x701238), writes.Writes[1].Value);
    try std.testing.expectEqualSlices(u8, &original, &bytes);
    var eager = original;
    record(&eager, GENERAL, 0x5408, 0x100000006, 0);
    var eager_image = try place(&eager);
    defer eager_image.Image.deinit();
    var eager_writes = try plan(ALLOCATOR, &eager_image, &BINDINGS);
    defer eager_writes.deinit();
    try std.testing.expectEqual(@as(u64, 0x205400), eager_writes.Writes[0].Address);
    try std.testing.expectEqual(@as(u64, 0x205408), eager_writes.Writes[1].Address);
    try std.testing.expectEqual(@as(u64, 0x701238), eager_writes.Writes[1].Value);
}

pub fn rejectsInvalidValues() !void {
    const cases = [_]struct { Info: u64, Addend: i64, Reason: anyerror }{
        .{ .Info = 1, .Addend = 0, .Reason = error.UnsupportedRelocation },
        .{ .Info = 0x100000008, .Addend = 0, .Reason = error.InvalidRelocation },
        .{ .Info = 8, .Addend = -0x200001, .Reason = error.InvalidRelocationValue },
        .{ .Info = 8, .Addend = -0x1ff001, .Reason = error.InvalidRelocationValue },
        .{ .Info = 8, .Addend = std.math.maxInt(i64), .Reason = error.InvalidRelocationValue },
        .{ .Info = 0x100000006, .Addend = 1, .Reason = error.InvalidRelocation },
    };
    for (cases) |case| {
        var bytes = dynamic.loadImage();
        record(&bytes, GENERAL, 0x53f8, case.Info, case.Addend);
        record(&bytes, PROCEDURE, 0x5400, 0x100000007, 0);
        try reject(&bytes, &BINDINGS, case.Reason);
    }
    var bytes = dynamic.loadImage();
    record(&bytes, GENERAL, 0x53f8, 8, 0x5400);
    record(&bytes, PROCEDURE, 0x5400, 7, 0);
    try reject(&bytes, &BINDINGS, error.InvalidRelocation);
    record(&bytes, PROCEDURE, 0x5400, 0x100000007, 0);
    try reject(&bytes, &.{null}, error.MissingBinding);
    try reject(&bytes, &.{ null, null }, error.MissingBinding);
    try reject(&bytes, &.{ null, 0 }, error.InvalidRelocationValue);
    try reject(&bytes, &.{ null, 0x800000000000 }, error.InvalidRelocationValue);
}

pub fn checksTargets() !void {
    for ([_]u64{ 0x50ff, 0x5ff9, 0x6000, std.math.maxInt(u64) }) |target| {
        var bytes = dynamic.loadImage();
        record(&bytes, GENERAL, 0x53f8, 8, 0x5400);
        record(&bytes, PROCEDURE, target, 0x100000007, 0);
        try reject(&bytes, &BINDINGS, error.InvalidRelocationTarget);
    }
}

pub fn rejectsOverlap() !void {
    for ([_]u64{ 0x5400, 0x53ff }) |target| {
        var bytes = dynamic.loadImage();
        record(&bytes, GENERAL, 0x5400, 8, 0x5400);
        record(&bytes, PROCEDURE, target, 0x100000007, 0);
        try reject(&bytes, &BINDINGS, error.OverlappingRelocation);
    }
}

pub fn rejectsUnsupportedMetadata() !void {
    for ([_]u64{ 17, 18, 19, 22, 30, 35, 36, 37 }) |tag| {
        var bytes = dynamic.loadImage();
        record(&bytes, GENERAL, 0x53f8, 8, 0x5400);
        record(&bytes, PROCEDURE, 0x5400, 0x100000007, 0);
        fixture.write64(&bytes, DYNAMIC, tag);
        fixture.write64(&bytes, DYNAMIC + 8, 4);
        try reject(&bytes, &BINDINGS, error.UnsupportedRelocation);
    }
}

pub fn checksAllocation() !void {
    var bytes = dynamic.loadImage();
    record(&bytes, GENERAL, 0x53f8, 8, 0x5400);
    record(&bytes, PROCEDURE, 0x5400, 0x100000007, 0);
    var image = try place(&bytes);
    defer image.Image.deinit();
    var failing = std.testing.FailingAllocator.init(ALLOCATOR, .{ .fail_index = 0 });
    try std.testing.expectError(error.OutOfMemory, elf.validate.relocation.plan(failing.allocator(), &image, &BINDINGS));
}

fn place(bytes: []const u8) !elf.types.dynamic.Layout {
    return elf.validate.dynamic.parse(ALLOCATOR, bytes, inputs.DYNAMIC_BIAS, .Executable, POLICY);
}

fn reject(bytes: []const u8, bindings: []const ?u64, reason: anyerror) !void {
    var image = try place(bytes);
    defer image.Image.deinit();
    try std.testing.expectError(reason, elf.validate.relocation.plan(ALLOCATOR, &image, bindings));
}

fn record(bytes: []u8, start: usize, address: u64, info: u64, addend: i64) void {
    fixture.write64(bytes, start, address);
    fixture.write64(bytes, start + 8, info);
    fixture.write64(bytes, start + 16, @bitCast(addend));
}
