//! Memory utilities

pub fn copy(dest: []u8, src: []const u8) void {
    const len = @min(dest.len, src.len);
    for (0..len) |i| {
        dest[i] = src[i];
    }
}

pub fn zero(buf: []u8) void {
    for (buf) |*b| {
        b.* = 0;
    }
}

pub fn equals(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |ac, bc| {
        if (ac != bc) return false;
    }
    return true;
}
