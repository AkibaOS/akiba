//! Dedicated EFI Diagnostic Final Menu

const std = @import("std");

const assembly = @import("hikari").assembly;
const efi = @import("hikari").efi;
const keyboard = @import("tests").efi.keyboard;
const menu = @import("tests").efi.menu;
const phase = @import("tests").phase;
const types = @import("tests").efi.types.menu;

const status = efi.constants.status.codes;

pub fn main() void {
    const system_table = std.os.uefi.system_table;
    if (system_table.boot_services) |boot_services| {
        const services: *efi.types.services.boot.BootServices = @ptrCast(boot_services);
        run(services) catch |failure| menu.serial.reportFailure(services, @errorName(failure));
    }
    assembly.halt.haltLoop();
}

pub const panic = std.debug.FullPanic(haltOnPanic);

fn haltOnPanic(_: []const u8, _: ?usize) noreturn {
    assembly.halt.haltLoop();
}

fn run(services: *efi.types.services.boot.BootServices) !void {
    const input = try keyboard.locate(services);
    if (!menu.serial.attach() or !menu.serial.send(services, &phase.constants.menu.READY)) return error.MenuGreetingFailed;
    var bytes: [phase.constants.menu.OFFER_BYTES]u8 = undefined;
    if (!menu.serial.receive(services, &bytes)) return error.MenuOfferMissing;
    const offer = phase.menu.decodeOffer(&bytes) orelse return error.InvalidMenuOffer;

    if (input.Reset(input, false) != status.SUCCESS) return error.MenuInputResetFailed;
    const action = try waitForSelection(services, input, offer);
    const message = phase.action.encode(offer.Epoch, action) orelse return error.InvalidMenuEpoch;
    if (!menu.serial.send(services, &message)) return error.MenuActionTransmissionFailed;
}

fn waitForSelection(services: *efi.types.services.boot.BootServices, input: *keyboard.Input, offer: phase.types.menu.Offer) !phase.types.action.Action {
    var view: types.display.View = .{};
    const selection = if (menu.display.show(services, offer, &view)) menu.choice.readyAndWait(services, input, offer.Epoch, &view) else error.MenuRenderFailed;
    const released = menu.display.release(services, &view);
    const action = try selection;
    if (!released) return error.MenuRenderReleaseFailed;
    return action;
}
