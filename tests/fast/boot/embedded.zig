//! Verify Selection Of Exactly One Read Only Boot Payload

const std = @import("std");

const elf = @import("shared").elf;
const fixture = @import("tests").fixtures.bytes.elf;
const image = @import("shared").pulse.boot.image;
const layout = @import("tests").fixtures.constants.elf.layout;
const samples = @import("tests").fast.constants.boot.bootstrap;

pub fn exactPayload() !void {
    var bytes = fixture.create();
    embed(&bytes, samples.PAYLOAD_INDEX);
    const start = (samples.PAYLOAD_INDEX + 1) * layout.PAGE_BYTES;
    try std.testing.expectEqualSlices(u8, bytes[start..][0..samples.PAYLOAD_BYTES], try image.weaver(&bytes));
}

pub fn rejectedPayloads() !void {
    var bytes = fixture.create();
    try std.testing.expectError(error.BootstrapImageMissing, image.weaver(&bytes));
    embed(&bytes, samples.PAYLOAD_INDEX);
    const first = fixture.program(samples.PAYLOAD_INDEX);
    fixture.write32(&bytes, first + samples.FLAGS_OFFSET, samples.READ_WRITE);
    try std.testing.expectError(error.InvalidBootstrapImage, image.weaver(&bytes));
    embed(&bytes, samples.PAYLOAD_INDEX);
    fixture.write64(&bytes, first + samples.MEMORY_BYTES_OFFSET, samples.PAYLOAD_BYTES + 1);
    try std.testing.expectError(error.InvalidBootstrapImage, image.weaver(&bytes));
    embed(&bytes, samples.PAYLOAD_INDEX);
    fixture.write64(&bytes, first + samples.UNIT_OFFSET, bytes.len - 1);
    try std.testing.expectError(error.InvalidBootstrapImage, image.weaver(&bytes));
    bytes = fixture.create();
    embed(&bytes, samples.PAYLOAD_INDEX);
    embed(&bytes, samples.DUPLICATE_INDEX);
    try std.testing.expectError(error.InvalidBootstrapImage, image.weaver(&bytes));
}

pub fn exclusivePages() !void {
    var bytes = fixture.create();
    embed(&bytes, samples.PAYLOAD_INDEX);
    const neighbor = fixture.program(samples.DUPLICATE_INDEX);
    fixture.write32(&bytes, neighbor + samples.FLAGS_OFFSET, samples.READ_ONLY);
    fixture.write64(&bytes, neighbor + samples.VIRTUAL_OFFSET, samples.ADDRESS + layout.PAGE_BYTES);
    const payload = (samples.PAYLOAD_INDEX + 1) * layout.PAGE_BYTES;
    try std.testing.expectEqualSlices(u8, bytes[payload..][0..samples.PAYLOAD_BYTES], try image.weaver(&bytes));

    const next = (samples.DUPLICATE_INDEX + 1) * layout.PAGE_BYTES;
    fixture.write64(&bytes, neighbor + samples.UNIT_OFFSET, next + samples.PAYLOAD_BYTES);
    fixture.write64(&bytes, neighbor + samples.VIRTUAL_OFFSET, samples.ADDRESS + samples.PAYLOAD_BYTES);
    var plan = try elf.validate.image.parse(std.testing.allocator, &bytes, .{
        .MinimumAddress = layout.PAGE_BYTES,
        .MaximumAddress = layout.USER_END,
        .MaximumPages = layout.MAXIMUM_PAGES,
    });
    defer plan.deinit();
    try std.testing.expectEqual(samples.READ_ONLY, elf.validate.pages.flags(&plan, samples.ADDRESS));
    try std.testing.expectError(error.InvalidBootstrapImage, image.weaver(&bytes));
}

fn embed(bytes: []u8, index: usize) void {
    const header = fixture.program(index);
    fixture.write32(bytes, header + samples.FLAGS_OFFSET, samples.READ_ONLY);
    fixture.write64(bytes, header + samples.VIRTUAL_OFFSET, samples.ADDRESS);
    fixture.write64(bytes, header + samples.UNIT_BYTES_OFFSET, samples.PAYLOAD_BYTES);
    fixture.write64(bytes, header + samples.MEMORY_BYTES_OFFSET, samples.PAYLOAD_BYTES);
}
