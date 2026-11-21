//! Revalidate The Selected ATA Port Without Attaching DMA

const std = @import("std");

const discover = @import("shared").ahci.discover.pci;
const guard = @import("asm").interrupts.guard;
const layout = @import("common").constants.memory.layout;
const pci = @import("mirai").device.pci.configuration;
const physmap = @import("mirai").kagami.tables.physmap;
const registers = @import("mirai").device.ahci.registers;
const values = @import("mirai").device.constants.ahci.registers;

const AttachmentError = @import("mirai").device.errors.ahci.attachment.AttachmentError;
const Location = @import("shared").ahci.types.discover.selection.Location;

pub fn readyPorts(aperture: u64) AttachmentError!u32 {
    if (registers.read(aperture, values.GHC) & values.AHCI_ENABLE == 0 or registers.read(aperture, values.CAP2) & values.BIOS_HANDOFF != 0)
        return AttachmentError.UnsupportedAhciController;
    return registers.ports(aperture);
}

pub fn exactPort(aperture: u64, port: u8) AttachmentError!u64 {
    const index = std.math.cast(u5, port) orelse return AttachmentError.BootDeviceChanged;
    if ((try readyPorts(aperture)) & (@as(u32, 1) << index) == 0) return AttachmentError.BootDeviceChanged;
    return (try registers.diskPort(aperture, index)) orelse return AttachmentError.BootDeviceChanged;
}

pub fn verifyDetached(location: Location) !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    const device = (try discover.inspect(pci.source(), location.Address)) orelse return AttachmentError.BootDeviceChanged;
    const alias = try physmap.uncachedDevicePage(device.Bar);
    defer physmap.restoreDevicePage(alias);
    const sata = try exactPort(layout.PHYSMAP_BASE + device.Bar, location.Port);
    if (!registers.detached(sata)) return AttachmentError.AhciPortBusy;
}
