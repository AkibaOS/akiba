//! Test Native Discovery Against Every Ready ATA Candidate

const ahci = @import("shared").ahci;
const guard = @import("asm").interrupts.guard;
const layout = @import("common").constants.memory.layout;
const pci = @import("tests").guest.ahci.pci;
const physmap = @import("mirai").kagami.tables.physmap;
const probe = @import("tests").guest.ahci.probe;
const registers = @import("tests").guest.ahci.registers;
const values = @import("tests").guest.constants.ahci.registers;

const Controller = ahci.types.discover.controller.Controller;
const DiscoverError = ahci.errors.discover.selection.DiscoverError;
const Location = ahci.types.discover.selection.Location;
const ProbeError = @import("tests").guest.errors.ahci.transfer.ProbeError;
const Volume = @import("shared").boot.types.volume.Volume;

pub fn locate(expected: Volume) !Location {
    const flags = guard.acquire();
    defer guard.release(flags);
    var volume = expected;
    return (try ahci.discover.selection.unique(pci.source(), .{ .Context = &volume, .Find = find })) orelse
        ProbeError.AhciBootVolumeMismatch;
}

fn find(context: *anyopaque, device: Controller) !?u8 {
    const expected: *const Volume = @ptrCast(@alignCast(context));
    const alias = try physmap.uncachedDevicePage(device.Bar);
    var reclaimable = true;
    defer if (reclaimable) physmap.restoreDevicePage(alias);
    const aperture = layout.PHYSMAP_BASE + device.Bar;
    if (registers.read(aperture, values.GHC) & values.AHCI_ENABLE == 0 or registers.read(aperture, values.CAP2) & values.BIOS_HANDOFF != 0)
        return ProbeError.UnsupportedAhciController;

    var pending = try registers.ports(aperture);
    var selected: ?u8 = null;
    while (pending != 0) {
        const index: u5 = @intCast(@ctz(pending));
        pending &= pending - 1;
        const sata = (try registers.diskPort(aperture, index)) orelse continue;
        if (!try probe.match(device, aperture, sata, &reclaimable, expected.*)) continue;
        if (selected != null) return DiscoverError.AmbiguousBootVolume;
        selected = index;
    }
    return selected;
}
