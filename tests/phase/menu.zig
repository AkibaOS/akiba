//! Verify Menu Summary And Menu-Ready Epoch

const std = @import("std");

const date = @import("tests").screen.date;
const limits = @import("tests").phase.constants.menu;
const types = @import("tests").phase.types.menu;
const Scenario = @import("tests").types.scenario.Scenario;

pub fn encodeOffer(offer: types.Offer) ?types.OfferFrame {
    if (!valid(offer)) return null;
    var frame: types.OfferFrame = undefined;
    @memcpy(frame[0..limits.EPOCH_OFFSET], &limits.OFFER);
    std.mem.writeInt(u64, frame[limits.EPOCH_OFFSET..limits.PASSED_OFFSET], offer.Epoch, .little);
    std.mem.writeInt(u32, frame[limits.PASSED_OFFSET..limits.DATE_OFFSET], offer.Passed, .little);
    @memcpy(frame[limits.DATE_OFFSET..limits.FAILED_OFFSET], &offer.Date);
    frame[limits.FAILED_OFFSET] = offer.FailedMask;
    frame[limits.INTERRUPTED_OFFSET] = offer.InterruptedMask;
    return frame;
}

pub fn decodeOffer(frame: []const u8) ?types.Offer {
    if (frame.len != limits.OFFER_BYTES or !std.mem.eql(u8, frame[0..limits.EPOCH_OFFSET], &limits.OFFER)) return null;
    const offer: types.Offer = .{
        .Epoch = std.mem.readInt(u64, frame[limits.EPOCH_OFFSET..limits.PASSED_OFFSET], .little),
        .Passed = std.mem.readInt(u32, frame[limits.PASSED_OFFSET..limits.DATE_OFFSET], .little),
        .Date = frame[limits.DATE_OFFSET..limits.FAILED_OFFSET].*,
        .FailedMask = frame[limits.FAILED_OFFSET],
        .InterruptedMask = frame[limits.INTERRUPTED_OFFSET],
    };
    return if (valid(offer)) offer else null;
}

pub fn encodeArmed(epoch: u64) types.ArmedFrame {
    var frame: types.ArmedFrame = undefined;
    @memcpy(frame[0..limits.EPOCH_OFFSET], &limits.ARMED);
    std.mem.writeInt(u64, frame[limits.EPOCH_OFFSET..], epoch, .little);
    return frame;
}

pub fn isArmed(epoch: u64, bytes: []const u8) bool {
    return epoch != 0 and std.mem.eql(u8, bytes, &encodeArmed(epoch));
}

pub fn phaseBit(selected: Scenario) u8 {
    return @as(u8, 1) << @intCast(@intFromEnum(selected));
}

pub fn phaseStatus(offer: types.Offer, selected: Scenario) types.PhaseStatus {
    const bit = phaseBit(selected);
    if (offer.InterruptedMask & bit != 0) return .Incomplete;
    if (offer.FailedMask & bit != 0) return .Failed;
    return .Passed;
}

pub fn completedPhases(offer: types.Offer) usize {
    return limits.PHASE_COUNT -| @popCount(offer.InterruptedMask);
}

fn valid(offer: types.Offer) bool {
    const all_failed = offer.FailedMask == limits.PHASE_MASK;
    return offer.Epoch != 0 and (offer.Passed == 0) == all_failed and
        offer.FailedMask & ~limits.PHASE_MASK == 0 and offer.InterruptedMask & ~offer.FailedMask == 0 and
        date.valid(&offer.Date);
}
