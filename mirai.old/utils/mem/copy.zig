//! Memory copy utilities

pub inline fn bytes(dest: []u8, src: []const u8) void {
    @memcpy(dest[0..src.len], src);
}

pub inline fn bytes_n(dest: []u8, src: []const u8, n: usize) void {
    @memcpy(dest[0..n], src[0..n]);
}

pub inline fn fill(dest: []u8, value: u8) void {
    @memset(dest, value);
}

pub inline fn zero(dest: []u8) void {
    @memset(dest, 0);
}

pub inline fn from_ptr(dest: []u8, src_ptr: u64, len: usize) void {
    const src = @as([*]const u8, @ptrFromInt(src_ptr));
    @memcpy(dest[0..len], src[0..len]);
}

pub inline fn to_ptr(dest_ptr: u64, src: []const u8) void {
    const dest = @as([*]u8, @ptrFromInt(dest_ptr));
    @memcpy(dest[0..src.len], src);
}
