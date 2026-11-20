//! Select And Revalidate One Native Bootstrap Disk

const std = @import("std");

const ahci = @import("shared").ahci;
const guard = @import("asm").interrupts.guard;
const identity = @import("mirai").bootstrap.storage.identity;
const layout = @import("common").constants.memory.layout;
const pci = @import("mirai").bootstrap.storage.pci;
const physmap = @import("mirai").kagami.tables.physmap;
const registers = @import("mirai").bootstrap.storage.registers;
const session = @import("mirai").bootstrap.storage.session;
const values = @import("mirai").bootstrap.constants.storage.registers;

const Controller = ahci.types.discover.controller.Controller;
const DiscoverError = ahci.errors.discover.selection.DiscoverError;
const Disk = @import("mirai").bootstrap.types.storage.disk.Disk;
const Lease = @import("mirai").bootstrap.types.storage.session.Lease;
const Location = ahci.types.discover.selection.Location;
const Read = @import("mirai").bootstrap.types.storage.session.Read;
const StorageError = @import("mirai").bootstrap.errors.storage.read.StorageError;
const Volume = @import("shared").boot.types.volume.Volume;
const wire = ahci.constants.command.dma;

pub fn withVolume(expected: Volume, context: *anyopaque, consume: Read) !Location {
    if (!expected.isValid() or expected.BlockBytes != wire.SECTOR_BYTES) return StorageError.AhciBootVolumeMismatch;
    const flags = guard.acquire();
    defer guard.release(flags);
    var volume = expected;
    const location = (try ahci.discover.selection.unique(pci.source(), .{ .Context = &volume, .Find = find })) orelse
        return StorageError.AhciBootVolumeMismatch;
    var lease: Lease = .{ .Expected = expected, .Context = context, .Consume = consume };
    try reopen(location, &lease);
    return location;
}

fn find(context: *anyopaque, device: Controller) !?u8 {
    const alias = try physmap.uncachedDevicePage(device.Bar);
    var reclaimable = true;
    defer if (reclaimable) physmap.restoreDevicePage(alias);
    const aperture = layout.PHYSMAP_BASE + device.Bar;
    var pending = try readyPorts(aperture);
    var selected: ?u8 = null;
    while (pending != 0) {
        const index: u5 = @intCast(@ctz(pending));
        pending &= pending - 1;
        const port = (try registers.diskPort(aperture, index)) orelse continue;
        if (!try session.withDisk(device, aperture, port, &reclaimable, context, verifyCandidate)) continue;
        if (selected != null) return DiscoverError.AmbiguousBootVolume;
        selected = index;
    }
    return selected;
}

fn reopen(location: Location, lease: *Lease) !void {
    const device = (try ahci.discover.pci.inspect(pci.source(), location.Address)) orelse return StorageError.BootDeviceChanged;
    const alias = try physmap.uncachedDevicePage(device.Bar);
    var reclaimable = true;
    defer if (reclaimable) physmap.restoreDevicePage(alias);
    const aperture = layout.PHYSMAP_BASE + device.Bar;
    const index = std.math.cast(u5, location.Port) orelse return StorageError.BootDeviceChanged;
    if ((try readyPorts(aperture)) & (@as(u32, 1) << index) == 0) return StorageError.BootDeviceChanged;
    const port = (try registers.diskPort(aperture, index)) orelse return StorageError.BootDeviceChanged;
    if (!try session.withDisk(device, aperture, port, &reclaimable, lease, verifyAndRead)) return StorageError.BootDeviceChanged;
}

fn readyPorts(aperture: u64) StorageError!u32 {
    if (registers.read(aperture, values.GHC) & values.AHCI_ENABLE == 0 or registers.read(aperture, values.CAP2) & values.BIOS_HANDOFF != 0)
        return StorageError.UnsupportedAhciController;
    return registers.ports(aperture);
}

fn verifyCandidate(context: *anyopaque, disk: *Disk) !bool {
    const expected: *const Volume = @ptrCast(@alignCast(context));
    return identity.compare(expected.*, disk);
}

fn verifyAndRead(context: *anyopaque, disk: *Disk) !bool {
    const lease: *const Lease = @ptrCast(@alignCast(context));
    if (!try identity.compare(lease.Expected, disk)) return false;
    try lease.Consume(lease.Context, disk);
    return true;
}
