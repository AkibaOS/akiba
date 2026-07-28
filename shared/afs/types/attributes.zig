//! AFS Attribute Types

const constants = @import("shared").afs.constants;
const volume = @import("shared").afs.types.volume;

const ChannelInfo = volume.ChannelInfo;

pub const AttributeKey = extern struct {
    KeyLength: u16 = 0,
    Padding: u16 = 0,
    NodeId: u32 = 0,
    StartCell: u32 = 0,
    AttributeIdentityLength: u16 = 0,
    AttributeIdentity: [128]u16 = [_]u16{0} ** 128,
};

pub const AttributeInlineRecord = extern struct {
    RecordType: u32 = 0,
    Reserved: [4]u8 = [_]u8{0} ** 4,
    DataSize: u32 = 0,
    Data: [constants.sizes.ATTRIBUTE_INLINE_DATA_MAX]u8 = [_]u8{0} ** constants.sizes.ATTRIBUTE_INLINE_DATA_MAX,
};

pub const AttributeChannelRecord = extern struct {
    RecordType: u32 = 0,
    Reserved: u32 = 0,
    Channel: ChannelInfo = .{},
};
