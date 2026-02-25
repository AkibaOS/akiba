//! Bitmap Operations

pub fn set_bit(bitmap: []u8, bit_index: u64) void {
    const byte_index = bit_index / 8;
    const bit_offset: u3 = @truncate(bit_index % 8);
    if (byte_index < bitmap.len) {
        bitmap[byte_index] |= @as(u8, 1) << bit_offset;
    }
}

pub fn clear_bit(bitmap: []u8, bit_index: u64) void {
    const byte_index = bit_index / 8;
    const bit_offset: u3 = @truncate(bit_index % 8);
    if (byte_index < bitmap.len) {
        bitmap[byte_index] &= ~(@as(u8, 1) << bit_offset);
    }
}

pub fn test_bit(bitmap: []const u8, bit_index: u64) bool {
    const byte_index = bit_index / 8;
    const bit_offset: u3 = @truncate(bit_index % 8);
    if (byte_index < bitmap.len) {
        return (bitmap[byte_index] & (@as(u8, 1) << bit_offset)) != 0;
    }
    return true;
}

pub fn set_range(bitmap: []u8, start_bit: u64, count: u64) void {
    var bit_index = start_bit;
    const end_bit = start_bit + count;
    while (bit_index < end_bit) : (bit_index += 1) {
        set_bit(bitmap, bit_index);
    }
}

pub fn clear_range(bitmap: []u8, start_bit: u64, count: u64) void {
    var bit_index = start_bit;
    const end_bit = start_bit + count;
    while (bit_index < end_bit) : (bit_index += 1) {
        clear_bit(bitmap, bit_index);
    }
}

pub fn find_first_clear(bitmap: []const u8, start_bit: u64, max_bit: u64) ?u64 {
    var bit_index = start_bit;
    while (bit_index < max_bit) : (bit_index += 1) {
        if (!test_bit(bitmap, bit_index)) {
            return bit_index;
        }
    }
    return null;
}

pub fn find_contiguous_clear(bitmap: []const u8, start_bit: u64, max_bit: u64, count: u64) ?u64 {
    var bit_index = start_bit;
    while (bit_index + count <= max_bit) {
        var found = true;
        var check_index: u64 = 0;
        while (check_index < count) : (check_index += 1) {
            if (test_bit(bitmap, bit_index + check_index)) {
                found = false;
                bit_index += check_index + 1;
                break;
            }
        }
        if (found) {
            return bit_index;
        }
    }
    return null;
}

pub fn count_clear_bits(bitmap: []const u8, max_bit: u64) u64 {
    var count: u64 = 0;
    var bit_index: u64 = 0;
    while (bit_index < max_bit) : (bit_index += 1) {
        if (!test_bit(bitmap, bit_index)) {
            count += 1;
        }
    }
    return count;
}