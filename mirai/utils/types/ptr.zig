//! Pointer conversion utilities

pub inline fn of(comptime T: type, addr: u64) *T {
    return @as(*T, @ptrFromInt(addr));
}

pub inline fn of_const(comptime T: type, addr: u64) *const T {
    return @as(*const T, @ptrFromInt(addr));
}

pub inline fn to_addr(p: anytype) u64 {
    return @intFromPtr(p);
}
