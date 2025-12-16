//! String utilities

const kata_mod = @import("../kata/kata.zig");

/// Copy null-terminated string from user space to kernel buffer
pub fn copy_string_from_user(_: *kata_mod.Kata, dest: []u8, user_ptr: u64) !usize {
    // TODO: Validate user pointer properly
    const src = @as([*:0]const u8, @ptrFromInt(user_ptr));
    var len: usize = 0;
    while (src[len] != 0 and len < dest.len) : (len += 1) {
        dest[len] = src[len];
    }
    return len;
}

/// Compare two strings for equality
pub fn strings_equal(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    var i: usize = 0;
    while (i < a.len) : (i += 1) {
        if (a[i] != b[i]) return false;
    }
    return true;
}
