//! Verify Menu Summary And Menu-Ready Epoch

const std = @import("std");

const date = @import("tests").screen.date;
const limits = @import("tests").phase.constants.menu;
const types = @import("tests").phase.types.menu;

pub fn encodeOffer(offer: types.Offer) ?types.OfferFrame {
    if (!valid(offer)) return null;
    var frame: types.OfferFrame = undefined;
    @memcpy(frame[0..limits.EPOCH_OFFSET], &limits.OFFER);
    std.mem.writeInt(u64, frame[limits.EPOCH_OFFSET..limits.PASSED_OFFSET], offer.Epoch, .little);
    std.mem.writeInt(u32, frame[limits.PASSED_OFFSET..limits.DATE_OFFSET], offer.Passed, .little);
    @memcpy(frame[limits.DATE_OFFSET..], &offer.Date);
    return frame;
}

pub fn decodeOffer(frame: []const u8) ?types.Offer {
    if (frame.len != limits.OFFER_BYTES or !std.mem.eql(u8, frame[0..limits.EPOCH_OFFSET], &limits.OFFER)) return null;
    const offer: types.Offer = .{
        .Epoch = std.mem.readInt(u64, frame[limits.EPOCH_OFFSET..limits.PASSED_OFFSET], .little),
        .Passed = std.mem.readInt(u32, frame[limits.PASSED_OFFSET..limits.DATE_OFFSET], .little),
        .Date = frame[limits.DATE_OFFSET..limits.OFFER_BYTES].*,
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

fn valid(offer: types.Offer) bool {
    return offer.Epoch != 0 and offer.Passed != 0 and date.valid(&offer.Date);
}
