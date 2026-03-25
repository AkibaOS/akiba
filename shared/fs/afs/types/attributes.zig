//! AFS Attribute Types

const constants = @import("../constants/constants.zig");
const volume = @import("volume.zig");

const ChannelInfo = volume.ChannelInfo;

pub const AttributeKey = extern struct {
    key_length: u16 = 0,
    padding: u16 = 0,
    node_id: u32 = 0,
    start_cell: u32 = 0,
    attribute_identity_length: u16 = 0,
    attribute_identity: [128]u16 = [_]u16{0} ** 128,
};

pub const AttributeInlineRecord = extern struct {
    record_type: u32 = 0,
    reserved: [4]u8 = [_]u8{0} ** 4,
    data_size: u32 = 0,
    data: [constants.sizes.attribute_inline_data_max]u8 = [_]u8{0} ** constants.sizes.attribute_inline_data_max,
};

pub const AttributeChannelRecord = extern struct {
    record_type: u32 = 0,
    reserved: u32 = 0,
    channel: ChannelInfo = .{},
};
