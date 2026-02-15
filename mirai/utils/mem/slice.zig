//! Slice and pointer utilities

pub inline fn from_ptr(comptime T: type, ptr: u64, len: usize) []T {
    return @as([*]T, @ptrFromInt(ptr))[0..len];
}

pub inline fn from_ptr_const(comptime T: type, ptr: u64, len: usize) []const T {
    return @as([*]const T, @ptrFromInt(ptr))[0..len];
}

pub inline fn byte_ptr(ptr: u64) [*]u8 {
    return @as([*]u8, @ptrFromInt(ptr));
}

pub inline fn byte_ptr_const(ptr: u64) [*]const u8 {
    return @as([*]const u8, @ptrFromInt(ptr));
}

pub inline fn null_term_ptr(ptr: u64) [*:0]const u8 {
    return @as([*:0]const u8, @ptrFromInt(ptr));
}

pub inline fn typed_ptr(comptime T: type, ptr: u64) [*]T {
    return @as([*]T, @ptrFromInt(ptr));
}

pub inline fn typed_ptr_const(comptime T: type, ptr: u64) [*]const T {
    return @as([*]const T, @ptrFromInt(ptr));
}
