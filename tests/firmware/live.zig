//! Opt In To A Hosted Firmware Diagnostic Viewport

const display = @import("tests").firmware.display;
const efi = @import("hikari").efi;
const phase = @import("tests").phase;
const ports = @import("common").constants.serial.ports;
const serial = @import("tests").firmware.serial;

var keyboard: ?*phase.keyboard.Input = null;
var boot_epoch: ?u64 = null;

pub fn start(services: *efi.types.services.boot.BootServices) !void {
    if (!phase.config.liveEnabled()) return;
    if (!serial.attach(ports.COM3) or !serial.send(services, ports.COM3, &phase.constants.live.READY)) return error.FirmwareLiveGreetingFailed;
    var bytes: [phase.constants.live.OFFER_BYTES]u8 = undefined;
    if (!serial.receive(services, ports.COM3, &bytes)) return error.FirmwareLiveOfferMissing;
    const offer = phase.live.decodeOffer(&bytes) orelse return error.InvalidFirmwareLiveOffer;
    if (offer.Ticket.Scenario != .Firmware) return error.InvalidFirmwareLiveScenario;
    keyboard = try prepareKeyboard(services);
    try display.start(services, offer, keyboard != null);
    const acknowledgement = phase.live.encodeAcknowledgement(offer.Ticket);
    if (!serial.send(services, ports.COM3, &acknowledgement)) return error.FirmwareLiveAcknowledgementFailed;
    boot_epoch = offer.Ticket.Epoch;
}

fn prepareKeyboard(services: *efi.types.services.boot.BootServices) !?*phase.keyboard.Input {
    if (!phase.config.cancellationEnabled()) return null;
    const input = phase.keyboard.locate(services) catch |failure| switch (failure) {
        error.MenuInputMissing, error.MenuKeyboardMissing => return null,
        else => return failure,
    };
    if (input.Reset(input, false) != efi.constants.status.SUCCESS) return error.FirmwareKeyboardResetFailed;
    return input;
}

pub fn pendingCancellation() !bool {
    if (boot_epoch == null) return false;
    return phase.keyboard.pressedEscape(keyboard orelse return false);
}

pub fn sendCancellation(services: *efi.types.services.boot.BootServices) bool {
    const epoch = boot_epoch orelse return false;
    const bytes = phase.action.encode(epoch, .Cancel) orelse return false;
    return serial.send(services, ports.COM3, &bytes);
}
