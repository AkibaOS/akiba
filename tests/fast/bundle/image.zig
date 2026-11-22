//! Exercise Installed Bundles In A Writer Produced AFS Image

const std = @import("std");

const afs = @import("shared").afs;
const files = @import("tests").fast.image;
const fixtures = @import("tests").fixtures.strings.bundle;
const geometry = @import("tests").fast.constants.image.fixtures;
const installed = @import("shared").bundle.installed;
const iterator = @import("shared").location.types.iterator;
const limits = @import("tests").fast.constants.bundle.limits;
const manifest = @import("shared").bundle.manifest.read;
const names = @import("tests").fast.strings.image.witnesses;
const packer = @import("mkafsdisk");
const shapes = @import("tests").fast.strings.bundle.shape;

const Candidate = @import("shared").bundle.types.installed.catalog.Candidate;
const Entry = afs.types.read.list.Entry;
const Image = @import("tests").fast.types.bundle.image.Image;
const ReadError = @import("shared").bundle.errors.installed.reader.ReadError;
const Reader = @import("shared").bundle.types.installed.reader.Reader;
const Unit = afs.types.catalog.UnitRecord;

pub fn verify(binary: []const u8) !void {
    const allocator = std.testing.allocator;
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try writeFixtures(temporary.dir, binary);
    var paths = try files.fixture.paths(allocator, temporary.dir);
    defer paths.deinit();
    _ = try packer.image.create.createDiskImageReported(allocator, paths.Source, paths.Output, geometry.IMAGE_MEGABYTES, null);
    const backing = try temporary.dir.openFile(names.IMAGE_NAME, .{});
    defer backing.close();
    var image = try files.lookup.openImage(backing);
    var source: Image = .{ .Catalog = undefined };
    source.Catalog = try afs.read.catalog.mount(files.io.reader(&image), &source.Scratch);
    const reader: Reader = .{ .Context = &source, .Read = read, .Size = size, .List = list };

    const ordinary = try installed.resolve.open(reader, allocator, .SystemBinary, fixtures.CHECK_NAME, binary.len);
    defer allocator.free(ordinary.Bytes);
    try std.testing.expect(ordinary.Description.Type == .Cli);
    try std.testing.expectEqualSlices(u8, binary, ordinary.Bytes);
    const driver = try installed.resolve.open(reader, allocator, .SystemDriver, fixtures.ALTERNATE_ID, binary.len);
    defer allocator.free(driver.Bytes);
    try std.testing.expect(driver.Description.Type == .Driver);
    try std.testing.expect(manifest.supports(driver.Description, .Keyboard, .Keyboard, 1));
    try std.testing.expectEqualSlices(u8, binary, driver.Bytes);
    try std.testing.expectError(error.TooLarge, installed.resolve.open(reader, allocator, .SystemDriver, fixtures.ALTERNATE_ID, binary.len - 1));
    try std.testing.expectError(error.MissingManifest, installed.resolve.open(reader, allocator, .SystemBinary, fixtures.LOOSE_ID, binary.len));
    try std.testing.expectError(error.MissingManifest, installed.resolve.open(reader, allocator, .UserBinary, fixtures.CHECK_NAME, binary.len));
    try std.testing.expectError(error.MissingBinary, installed.resolve.open(reader, allocator, .SystemBinary, fixtures.ABSENT_ID, binary.len));
    try std.testing.expectError(error.TypeMismatch, installed.resolve.open(reader, allocator, .SystemDriver, fixtures.WRONG_ID, binary.len));
    try std.testing.expectError(error.UnsupportedType, installed.resolve.open(reader, allocator, .SystemBinary, fixtures.GUI_ID, binary.len));
    try std.testing.expectError(error.InvalidExecutable, installed.resolve.open(reader, allocator, .SystemBinary, fixtures.CORRUPT_ID, binary.len));

    try std.testing.expectError(error.TypeMismatch, installed.resolve.open(reader, allocator, .SystemBinary, shapes.WRONG_SCOPE_ID, binary.len));
    try std.testing.expectError(error.MissingManifest, installed.resolve.open(reader, allocator, .SystemBinary, shapes.MANIFEST_STACK_ID, binary.len));
    try std.testing.expectError(error.MissingBinary, installed.resolve.open(reader, allocator, .SystemBinary, shapes.BINARY_STACK_ID, binary.len));
    try std.testing.expectError(error.TooLarge, installed.resolve.open(reader, allocator, .SystemBinary, shapes.OVERSIZED_ID, binary.len));
    try std.testing.expectError(error.InvalidIdentity, installed.resolve.open(reader, allocator, .SystemBinary, shapes.NONCANONICAL, binary.len));
    try std.testing.expectError(error.InvalidIdentity, installed.resolve.open(reader, allocator, .SystemBinary, shapes.ALIASED, binary.len));

    var catalog = try installed.catalog.scan(reader, allocator, .SystemDriver);
    defer catalog.deinit();
    try std.testing.expectEqual(@as(usize, 3), catalog.Candidates.len);
    try std.testing.expect((try found(catalog.Candidates, fixtures.ALTERNATE_ID)).State == .Description);
    try expectFailure(catalog.Candidates, fixtures.WRONG_ID, error.TypeMismatch);
    try expectFailure(catalog.Candidates, fixtures.LOOSE_DRIVER_ID, error.WrongBundleKind);
    try std.testing.expectError(error.CatalogTooLarge, installed.catalog.scan(reader, allocator, .UserBinary));
    try std.testing.checkAllAllocationFailures(allocator, allocateCatalog, .{reader});
    source.RepeatFirst = true;
    try std.testing.expectError(error.InvalidCatalog, installed.catalog.scan(reader, allocator, .SystemDriver));
}

