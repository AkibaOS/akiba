//! Choose One Real EFI Application On The Diagnostic Disk

const std = @import("std");

const assembly = @import("hikari").assembly;
const efi = @import("hikari").efi;
const phase = @import("tests").phase;
const ports = @import("common").constants.serial.ports;
const uart = @import("tests").efi.serial;
const Role = phase.types.boot.frame.Role;
const status = efi.constants.status.codes;

pub fn main() std.os.uefi.Status {
    const boot_services = std.os.uefi.system_table.boot_services orelse return @enumFromInt(status.UNSUPPORTED);
    const parent: efi.types.base.Handle = @ptrCast(std.os.uefi.handle);
    return @enumFromInt(start(@ptrCast(boot_services), parent));
}

fn start(services: *efi.types.services.boot.BootServices, parent: efi.types.base.Handle) efi.types.base.Status {
    if (!uart.attach(ports.COM4) or !uart.send(services, ports.COM4, &phase.constants.boot.frame.READY)) return status.DEVICE_ERROR;
    var offer: phase.types.boot.frame.Frame = undefined;
    if (!uart.receive(services, ports.COM4, &offer)) return status.DEVICE_ERROR;
    const selection = phase.boot.decode(&offer, .Offer) orelse return status.INVALID_PARAMETER;
    const acknowledgement = phase.boot.encode(selection, .Acknowledgement) orelse return status.INVALID_PARAMETER;
    const executable = image(selection.Role);
    var child: efi.types.base.Handle = undefined;
    const loaded = services.LoadImage(false, parent, null, executable.ptr, executable.len, &child);
    if (loaded == status.SECURITY_VIOLATION) return discard(services, child, loaded);
    if (loaded != status.SUCCESS) return loaded;
    if (!uart.send(services, ports.COM4, &acknowledgement)) return discard(services, child, status.DEVICE_ERROR);
    var exit_bytes: usize = 0;
    const result = services.StartImage(child, &exit_bytes, null);
    return if (result == status.SUCCESS) status.LOAD_ERROR else result;
}

fn discard(services: *efi.types.services.boot.BootServices, child: efi.types.base.Handle, failure: efi.types.base.Status) efi.types.base.Status {
    const unloaded = services.UnloadImage(child);
    return if (unloaded == status.SUCCESS) failure else unloaded;
}

fn image(role: Role) []const u8 {
    return switch (role) {
        .Diagnostic => @embedFile("diagnostic"),
        .Firmware => @embedFile("firmware"),
        .Menu => @embedFile("menu"),
        .Ordinary => @embedFile("ordinary"),
    };
}

pub const panic = std.debug.FullPanic(haltOnPanic);

fn haltOnPanic(_: []const u8, _: ?usize) noreturn {
    assembly.halt.haltLoop();
}
