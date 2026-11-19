//! Executable Plan Metadata Growth Regressions

const std = @import("std");

const elf = @import("shared").elf;
const fixture = @import("tests").fixtures.bytes.elf;
const inputs = @import("tests").constants.elf;

const policy: elf.types.image.Policy = .{ .MinimumAddress = inputs.PAGE_BYTES, .MaximumAddress = inputs.USER_END, .MaximumPages = inputs.MAXIMUM_PAGES };

pub fn sparse() !void {
    var bytes = fixture.create();
    fixture.write64(&bytes, fixture.program(2) + 40, inputs.SPARSE_BSS_BYTES);
    var bounds = policy;
    bounds.MaximumPages = inputs.SPARSE_BSS_BYTES / inputs.PAGE_BYTES + 2;
    var plan = try elf.validate.image.parse(std.testing.allocator, &bytes, bounds);
    defer plan.deinit();
    try std.testing.expectEqual(bounds.MaximumPages, plan.Pages);
    try std.testing.expectEqual(@as(usize, 3), plan.Ranges.len);
    try std.testing.expectEqual(inputs.SPARSE_BSS_BYTES, plan.Ranges[2].End - plan.Ranges[2].Start);
}

pub fn fragments() !void {
    var bytes = fixture.create();
    fixture.write16(&bytes, 56, inputs.MANY_LOADS);
    for (0..inputs.MANY_LOADS) |index| {
        const start = fixture.program(index);
        fixture.write32(&bytes, start, 1);
        fixture.write32(&bytes, start + 4, if (index == 0) 5 else 4);
        fixture.write64(&bytes, start + 8, inputs.PAGE_BYTES + index * 32);
        fixture.write64(&bytes, start + 16, inputs.CODE_ADDRESS + index * 32);
        fixture.write64(&bytes, start + 32, 2);
        fixture.write64(&bytes, start + 40, 2);
        fixture.write64(&bytes, start + 48, inputs.PAGE_BYTES);
    }
    var plan = try elf.validate.image.parse(std.testing.allocator, &bytes, policy);
    defer plan.deinit();
    try std.testing.expectEqual(@as(u64, 1), plan.Pages);
    try std.testing.expectEqual(@as(usize, 1), plan.Ranges.len);
    try std.testing.expectEqual(@as(u32, 5), plan.Ranges[0].Flags);
    fixture.write32(&bytes, fixture.program(inputs.MANY_LOADS - 1) + 4, 6);
    try std.testing.expectError(error.PermissionConflict, elf.validate.image.parse(std.testing.allocator, &bytes, policy));
}

pub fn failures() !void {
    const bytes = fixture.create();
    try std.testing.checkAllAllocationFailures(std.testing.allocator, owned, .{&bytes});
}

fn owned(allocator: std.mem.Allocator, bytes: []const u8) !void {
    var plan = try elf.validate.image.parse(allocator, bytes, policy);
    defer plan.deinit();
    try std.testing.expectEqual(@as(u64, 4), plan.Pages);
}

pub fn headers() !void {
    var bytes = fixture.create();
    fixture.write16(&bytes, 56, inputs.MANY_PROGRAMS);
    var plan = try elf.validate.image.parse(std.testing.allocator, &bytes, policy);
    defer plan.deinit();
    try std.testing.expectEqual(@as(usize, inputs.PROGRAM_COUNT), plan.Segments.len);
    try std.testing.expectEqual(@as(u64, 4), plan.Pages);
}

pub fn loads() !void {
    var bytes = fixture.create();
    fixture.write16(&bytes, 56, inputs.MANY_LOADS);
    for (inputs.PROGRAM_COUNT..inputs.MANY_LOADS) |index| {
        const start = fixture.program(index);
        fixture.write32(&bytes, start, 1);
        fixture.write32(&bytes, start + 4, 4);
        fixture.write64(&bytes, start + 16, inputs.CODE_ADDRESS + (index + 1) * 2 * inputs.PAGE_BYTES);
        fixture.write64(&bytes, start + 40, inputs.PAGE_BYTES);
        fixture.write64(&bytes, start + 48, inputs.PAGE_BYTES);
    }
    var plan = try elf.validate.image.parse(std.testing.allocator, &bytes, policy);
    defer plan.deinit();
    try std.testing.expectEqual(@as(usize, inputs.MANY_LOADS), plan.Segments.len);
    try std.testing.expectEqual(@as(u64, 4 + inputs.MANY_LOADS - inputs.PROGRAM_COUNT), plan.Pages);
}

pub fn ordered() !void {
    var bytes = fixture.create();
    var temporary: [inputs.PROGRAM_BYTES]u8 = undefined;
    @memcpy(&temporary, bytes[fixture.program(0)..][0..inputs.PROGRAM_BYTES]);
    @memcpy(bytes[fixture.program(0)..][0..inputs.PROGRAM_BYTES], bytes[fixture.program(2)..][0..inputs.PROGRAM_BYTES]);
    @memcpy(bytes[fixture.program(2)..][0..inputs.PROGRAM_BYTES], &temporary);
    var plan = try elf.validate.image.parse(std.testing.allocator, &bytes, policy);
    defer plan.deinit();
    try std.testing.expectEqual(inputs.CODE_ADDRESS, plan.Segments[0].VirtualAddress);
    try std.testing.expectEqual(inputs.CODE_ADDRESS + inputs.PAGE_BYTES, plan.Segments[1].VirtualAddress);
    try std.testing.expectEqual(inputs.CODE_ADDRESS + 2 * inputs.PAGE_BYTES, plan.Segments[2].VirtualAddress);
}