fn allocateCatalog(allocator: std.mem.Allocator, reader: Reader) !void {
    var catalog = try installed.catalog.scan(reader, allocator, .SystemDriver);
    defer catalog.deinit();
    try std.testing.expect((try found(catalog.Candidates, fixtures.ALTERNATE_ID)).State == .Description);
}

fn writeFixtures(directory: std.fs.Dir, binary: []const u8) !void {
    try files.fixture.createSource(directory, true);
    try files.fixture.addModerateUnits(directory);
    for ([_][]const u8{ fixtures.CHECK_PATH, fixtures.DRIVER_PATH, fixtures.WRONG_PATH, fixtures.ABSENT_PATH, fixtures.GUI_PATH, fixtures.CORRUPT_PATH }) |path| {
        try directory.makePath(path);
    }
    try directory.writeFile(.{ .sub_path = fixtures.CHECK_MANIFEST_SOURCE, .data = fixtures.DESCRIPTOR });
    try directory.writeFile(.{ .sub_path = fixtures.CHECK_BINARY_SOURCE, .data = binary });
    try directory.writeFile(.{ .sub_path = fixtures.DRIVER_MANIFEST, .data = fixtures.DRIVER });
    try directory.writeFile(.{ .sub_path = fixtures.DRIVER_BINARY, .data = binary });
    try directory.writeFile(.{ .sub_path = fixtures.DRIVER_ROOT_FILE, .data = binary });
    try directory.writeFile(.{ .sub_path = fixtures.WRONG_MANIFEST, .data = fixtures.DESCRIPTOR });
    try directory.writeFile(.{ .sub_path = fixtures.WRONG_BINARY, .data = binary });
    try directory.writeFile(.{ .sub_path = fixtures.ABSENT_MANIFEST, .data = fixtures.DESCRIPTOR });
    try directory.writeFile(.{ .sub_path = fixtures.GUI_MANIFEST, .data = fixtures.GUI });
    try directory.writeFile(.{ .sub_path = fixtures.GUI_BINARY, .data = binary });
    try directory.writeFile(.{ .sub_path = fixtures.CORRUPT_MANIFEST, .data = fixtures.DESCRIPTOR });
    try directory.writeFile(.{ .sub_path = fixtures.CORRUPT_BINARY, .data = fixtures.OTHER_ARCH });
    try directory.writeFile(.{ .sub_path = fixtures.LOOSE_ORDINARY, .data = binary });
    try directory.makePath(shapes.WRONG_SCOPE);
    try directory.makePath(shapes.MANIFEST_STACK_MEMBER);
    try directory.makePath(shapes.BINARY_STACK_MEMBER);
    try directory.makePath(shapes.OVERSIZED);
    try directory.writeFile(.{ .sub_path = shapes.WRONG_SCOPE_MANIFEST, .data = fixtures.DRIVER });
    try directory.writeFile(.{ .sub_path = shapes.WRONG_SCOPE_BINARY, .data = binary });
    try directory.writeFile(.{ .sub_path = shapes.MANIFEST_STACK_BINARY, .data = binary });
    try directory.writeFile(.{ .sub_path = shapes.BINARY_STACK_MANIFEST, .data = fixtures.DESCRIPTOR });
    try directory.writeFile(.{ .sub_path = shapes.OVERSIZED_MANIFEST, .data = &shapes.OVERSIZED_BYTES });
    try directory.makePath(shapes.RESERVED_DIRECTORY);
    var crowded = try directory.openDir(shapes.RESERVED_DIRECTORY, .{});
    defer crowded.close();
    for (0..limits.OVERFLOW_ENTRIES) |index| {
        var name: [limits.NAME_BYTES]u8 = undefined;
        try crowded.writeFile(.{ .sub_path = try std.fmt.bufPrint(&name, shapes.EMPTY_UNIT, .{index}), .data = &.{} });
    }
}

