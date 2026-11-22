//! Installed Bundle And Manifest Regression Entry

const std = @import("std");

const elf = @import("shared").elf.read.executable;
const fields = @import("tests").fast.constants.bundle.elf;
const fixtures = @import("tests").fixtures.strings.bundle;
const image = @import("tests").fast.bundle.image;
const manifest = @import("shared").bundle.manifest.read;
const shapes = @import("tests").fast.strings.bundle.shape;

test "one World manifest describes all supported bundle types without granting hardware" {
    const allocator = std.testing.allocator;
    const binary = try manifest.parse(allocator, fixtures.DESCRIPTOR);
    try std.testing.expect(binary.Type == .Cli);
    try std.testing.expect(!manifest.supports(binary, .Keyboard, .Keyboard, 1));
    const driver = try manifest.parse(allocator, fixtures.DRIVER);
    try std.testing.expect(driver.Type == .Driver);
    try std.testing.expect(manifest.supports(driver, .Keyboard, .Keyboard, 1));
    try std.testing.expect(!manifest.supports(driver, .Keyboard, .Keyboard, 2));
    try std.testing.expect(!manifest.supports(driver, .Keyboard, .Framebuffer, 1));
    try std.testing.expect((try manifest.parse(allocator, fixtures.GUI)).Type == .Gui);
    try std.testing.expectError(error.InvalidManifest, manifest.parse(allocator, fixtures.MISSING_TYPE));
    try std.testing.expectError(error.UnsupportedType, manifest.parse(allocator, fixtures.UNKNOWN_TYPE));
    try std.testing.expectError(error.UnsupportedVersion, manifest.parse(allocator, fixtures.UNSUPPORTED_VERSION));
    try std.testing.expectError(error.UnsupportedABI, manifest.parse(allocator, fixtures.UNSUPPORTED_ABI));
    try std.testing.expectError(error.InvalidManifest, manifest.parse(allocator, fixtures.ESCAPE));
    try std.testing.expectError(error.InvalidManifest, manifest.parse(allocator, fixtures.DUPLICATE_MATCH));
    try std.testing.checkAllAllocationFailures(allocator, parseDriver, .{});
}

test "typed bundles resolve exact nested members in a writer-produced AFS image" {
    try image.verify(@embedFile("dynamicimage"));
}

test "oversized manifests are refused before the parser allocates" {
    try std.testing.expectError(error.TooLarge, manifest.parse(std.testing.failing_allocator, &shapes.OVERSIZED_BYTES));
}

test "plain ELF requires the native machine and a file backed executable entry" {
    const program = @embedFile("dynamicimage");
    try elf.check(program);
    const allocator = std.testing.allocator;
    const changed = try allocator.dupe(u8, program);
    defer allocator.free(changed);
    std.mem.writeInt(u16, changed[fields.MACHINE_OFFSET..][0..@sizeOf(u16)], fields.AARCH64_MACHINE, .little);
    try std.testing.expectError(error.UnsupportedArchitecture, elf.check(changed));
    @memcpy(changed, program);
    std.mem.writeInt(u64, changed[fields.ENTRY_OFFSET..][0..@sizeOf(u64)], fields.OUTSIDE_IMAGE, .little);
    try std.testing.expectError(error.InvalidEntryPoint, elf.check(changed));
}

fn parseDriver(allocator: std.mem.Allocator) !void {
    try std.testing.expect((try manifest.parse(allocator, fixtures.DRIVER)).Type == .Driver);
}
