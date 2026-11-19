//! Dedicated EFI Diagnostic Final Menu

const std = @import("std");

const assembly = @import("hikari").assembly;
const efi = @import("hikari").efi;
const phase = @import("tests").phase;

pub const choice = @import("choice.zig");
pub const constants = @import("constants/constants.zig");
pub const display = @import("display.zig");
pub const serial = @import("serial.zig");
pub const strings = @import("strings/strings.zig");

const status = efi.constants.status;

pub fn main() void {
    const system_table = std.os.uefi.system_table;
    if (system_table.boot_services) |boot_services| {
        const services: *efi.types.services.boot.BootServices = @ptrCast(boot_services);
        run(services) catch |failure| serial.reportFailure(services, @errorName(failure));
    }
    assembly.halt.haltLoop();
}

pub const panic = std.debug.FullPanic(haltOnPanic);

fn haltOnPanic(_: []const u8, _: ?usize) noreturn {
    assembly.halt.haltLoop();
}

fn run(services: *efi.types.services.boot.BootServices) !void {
    const input = try phase.keyboard.locate(services);
    if (!serial.attach() or !serial.send(services, &phase.constants.menu.READY)) return error.MenuGreetingFailed;
    var bytes: [phase.constants.menu.OFFER_BYTES]u8 = undefined;
    if (!serial.receive(services, &bytes)) return error.MenuOfferMissing;
    const offer = phase.menu.decodeOffer(&bytes) orelse return error.InvalidMenuOffer;

    if (input.Reset(input, false) != status.SUCCESS) return error.MenuInputResetFailed;
    if (!display.show(services, offer)) return error.MenuRenderFailed;
    const action = try choice.readyAndWait(services, input, offer.Epoch);
    const message = phase.action.encode(offer.Epoch, action) orelse return error.InvalidMenuEpoch;
    if (!serial.send(services, &message)) return error.MenuActionTransmissionFailed;
}
