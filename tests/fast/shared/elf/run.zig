//! Portable ELF Image Plan Test Entry

const std = @import("std");

const dynamic = @import("tests").fast.shared.elf.dynamic;
const elf = @import("shared").elf;
const fixture = @import("tests").fixtures.bytes.elf;
const growth = @import("tests").fast.shared.elf.growth;
const inputs = @import("tests").fixtures.constants.elf.layout;
const relocation = @import("tests").fast.shared.elf.relocation;

const ImageError = elf.errors.image.ImageError;

const policy: elf.types.image.Policy = .{ .MinimumAddress = inputs.PAGE_BYTES, .MaximumAddress = inputs.USER_END, .MaximumPages = inputs.MAXIMUM_PAGES };

test "dynamic ELF exposes library names symbols and both relocation tables" {
    try dynamic.readsTables();
}

test "dynamic ELF metadata requires unique matching file-backed load ranges" {
    try dynamic.checksBacking();
}

test "dynamic ELF names stay within the terminated string table" {
    try dynamic.checksNames();
}

test "dynamic ELF rejects malformed tables and a foreign interpreter" {
    try dynamic.checksTableExtents();
}

test "dynamic ELF applies a checked bias and does not infer a library entry" {
    try dynamic.placesImage();
}

test "dynamic ELF rejects invalid bias entry permissions and unsupported segments" {
    try dynamic.rejectsInvalidLayout();
}

test "dynamic ELF rejects RELRO that would freeze unrelated writable bytes" {
    try dynamic.rejectsUnsafeRelro();
}

test "ELF plans signed relative and eager import writes without changing the image bytes" {
    try relocation.plansWrites();
}

test "ELF rejects unsupported relocation operations and invalid resolved values" {
    try relocation.rejectsInvalidValues();
}

test "ELF relocation words stay wholly within writable load bytes" {
    try relocation.checksTargets();
}

test "ELF rejects duplicate and overlapping words from separate relocation tables" {
    try relocation.rejectsOverlap();
}

test "ELF relocation planning refuses alternate encodings and text relocation declarations" {
    try relocation.rejectsUnsupportedMetadata();
}

test "ELF relocation plan propagates allocator refusal" {
    try relocation.checksAllocation();
}

test "ELF counts a terabyte of sparse BSS through intervals without visiting its pages" {
    try growth.sparse();
}

test "ELF unions many fragments on one page and rejects a later writable executable conflict" {
    try growth.fragments();
}

test "ELF plan construction returns every allocation after each injected allocator failure" {
    try growth.failures();
}

test "ELF accepts an actual 65-entry table with supported loads and null metadata" {
    try growth.headers();
}

test "ELF plans seventeen supported load segments without a fixed load workspace" {
    try growth.loads();
}

test "ELF normalized plan orders validated loads by virtual address rather than file table order" {
    try growth.ordered();
}

test "independent fixed-address ELF plans file bytes BSS and distinct pages without trusting physical addresses" {
    const bytes = fixture.create();
    var plan = try elf.validate.image.parse(std.testing.allocator, &bytes, policy);
    defer plan.deinit();
    try std.testing.expectEqual(inputs.CODE_ADDRESS + 1, plan.Entry);
    try std.testing.expectEqual(@as(usize, 3), plan.Segments.len);
    try std.testing.expectEqual(@as(u64, 4), plan.Pages);
    try std.testing.expectEqual(@as(u64, inputs.PAGE_BYTES + 1), plan.Segments[2].UnitSize);
}

test "ELF wire input need not have host struct alignment" {
    var guarded: [inputs.DATA_BYTES + 1]u8 = undefined;
    const bytes = fixture.create();
    @memcpy(guarded[1..], &bytes);
    var plan = try elf.validate.image.parse(std.testing.allocator, guarded[1..], policy);
    defer plan.deinit();
    try std.testing.expectEqual(@as(usize, 3), plan.Segments.len);
}

test "ELF rejects truncated header and program table before segment access" {
    const bytes = fixture.create();
    try std.testing.expectError(ImageError.InvalidHeader, elf.validate.image.parse(std.testing.allocator, bytes[0 .. inputs.HEADER_BYTES - 1], policy));
    const table_end = inputs.HEADER_BYTES + inputs.PROGRAM_COUNT * inputs.PROGRAM_BYTES;
    try std.testing.expectError(ImageError.InvalidProgramHeaders, elf.validate.image.parse(std.testing.allocator, bytes[0 .. table_end - 1], policy));
}

test "ELF image policy rejects wrong class architecture and dynamic image type" {
    var bytes = fixture.create();
    bytes[4] = 1;
    try std.testing.expectError(ImageError.InvalidHeader, elf.validate.image.parse(std.testing.allocator, &bytes, policy));
    bytes = fixture.create();
    fixture.write16(&bytes, 18, 3);
    try std.testing.expectError(ImageError.UnsupportedArchitecture, elf.validate.image.parse(std.testing.allocator, &bytes, policy));
    bytes = fixture.create();
    fixture.write16(&bytes, 16, 3);
    try std.testing.expectError(ImageError.UnsupportedImage, elf.validate.image.parse(std.testing.allocator, &bytes, policy));
}

