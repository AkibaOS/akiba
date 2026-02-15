//! String comparison utilities

pub inline fn equals(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |ac, bc| {
        if (ac != bc) return false;
    }
    return true;
}

pub inline fn starts_with(str: []const u8, prefix: []const u8) bool {
    if (str.len < prefix.len) return false;
    return equals(str[0..prefix.len], prefix);
}
