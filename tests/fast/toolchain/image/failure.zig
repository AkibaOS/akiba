//! Real I O Boundary And Publication Failure Regressions

const std = @import("std");

const afs = @import("shared").afs;
const capacity = @import("tests").fast.toolchain.image.constants.capacity;
const constants = @import("tests").fast.toolchain.image.constants.emission;
const esp = @import("tests").fast.toolchain.image.esp;
const fixture = @import("tests").fast.toolchain.image.fixture;
const inputs = @import("tests").fast.constants.image;
const io = @import("tests").fast.toolchain.image.io;
const lookup = @import("tests").fast.toolchain.image.lookup;
const names = @import("tests").fast.strings.image;
const strings = @import("tests").fast.toolchain.image.strings.emission;
const tool = @import("mkafsdisk");
const types = @import("tests").fast.toolchain.image.types.failure;

pub fn sourceChangeRefusesPublication() !void {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    var paths = try fixture.paths(std.testing.allocator, temporary.dir);
    defer paths.deinit();
    try fixture.createSource(temporary.dir, true);
    try fixture.addMutableUnit(temporary.dir);
    try fixture.writeSentinel(temporary.dir);
    const source = try std.fs.path.join(std.testing.allocator, &.{ paths.Source, strings.NESTED_IDENTITY, strings.MUTABLE_IDENTITY });
    defer std.testing.allocator.free(source);
    var context = types.Context{ .Kind = .SourceChange, .SourcePath = source };
    try std.testing.expectError(error.SourceChanged, tool.image.create.createDiskImageUsingIO(std.testing.allocator, paths.Source, paths.Output, capacity.DEFAULT_MIB, operations(&context)));
    const changed = try temporary.dir.openFile(strings.MUTABLE_PATH, .{});
    defer changed.close();
    try std.testing.expectEqual(@as(u64, 0), try changed.getEndPos());
    try fixture.expectSentinel(temporary.dir);
    try fixture.expectOwnedEntries(temporary.dir, true, true);
}

pub fn shortReadsPreserveAFSPayloadBytes() !void {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    var paths = try fixture.paths(std.testing.allocator, temporary.dir);
    defer paths.deinit();
    try fixture.createSource(temporary.dir, true);
    var context = types.Context{ .Kind = .ShortRead };
    try tool.image.create.createDiskImageUsingIO(std.testing.allocator, paths.Source, paths.Output, capacity.DEFAULT_MIB, operations(&context));
    const file = try temporary.dir.openFile(names.IMAGE_NAME, .{});
    defer file.close();
    var image = try lookup.openImage(file);
    const efi = (try lookup.findRecord(afs.types.catalog.StackRecord, &image, capacity.ORIGIN_ID, names.EFI_NAME)) orelse return error.TestExpectedEqual;
    const boot = (try lookup.findRecord(afs.types.catalog.StackRecord, &image, efi.NodeId, names.BOOT_NAME)) orelse return error.TestExpectedEqual;
    const unit = (try lookup.findRecord(afs.types.catalog.UnitRecord, &image, boot.NodeId, names.BOOTLOADER_NAME)) orelse return error.TestExpectedEqual;
    const reader = io.reader(&image);
    var scratch: [capacity.CELL_BYTES]u8 = undefined;
    var bytes: [inputs.BOOTLOADER_BYTES.len]u8 = undefined;
    try std.testing.expectEqual(@as(u64, bytes.len), try afs.read.unit.readUnit(&reader, &unit, &bytes, &scratch));
    try std.testing.expectEqualSlices(u8, &inputs.BOOTLOADER_BYTES, &bytes);
    try fixture.expectOwnedEntries(temporary.dir, true, true);
}

pub fn shortReadsPreserveESPPayloadBytes() !void {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    var paths = try fixture.paths(std.testing.allocator, temporary.dir);
    defer paths.deinit();
    try fixture.createSource(temporary.dir, true);
    var context = types.Context{ .Kind = .ShortRead };
    try tool.image.create.createDiskImageUsingIO(std.testing.allocator, paths.Source, paths.Output, capacity.DEFAULT_MIB, operations(&context));
    const file = try temporary.dir.openFile(names.IMAGE_NAME, .{});
    defer file.close();
    const boot = try esp.bootMetadata(file);
    try esp.bootloaderChainAndPadding(file, &boot);
    try fixture.expectOwnedEntries(temporary.dir, true, true);
}

pub fn readFailureKeepsFinalState() !void {
    try expectFailedPublication(.Read, error.InjectedReadFailure);
}

pub fn writeFailureKeepsFinalState() !void {
    try expectFailedPublication(.Write, error.InjectedWriteFailure);
}

