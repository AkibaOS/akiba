//! Observe Initial Device Signatures And Verify Detached ATA Ports

const std = @import("std");

const cpu = @import("asm").cpu;
const discover = @import("shared").ahci.discover.pci;
const guard = @import("asm").interrupts.guard;
const layout = @import("common").constants.memory.layout;
const limits = @import("mirai").device.constants.ahci.limits;
const pci = @import("mirai").device.pci.configuration;
const physmap = @import("mirai").kagami.tables.physmap;
const portspec = @import("shared").ahci.discover.port;
const quarantine = @import("mirai").device.ahci.quarantine;
const registers = @import("mirai").device.ahci.registers;
const session = @import("mirai").device.ahci.session;
const values = @import("mirai").device.constants.ahci.registers;

const AttachmentError = @import("mirai").device.errors.ahci.attachment.AttachmentError;
const Controller = @import("shared").ahci.types.discover.controller.Controller;
const Kind = @import("shared").ahci.types.discover.port.Kind;
const Location = @import("shared").ahci.types.discover.selection.Location;
const Slot = @import("mirai").device.types.ahci.slot.Slot;

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

pub fn diskPort(device: Controller, aperture: u64, index: u5, reclaimable: *bool) !?u64 {
    if (index >= values.MAPPED_PORTS) return AttachmentError.UnsupportedAhciPort;
    const port = aperture + values.PORT_BASE + @as(u64, index) * values.PORT_STRIDE;
    const link = registers.read(port, values.LINK);
    const signature = registers.read(port, values.SIGNATURE);
    if (!portspec.needsReceive(link, signature)) return registers.diskPort(aperture, index);
    if (!registers.detached(port)) return AttachmentError.AhciPortBusy;
    var observed: Kind = .Unverifiable;
    const disk = try session.withSlot(device, aperture, port, reclaimable, &observed, receive);
    return if (disk and observed == .AtaDisk) port else null;
}

pub fn verifyDetached(location: Location) !void {
    const flags = guard.acquire();
    defer guard.release(flags);
    if (quarantine.contains(location.Address)) return AttachmentError.AhciPortBusy;
    const device = (try discover.inspect(pci.source(), location.Address)) orelse return AttachmentError.BootDeviceChanged;
    const alias = try physmap.uncachedDevicePage(device.Bar);
    var reclaimable = true;
    defer if (reclaimable) physmap.restoreDevicePage(alias) else quarantine.retain(location.Address);
    const index = std.math.cast(u5, location.Port) orelse return AttachmentError.BootDeviceChanged;
    const aperture = layout.PHYSMAP_BASE + device.Bar;
    if ((try readyPorts(aperture)) & (@as(u32, 1) << index) == 0) return AttachmentError.BootDeviceChanged;
    const sata = (try diskPort(device, aperture, index, &reclaimable)) orelse return AttachmentError.BootDeviceChanged;
    if (!registers.detached(sata)) return AttachmentError.AhciPortBusy;
}

fn receive(context: *anyopaque, slot: Slot) !bool {
    const observed: *Kind = @ptrCast(@alignCast(context));
    for (0..limits.POLL_LIMIT) |_| {
        observed.* = portspec.classify(registers.read(slot.Port, values.LINK), registers.read(slot.Port, values.SIGNATURE));
        switch (observed.*) {
            .AtaDisk => return true,
            .PacketDevice => return false,
            .Empty => return AttachmentError.BootDeviceChanged,
            .Unverifiable => cpu.halt.pause(),
        }
    }
    return AttachmentError.UnsupportedAhciPort;
}
