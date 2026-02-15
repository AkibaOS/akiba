//! String copy utilities

const memory_limits = @import("../../common/limits/memory.zig");
const slice = @import("../mem/slice.zig");

pub fn from_kata(dest: []u8, kata_ptr: u64) !usize {
    if (!memory_limits.is_valid_kata_pointer(kata_ptr)) {
        return error.InvalidPointer;
    }

    const src = slice.null_term_ptr(kata_ptr);

    var len: usize = 0;
    while (src[len] != 0 and len < dest.len) : (len += 1) {
        dest[len] = src[len];
    }

    if (len >= dest.len and src[len] != 0) {
        return error.StringTooLong;
    }

    return len;
}
