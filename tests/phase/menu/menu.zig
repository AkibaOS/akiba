//! Verify Menu Summary And Menu-Ready Epoch

const std = @import("std");

const date = @import("tests").screen.date;
const limits = @import("tests").phase.constants.menu;
const live = @import("tests").phase.live;
const progress = @import("tests").phase.constants.live;
const types = @import("tests").phase.types.menu;
const Scenario = @import("tests").phase.types.scenario.Scenario;
const Work = @import("tests").phase.types.work.Work;

pub fn encodeOffer(offer: types.Offer) ?types.OfferFrame {
    if (!valid(offer)) return null;
    var frame: types.OfferFrame = undefined;
    @memcpy(frame[0..limits.EPOCH_OFFSET], &limits.OFFER);
    std.mem.writeInt(u64, frame[limits.EPOCH_OFFSET..limits.PASSED_OFFSET], offer.Epoch, .little);
    std.mem.writeInt(u32, frame[limits.PASSED_OFFSET..limits.DATE_OFFSET], offer.Passed, .little);
    @memcpy(frame[limits.DATE_OFFSET..limits.FAILED_OFFSET], &offer.Date);
    frame[limits.FAILED_OFFSET] = offer.FailedMask;
    frame[limits.INTERRUPTED_OFFSET] = offer.InterruptedMask;
    std.mem.writeInt(u16, frame[limits.STANDARD_OFFSET..limits.WORK_OFFSET], offer.StandardCompleted, .little);
    frame[limits.WORK_OFFSET..].* = offer.Work.encode();
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
        .StandardCompleted = std.mem.readInt(u16, frame[limits.STANDARD_OFFSET..limits.WORK_OFFSET], .little),
        .Work = Work.decode(frame[limits.WORK_OFFSET..limits.OFFER_BYTES]),
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

pub fn encodeCountdown(epoch: u64, seconds: u8) ?types.CountdownFrame {
    if (epoch == 0 or !validCountdown(seconds)) return null;
    var frame: types.CountdownFrame = undefined;
    @memcpy(frame[0..limits.EPOCH_OFFSET], &limits.COUNTDOWN);
    std.mem.writeInt(u64, frame[limits.EPOCH_OFFSET..limits.ARMED_BYTES], epoch, .little);
    frame[limits.ARMED_BYTES] = seconds;
    return frame;
}

pub fn decodeCountdown(frame: []const u8, epoch: u64, previous: u8) ?u8 {
    if (epoch == 0 or frame.len != limits.COUNTDOWN_BYTES or
        !std.mem.eql(u8, frame[0..limits.EPOCH_OFFSET], &limits.COUNTDOWN)) return null;
    if (std.mem.readInt(u64, frame[limits.EPOCH_OFFSET..limits.ARMED_BYTES], .little) != epoch) return null;
    const seconds = frame[limits.ARMED_BYTES];
    return if (validCountdown(seconds) and seconds < previous) seconds else null;
}

fn validCountdown(seconds: u8) bool {
    return seconds > 0 and seconds < limits.COUNTDOWN_SECONDS;
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

pub fn completedUnits(offer: types.Offer) usize {
    return live.completed(limits.PHASE_MASK, offer.StandardCompleted, offer.InterruptedMask);
}

fn valid(offer: types.Offer) bool {
    const all_failed = offer.FailedMask == limits.PHASE_MASK;
    return offer.Epoch != 0 and (offer.Passed == 0) == all_failed and
        offer.Work.valid() and offer.Work.Verified >= offer.Passed and
        (offer.Work.Verified == offer.Work.Planned) == (offer.FailedMask == 0) and
        offer.FailedMask & ~limits.PHASE_MASK == 0 and offer.InterruptedMask & ~offer.FailedMask == 0 and
        offer.StandardCompleted <= progress.STANDARD_UNITS and
        (offer.FailedMask & phaseBit(.Standard) != 0 or offer.StandardCompleted == progress.STANDARD_UNITS) and
        date.valid(&offer.Date);
}
