//! Integer conversion utilities

pub inline fn u3_of(value: anytype) u3 {
    return @as(u3, @truncate(value));
}

pub inline fn u8_of(value: anytype) u8 {
    return @as(u8, @truncate(value));
}

pub inline fn u32_of(value: anytype) u32 {
    return @as(u32, @truncate(value));
}

pub inline fn u64_of(value: anytype) u64 {
    return @as(u64, @intCast(value));
}

pub inline fn usize_of(value: anytype) usize {
    return @as(usize, @intCast(value));
}
