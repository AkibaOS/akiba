//! Select And Revalidate One Native Bootstrap Disk

const ahci = @import("shared").ahci;
const attachment = @import("mirai").device.ahci.attachment;
const guard = @import("asm").interrupts.guard;
const identity = @import("mirai").bootstrap.storage.identity;
const layout = @import("common").constants.memory.layout;
const pci = @import("mirai").device.pci.configuration;
const physmap = @import("mirai").kagami.tables.physmap;
const quarantine = @import("mirai").device.ahci.quarantine;
const session = @import("mirai").bootstrap.storage.session;

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
    defer if (reclaimable) physmap.restoreDevicePage(alias) else quarantine.retain(device.Address);
    const aperture = layout.PHYSMAP_BASE + device.Bar;
    var pending = try attachment.readyPorts(aperture);
    var selected: ?u8 = null;
    while (pending != 0) {
        const index: u5 = @intCast(@ctz(pending));
        pending &= pending - 1;
        const port = (try attachment.diskPort(device, aperture, index, &reclaimable)) orelse continue;
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
    defer if (reclaimable) physmap.restoreDevicePage(alias) else quarantine.retain(device.Address);
    const aperture = layout.PHYSMAP_BASE + device.Bar;
    const port = try attachment.exactPort(aperture, location.Port);
    if (!try session.withDisk(device, aperture, port, &reclaimable, lease, verifyAndRead)) return StorageError.BootDeviceChanged;
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