pub fn syncFailureKeepsFinalState() !void {
    try expectFailedPublication(.Sync, error.InjectedSyncFailure);
}

pub fn renameFailureKeepsFinalState() !void {
    try expectFailedPublication(.Rename, error.InjectedRenameFailure);
}

pub fn allocationFailuresKeepFinalStateAndReleaseOwnership() !void {
    try std.testing.checkAllAllocationFailures(std.testing.allocator, buildWithAllocator, .{false});
    try std.testing.checkAllAllocationFailures(std.testing.allocator, buildWithAllocator, .{true});
}

fn buildWithAllocator(allocator: std.mem.Allocator, existing: bool) !void {
    var temporary = std.testing.tmpDir(.{});
    defer temporary.cleanup();
    var paths = try fixture.paths(std.testing.allocator, temporary.dir);
    defer paths.deinit();
    try fixture.createSource(temporary.dir, true);
    if (existing) try fixture.writeSentinel(temporary.dir);
    tool.image.create.createDiskImage(allocator, paths.Source, paths.Output, capacity.DEFAULT_MIB) catch |failure| {
        if (failure != error.OutOfMemory) return failure;
        if (existing) {
            try fixture.expectSentinel(temporary.dir);
        } else {
            try std.testing.expectError(error.FileNotFound, temporary.dir.access(names.IMAGE_NAME, .{}));
        }
        try fixture.expectOwnedEntries(temporary.dir, true, existing);
        return failure;
    };
    const file = try temporary.dir.openFile(names.IMAGE_NAME, .{});
    defer file.close();
    _ = try lookup.openImage(file);
    try fixture.expectOwnedEntries(temporary.dir, true, true);
}

fn expectFailedPublication(kind: types.Kind, expected: anyerror) !void {
    for ([_]bool{ false, true }) |existing| {
        var temporary = std.testing.tmpDir(.{});
        defer temporary.cleanup();
        var paths = try fixture.paths(std.testing.allocator, temporary.dir);
        defer paths.deinit();
        try fixture.createSource(temporary.dir, true);
        if (existing) try fixture.writeSentinel(temporary.dir);
        var context = types.Context{ .Kind = kind };
        try std.testing.expectError(expected, tool.image.create.createDiskImageUsingIO(std.testing.allocator, paths.Source, paths.Output, capacity.DEFAULT_MIB, operations(&context)));
        if (existing) {
            try fixture.expectSentinel(temporary.dir);
        } else {
            try std.testing.expectError(error.FileNotFound, temporary.dir.access(names.IMAGE_NAME, .{}));
        }
        try fixture.expectOwnedEntries(temporary.dir, true, existing);
    }
}

fn operations(context: *types.Context) tool.types.io.Operations {
    return .{ .Context = context, .ReadFn = readFile, .WriteFn = writeFile, .SyncFn = syncFile, .RenameFn = renameOutput };
}

fn readFile(context_pointer: ?*anyopaque, file: std.fs.File, buffer: []u8) !usize {
    const context: *types.Context = @ptrCast(@alignCast(context_pointer orelse return error.TestUnexpectedResult));
    context.ReadCalls += 1;
    if (context.Kind == .SourceChange and !context.Changed) {
        const source = try std.fs.cwd().openFile(context.SourcePath, .{ .mode = .write_only });
        defer source.close();
        try source.setEndPos(0);
        context.Changed = true;
    }
    if (context.Kind == .Read and context.ReadCalls == constants.FAILURE_OPERATION) return error.InjectedReadFailure;
    const length = if (context.Kind == .ShortRead) @min(buffer.len, constants.SHORT_READ_BYTES) else buffer.len;
    return file.read(buffer[0..length]);
}

fn writeFile(context_pointer: ?*anyopaque, file: std.fs.File, buffer: []const u8, offset: u64) !void {
    const context: *types.Context = @ptrCast(@alignCast(context_pointer orelse return error.TestUnexpectedResult));
    context.WriteCalls += 1;
    if (context.Kind == .Write and context.WriteCalls == constants.FAILURE_OPERATION) return error.InjectedWriteFailure;
    try file.pwriteAll(buffer, offset);
}

fn syncFile(context_pointer: ?*anyopaque, file: std.fs.File) !void {
    const context: *types.Context = @ptrCast(@alignCast(context_pointer orelse return error.TestUnexpectedResult));
    if (context.Kind == .Sync) return error.InjectedSyncFailure;
    try file.sync();
}

fn renameOutput(context_pointer: ?*anyopaque, atomic: *std.fs.AtomicFile) !void {
    const context: *types.Context = @ptrCast(@alignCast(context_pointer orelse return error.TestUnexpectedResult));
    if (context.Kind == .Rename) return error.InjectedRenameFailure;
    try atomic.renameIntoPlace();
}
