//! Acquire One Owned Unit From The Verified Native Boot Volume

const std = @import("std");

const afs = @import("shared").afs;
const selection = @import("mirai").bootstrap.storage.selection;
const transfer = @import("mirai").bootstrap.storage.transfer;
const types = @import("mirai").bootstrap.types.storage.read;
const wire = @import("shared").ahci.constants.command.dma;

const Disk = @import("mirai").bootstrap.types.storage.disk.Disk;
const StorageError = @import("mirai").bootstrap.errors.storage.read.StorageError;
const Volume = @import("shared").boot.types.volume.Volume;

pub fn unit(expected: Volume, path: types.Path, allocator: std.mem.Allocator) !types.Image {
    var request: types.Request = .{ .Volume = expected, .Path = path, .Allocator = allocator };
    errdefer if (request.Bytes) |bytes| allocator.free(bytes);
    const location = try selection.withVolume(expected, &request, acquire);
    return .{ .Location = location, .Bytes = request.Bytes orelse return StorageError.BootUnitMissing };
}

fn acquire(context: *anyopaque, disk: *Disk) !void {
    const request: *types.Request = @ptrCast(@alignCast(context));
    var first: [wire.SECTOR_BYTES]u8 = undefined;
    var volume = try afs.read.sectors.open(transfer.source(disk), request.Volume.FirstLBA, request.Volume.LastLBA, &first);
    const scratch = try request.Allocator.alloc(u8, volume.CellSize);
    defer request.Allocator.free(scratch);
    const catalog = try afs.read.catalog.mount(afs.read.sectors.reader(&volume), scratch);
    const located = (try afs.read.catalog.open(&catalog, request.Path.Parents, request.Path.Unit, scratch)) orelse
        return StorageError.BootUnitMissing;
    const length = std.math.cast(usize, try afs.read.unit.size(&catalog.Reader, &located.DataChannel)) orelse
        return StorageError.ImageTooLarge;
    const bytes = try request.Allocator.alloc(u8, length);
    errdefer request.Allocator.free(bytes);
    _ = try afs.read.unit.readUnit(&catalog.Reader, &located, bytes, scratch);
    request.Bytes = bytes;
}