test "ELF bootstrap subset rejects dynamic interpreter TLS and unknown required segments" {
    for ([_]u32{ 2, 3, 7, 0x777 }) |kind| {
        var bytes = fixture.create();
        fixture.write32(&bytes, fixture.program(1), kind);
        try std.testing.expectError(ImageError.UnsupportedSegment, elf.validate.image.parse(std.testing.allocator, &bytes, policy));
    }
    var bytes = fixture.create();
    fixture.write32(&bytes, fixture.program(1), 0x6474e551);
    fixture.write32(&bytes, fixture.program(1) + 4, 5);
    try std.testing.expectError(ImageError.UnsupportedSegment, elf.validate.image.parse(std.testing.allocator, &bytes, policy));
}

test "ELF rejects unreadable writable executable and unknown permission loads" {
    for ([_]u32{ 1, 7, 12 }) |flags| {
        var bytes = fixture.create();
        fixture.write32(&bytes, fixture.program(0) + 4, flags);
        try std.testing.expectError(ImageError.InvalidSegment, elf.validate.image.parse(std.testing.allocator, &bytes, policy));
    }
}

test "ELF rejects initialized size beyond memory and truncated file spans" {
    var bytes = fixture.create();
    fixture.write64(&bytes, fixture.program(0) + 32, inputs.PAGE_BYTES + 1);
    try std.testing.expectError(ImageError.InvalidSegment, elf.validate.image.parse(std.testing.allocator, &bytes, policy));
    bytes = fixture.create();
    fixture.write64(&bytes, fixture.program(0) + 8, inputs.DATA_BYTES);
    try std.testing.expectError(ImageError.InvalidSegment, elf.validate.image.parse(std.testing.allocator, &bytes, policy));
}

test "ELF rejects overflowing and out of domain virtual ranges before rounding" {
    for ([_]u64{ 0, inputs.USER_END - 15, std.math.maxInt(u64) - 15 }) |address| {
        var bytes = fixture.create();
        fixture.write64(&bytes, fixture.program(0) + 16, address);
        try std.testing.expectError(ImageError.InvalidSegment, elf.validate.image.parse(std.testing.allocator, &bytes, policy));
    }
}

test "ELF rejects invalid segment alignment and page incongruence" {
    var bytes = fixture.create();
    fixture.write64(&bytes, fixture.program(0) + 48, 3);
    try std.testing.expectError(ImageError.InvalidSegment, elf.validate.image.parse(std.testing.allocator, &bytes, policy));
    bytes = fixture.create();
    fixture.write64(&bytes, fixture.program(0) + 16, inputs.CODE_ADDRESS + 1);
    try std.testing.expectError(ImageError.InvalidSegment, elf.validate.image.parse(std.testing.allocator, &bytes, policy));
}

test "ELF rejects byte overlap even when page permissions would be compatible" {
    var bytes = fixture.create();
    fixture.write64(&bytes, fixture.program(1) + 16, inputs.CODE_ADDRESS + 0x800);
    fixture.write64(&bytes, fixture.program(1) + 8, inputs.PAGE_BYTES + 0x800);
    try std.testing.expectError(ImageError.SegmentOverlap, elf.validate.image.parse(std.testing.allocator, &bytes, policy));
}

test "ELF safely sharing a page counts it once and unions RO with RX" {
    var bytes = fixture.create();
    fixture.share(&bytes, false);
    var plan = try elf.validate.image.parse(std.testing.allocator, &bytes, policy);
    defer plan.deinit();
    try std.testing.expectEqual(@as(u64, 3), plan.Pages);
    try std.testing.expectEqual(@as(u32, 5), elf.validate.pages.flags(&plan, inputs.CODE_ADDRESS));
}

test "ELF disjoint byte ranges may not merge into a writable executable page" {
    var bytes = fixture.create();
    fixture.share(&bytes, true);
    try std.testing.expectError(ImageError.PermissionConflict, elf.validate.image.parse(std.testing.allocator, &bytes, policy));
}

test "ELF entry must lie inside file backed executable bytes rather than BSS" {
    var bytes = fixture.create();
    fixture.write64(&bytes, 24, inputs.CODE_ADDRESS + 64);
    try std.testing.expectError(ImageError.InvalidEntryPoint, elf.validate.image.parse(std.testing.allocator, &bytes, policy));
}

test "ELF caps mapped pages and rejects program tables outside supplied bytes" {
    const bytes = fixture.create();
    var smaller = policy;
    smaller.MaximumPages = 3;
    try std.testing.expectError(ImageError.ImageTooLarge, elf.validate.image.parse(std.testing.allocator, &bytes, smaller));
    var large = bytes;
    fixture.write64(&large, fixture.program(2) + 40, (inputs.MAXIMUM_PAGES + 1) * inputs.PAGE_BYTES);
    try std.testing.expectError(ImageError.ImageTooLarge, elf.validate.image.parse(std.testing.allocator, &large, policy));
    large = bytes;
    fixture.write16(&large, 56, std.math.maxInt(u16) - 1);
    try std.testing.expectError(ImageError.InvalidProgramHeaders, elf.validate.image.parse(std.testing.allocator, &large, policy));
}

test "ELF permits zero file bytes with a congruent unused offset past the file" {
    var bytes = fixture.create();
    fixture.write64(&bytes, fixture.program(2) + 32, 0);
    fixture.write64(&bytes, fixture.program(2) + 8, inputs.DATA_BYTES + inputs.PAGE_BYTES);
    var plan = try elf.validate.image.parse(std.testing.allocator, &bytes, policy);
    defer plan.deinit();
    try std.testing.expectEqual(@as(u64, 0), plan.Segments[2].UnitSize);
}
