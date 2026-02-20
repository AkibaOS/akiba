//! Attachment management

const attachment_limits = @import("../common/limits/attachment.zig");

pub const Type = enum {
    Unit,
    Device,
    Closed,
};

pub const DeviceType = enum {
    Source,
    Stream,
    Trace,
    Void,
    Chaos,
    Zero,
    Console,
};

pub const Attachment = struct {
    attachment_type: Type = .Closed,

    location: [attachment_limits.MAX_LOCATION_LENGTH]u8 = undefined,
    location_len: usize = 0,
    position: u64 = 0,
    unit_size: u64 = 0,
    buffer: ?[]u8 = null,
    flags: u32 = 0,
    dirty: bool = false,

    device_type: ?DeviceType = null,
};
