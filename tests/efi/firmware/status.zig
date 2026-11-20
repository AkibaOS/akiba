//! Firmware Boot Failure Status Regression

const std = @import("std");

const efi = @import("hikari").efi;
const hikari = @import("hikari");
const labels = @import("tests").efi.strings.firmware.handoff;
const output = @import("tests").efi.firmware.run;

const base = efi.types.base;
const codes = efi.constants.status;
const convention = efi.constants.convention.CALLING_CONVENTION;
const Console = efi.types.protocols.output.SimpleTextOutputProtocol;

pub fn run(system: *const efi.types.services.system.SystemTable) void {
    var services = system.BootServices.*;
    services.LocateProtocol = unavailable;
    var console = system.ConsoleOutput.*;
    console.ClearScreen = clear;
    console.OutputString = print;
    var wrapped = system.*;
    wrapped.BootServices = &services;
    wrapped.ConsoleOutput = &console;

    const actual = std.os.uefi.system_table;
    std.os.uefi.system_table = @ptrCast(&wrapped);
    const status = hikari.sequence.entry.run();
    std.os.uefi.system_table = actual;
    output.require(@intFromEnum(status) == codes.UNSUPPORTED, labels.BOOT_FAILURE_STATUS);
}

fn unavailable(_: *align(8) const base.GUID, _: ?*anyopaque, interface: *?*anyopaque) callconv(convention) base.Status {
    interface.* = null;
    return codes.NOT_FOUND;
}

fn clear(_: *Console) callconv(convention) base.Status {
    return codes.SUCCESS;
}

fn print(_: *Console, _: [*:0]const base.Char16) callconv(convention) base.Status {
    return codes.SUCCESS;
}
