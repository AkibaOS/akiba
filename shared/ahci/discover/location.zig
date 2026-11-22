//! Address Free AHCI Port Location Codec

const Location = @import("shared").ahci.types.discover.selection.Location;

pub fn encode(location: Location) u64 {
    return @as(u64, @as(u16, @bitCast(location.Address))) << @bitSizeOf(u8) | location.Port;
}

pub fn decode(value: u64) !Location {
    if (value >> (@bitSizeOf(u16) + @bitSizeOf(u8)) != 0) return error.InvalidArgument;
    return .{ .Address = @bitCast(@as(u16, @intCast(value >> @bitSizeOf(u8)))), .Port = @truncate(value) };
}
