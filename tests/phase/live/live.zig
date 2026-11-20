//! Fresh Live Context And Verified Phase Progress

const std = @import("std");

const date = @import("tests").phase.date;
const limits = @import("tests").phase.constants.live.frame;
const menu = @import("tests").phase.menu;
const types = @import("tests").phase.types.live.frames;
const Scenario = @import("tests").phase.types.scenario.Scenario;
const Ticket = @import("tests").phase.types.ticket.Ticket;
const Work = @import("tests").phase.types.work.Work;

pub fn encodeOffer(offer: types.Offer) ?types.OfferFrame {
    if (!valid(offer)) return null;
    var frame: types.OfferFrame = undefined;
    @memcpy(frame[0..limits.EPOCH_OFFSET], &limits.OFFER);
    std.mem.writeInt(u64, frame[limits.EPOCH_OFFSET..limits.SCENARIO_OFFSET], offer.Ticket.Epoch, .little);
    frame[limits.SCENARIO_OFFSET] = @intFromEnum(offer.Ticket.Scenario);
    frame[limits.FAILED_OFFSET] = offer.FailedMask;
    frame[limits.INTERRUPTED_OFFSET] = offer.InterruptedMask;
    std.mem.writeInt(u16, frame[limits.STANDARD_OFFSET..limits.CHECKS_OFFSET], offer.StandardCompleted, .little);
    std.mem.writeInt(u32, frame[limits.CHECKS_OFFSET..limits.DATE_OFFSET], offer.VerifiedChecks, .little);
    @memcpy(frame[limits.DATE_OFFSET..limits.WORK_OFFSET], &offer.Date);
    frame[limits.WORK_OFFSET..].* = offer.Work.encode();
    return frame;
}

pub fn decodeOffer(frame: []const u8) ?types.Offer {
    if (frame.len != limits.OFFER_BYTES or !std.mem.eql(u8, frame[0..limits.EPOCH_OFFSET], &limits.OFFER)) return null;
    const selected = std.enums.fromInt(Scenario, frame[limits.SCENARIO_OFFSET]) orelse return null;
    const offer: types.Offer = .{
        .Ticket = .{ .Epoch = std.mem.readInt(u64, frame[limits.EPOCH_OFFSET..limits.SCENARIO_OFFSET], .little), .Scenario = selected },
        .Date = frame[limits.DATE_OFFSET..limits.WORK_OFFSET].*,
        .Work = Work.decode(frame[limits.WORK_OFFSET..limits.OFFER_BYTES]),
        .FailedMask = frame[limits.FAILED_OFFSET],
        .InterruptedMask = frame[limits.INTERRUPTED_OFFSET],
        .StandardCompleted = std.mem.readInt(u16, frame[limits.STANDARD_OFFSET..limits.CHECKS_OFFSET], .little),
        .VerifiedChecks = std.mem.readInt(u32, frame[limits.CHECKS_OFFSET..limits.DATE_OFFSET], .little),
    };
    return if (valid(offer)) offer else null;
}

pub fn encodeAcknowledgement(ticket: Ticket) types.Acknowledgement {
    var frame: types.Acknowledgement = undefined;
    @memcpy(frame[0..limits.EPOCH_OFFSET], &limits.ACKNOWLEDGEMENT);
    std.mem.writeInt(u64, frame[limits.EPOCH_OFFSET..limits.SCENARIO_OFFSET], ticket.Epoch, .little);
    frame[limits.SCENARIO_OFFSET] = @intFromEnum(ticket.Scenario);
    return frame;
}

pub fn acknowledges(ticket: Ticket, bytes: []const u8) bool {
    return ticket.Epoch != 0 and std.mem.eql(u8, bytes, &encodeAcknowledgement(ticket));
}

pub fn preceding(selected: Scenario) u8 {
    return menu.phaseBit(selected) - 1;
}

pub fn completed(visited: u8, standard: u16, interrupted: u8) usize {
    const standard_bit = menu.phaseBit(.Standard);
    const standard_units: usize = if (visited & standard_bit != 0) standard else 0;
    return standard_units + @popCount(visited & ~standard_bit & ~interrupted);
}

fn valid(offer: types.Offer) bool {
    if (offer.Ticket.Epoch == 0 or !date.valid(&offer.Date) or offer.StandardCompleted > limits.STANDARD_UNITS) return false;
    const previous = preceding(offer.Ticket.Scenario);
    if (offer.FailedMask & ~previous != 0 or offer.InterruptedMask & ~offer.FailedMask != 0 or
        (offer.VerifiedChecks == 0) != (previous == offer.FailedMask)) return false;
    if (!offer.Work.valid() or offer.Work.Verified < offer.VerifiedChecks or offer.Work.Verified == offer.Work.Planned) return false;
    if (previous == 0) return offer.StandardCompleted == 0 and offer.Work.Verified == 0;
    return offer.FailedMask & menu.phaseBit(.Standard) != 0 or offer.StandardCompleted == limits.STANDARD_UNITS;
}
