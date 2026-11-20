//! Weaver Native Lookup On Writer Produced AFS

const std = @import("std");

const afs = @import("shared").afs;
const elf = @import("tests").fixtures.constants.elf.layout;
const files = @import("tests").fast.toolchain.image;
const geometry = @import("tests").fast.constants.image;
const names = @import("tests").fast.strings.image;
const packer = @import("mkafsdisk");
const strings = @import("tests").fast.weaver.strings.afs;
const weaver = @import("weaver");

const Device = @import("tests").fast.weaver.types.afs.Device;
const ALLOCATOR = std.testing.allocator;
const LIBRARY_NAME = @import("tests").fixtures.strings.elf.identities.DYNAMIC_SOURCE;

pub fn installed(program: []const u8, library: []const u8) !void {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    try files.fixture.createSource(temporary.dir, true);
    try files.fixture.addModerateUnits(temporary.dir);
    try temporary.dir.makePath(strings.SYSTEM);
    try temporary.dir.makePath(strings.INSTALLED);
    try temporary.dir.writeFile(.{ .sub_path = strings.LIBRARY_PATH, .data = library });
    try temporary.dir.writeFile(.{ .sub_path = strings.SHADOW_PATH, .data = strings.DECOY });
    try temporary.dir.writeFile(.{ .sub_path = strings.INSTALLED_ONLY_PATH, .data = strings.DECOY });
    var paths = try files.fixture.paths(ALLOCATOR, temporary.dir);
    defer paths.deinit();
    const report = try packer.image.create.createDiskImageReported(ALLOCATOR, paths.Source, paths.Output, geometry.IMAGE_MEGABYTES, null);
    const image = try temporary.dir.openFile(names.IMAGE_NAME, .{});
    defer image.close();
    var device: Device = .{ .File = image, .CellSize = report.CellBytes, .Start = report.AfsFirstSector * geometry.SECTOR_BYTES };
    var reader: afs.types.block.BlockReader = .{ .Context = &device, .ReadFn = read, .CellSize = report.CellBytes, .TotalCells = report.TotalCells };
    var cell: [geometry.CELL_BYTES]u8 = undefined;
    reader.TotalCells -= 1;
    try std.testing.expectError(error.InvalidVolumeHeader, afs.read.catalog.mount(reader, &cell));
    reader.TotalCells += 1;
    const volume = try afs.read.catalog.mount(reader, &cell);
    try std.testing.expect(volume.Index.Depth > 1);
    const source = weaver.library.afs.source(&volume);
    var graph = try weaver.library.load.collect.collect(ALLOCATOR, source, program);
    defer graph.deinit();
    try std.testing.expectEqual(@as(usize, 1), graph.Libraries.len);
    const found = graph.get(LIBRARY_NAME) orelse return error.TestUnexpectedResult;
    try std.testing.expectEqualSlices(u8, library, found.Bytes);
    var image_plan = try weaver.image.place.place(ALLOCATOR, &graph, .{
        .Executable = elf.DYNAMIC_EXECUTABLE_BIAS,
        .Libraries = &.{elf.DYNAMIC_LIBRARY_BIAS},
    }, .{ .MinimumAddress = elf.PAGE_BYTES, .MaximumAddress = elf.USER_END, .MaximumPages = elf.MAXIMUM_PAGES }, &.{});
    defer image_plan.deinit();
    var linked = try weaver.link.plan.plan(ALLOCATOR, &image_plan);
    defer linked.deinit();
    try std.testing.expect(linked.Executable.Writes.len != 0);
    try std.testing.expectError(error.LibraryNotFound, weaver.library.load.open.open(ALLOCATOR, source, strings.INSTALLED_ONLY));
    device.Refuse = true;
    try std.testing.expectError(error.LibraryReadFailed, weaver.library.load.open.open(ALLOCATOR, source, LIBRARY_NAME));
}

fn read(context: *anyopaque, cell: u64, destination: []u8) afs.errors.block.BlockError!void {
    const device: *Device = @ptrCast(@alignCast(context));
    if (device.Refuse) return error.ReadFailed;
    const position = device.Start + cell * device.CellSize;
    files.io.readExact(device.File, position, destination) catch return error.ReadFailed;
}
