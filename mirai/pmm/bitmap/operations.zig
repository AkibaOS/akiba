//! Bitmap Operations

pub fn setBit(bitmap: []u8, bit_index: u64) void {
    const byte_index = bit_index / @bitSizeOf(u8);
    const bit_offset: u3 = @truncate(bit_index % @bitSizeOf(u8));
    if (byte_index < bitmap.len) {
        bitmap[byte_index] |= @as(u8, 1) << bit_offset;
    }
}

pub fn clearBit(bitmap: []u8, bit_index: u64) void {
    const byte_index = bit_index / @bitSizeOf(u8);
    const bit_offset: u3 = @truncate(bit_index % @bitSizeOf(u8));
    if (byte_index < bitmap.len) {
        bitmap[byte_index] &= ~(@as(u8, 1) << bit_offset);
    }
}

pub fn testBit(bitmap: []const u8, bit_index: u64) bool {
    const byte_index = bit_index / @bitSizeOf(u8);
    const bit_offset: u3 = @truncate(bit_index % @bitSizeOf(u8));
    if (byte_index < bitmap.len) {
        return (bitmap[byte_index] & (@as(u8, 1) << bit_offset)) != 0;
    }
    return true;
}

pub fn setRange(bitmap: []u8, start_bit: u64, count: u64) void {
    var bit_index = start_bit;
    const end_bit = start_bit + count;
    while (bit_index < end_bit) : (bit_index += 1) {
        setBit(bitmap, bit_index);
    }
}

pub fn clearRange(bitmap: []u8, start_bit: u64, count: u64) void {
    var bit_index = start_bit;
    const end_bit = start_bit + count;
    while (bit_index < end_bit) : (bit_index += 1) {
        clearBit(bitmap, bit_index);
    }
}

pub fn findFirstClear(bitmap: []const u8, start_bit: u64, max_bit: u64) ?u64 {
    var bit_index = start_bit;
    while (bit_index < max_bit) : (bit_index += 1) {
        if (!testBit(bitmap, bit_index)) {
            return bit_index;
        }
    }
    return null;
}

pub fn findContiguousClear(bitmap: []const u8, start_bit: u64, max_bit: u64, count: u64) ?u64 {
    var bit_index = start_bit;
    while (bit_index + count <= max_bit) {
        var found = true;
        var check_index: u64 = 0;
        while (check_index < count) : (check_index += 1) {
            if (testBit(bitmap, bit_index + check_index)) {
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

pub fn countClearBits(bitmap: []const u8, max_bit: u64) u64 {
    var count: u64 = 0;
    var bit_index: u64 = 0;
    while (bit_index < max_bit) : (bit_index += 1) {
        if (!testBit(bitmap, bit_index)) {
            count += 1;
        }
    }
    return count;
}
