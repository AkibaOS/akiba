//! Opt In To A Hosted Firmware Diagnostic Viewport

const display = @import("tests").firmware.display;
const efi = @import("hikari").efi;
const phase = @import("tests").phase;
const serial = @import("tests").firmware.serial;

pub fn start(services: *efi.types.services.boot.BootServices) !void {
    if (!phase.config.liveEnabled()) return;
    if (!serial.attach() or !serial.send(services, &phase.constants.live.READY)) return error.FirmwareLiveGreetingFailed;
    var bytes: [phase.constants.live.OFFER_BYTES]u8 = undefined;
    if (!serial.receive(services, &bytes)) return error.FirmwareLiveOfferMissing;
    const offer = phase.live.decodeOffer(&bytes) orelse return error.InvalidFirmwareLiveOffer;
    if (offer.Ticket.Scenario != .Firmware) return error.InvalidFirmwareLiveScenario;
    try display.start(services, offer);
    const acknowledgement = phase.live.encodeAcknowledgement(offer.Ticket);
    if (!serial.send(services, &acknowledgement)) return error.FirmwareLiveAcknowledgementFailed;
}