fn expectFailure(candidates: []const Candidate, identity: []const u8, expected: anyerror) !void {
    const state = (try found(candidates, identity)).State;
    try std.testing.expect(state == .Failure);
    try std.testing.expectEqual(expected, state.Failure);
}

fn found(candidates: []const Candidate, id: []const u8) !Candidate {
    for (candidates) |candidate| if (std.mem.eql(u8, candidate.Identity, id)) return candidate;
    return error.TestUnexpectedResult;
}

fn list(context: *anyopaque, path: []const u8, index: u64) ReadError!?Entry {
    const source: *Image = @ptrCast(@alignCast(context));
    var buffer: [4][]const u8 = undefined;
    const parts = try split(path, &buffer);
    const ordinal = if (source.RepeatFirst and index == 1) 0 else index;
    return afs.read.list.child(&source.Catalog, parts, ordinal, &source.Scratch) catch |failure| switch (failure) {
        error.MissingStack => error.MissingStack,
        else => error.ReadFailed,
    };
}

fn unit(source: *Image, path: []const u8) ReadError!?Unit {
    var buffer: [4][]const u8 = undefined;
    const parts = try split(path, &buffer);
    return afs.read.catalog.open(&source.Catalog, parts[0 .. parts.len - 1], parts[parts.len - 1], &source.Scratch) catch error.ReadFailed;
}

fn size(context: *anyopaque, path: []const u8) ReadError!?u64 {
    const source: *Image = @ptrCast(@alignCast(context));
    const entry = (try unit(source, path)) orelse return null;
    return afs.read.unit.size(&source.Catalog.Reader, &entry.DataChannel) catch error.ReadFailed;
}

fn read(context: *anyopaque, allocator: std.mem.Allocator, path: []const u8, maximum: usize) ReadError!?[]u8 {
    const source: *Image = @ptrCast(@alignCast(context));
    const entry = (try unit(source, path)) orelse return null;
    const length = afs.read.unit.size(&source.Catalog.Reader, &entry.DataChannel) catch return error.ReadFailed;
    if (length > maximum) return error.TooLarge;
    const bytes = try allocator.alloc(u8, @intCast(length));
    errdefer allocator.free(bytes);
    _ = afs.read.unit.readUnit(&source.Catalog.Reader, &entry, bytes, &source.Scratch) catch return error.ReadFailed;
    return bytes;
}

fn split(path: []const u8, out: [][]const u8) ReadError![][]const u8 {
    var scanner = iterator.LocationIterator.init(path);
    var count: usize = 0;
    while (scanner.next()) |component| {
        if (count == out.len) return error.ReadFailed;
        out[count] = component;
        count += 1;
    }
    if (count == 0) return error.ReadFailed;
    return out[0..count];
}
