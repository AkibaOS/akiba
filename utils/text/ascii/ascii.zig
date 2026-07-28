//! ASCII Text Utilities

const CASE_DISTANCE: u8 = 'a' - 'A';

pub fn toUpper(character: u8) u8 {
    if (character >= 'a' and character <= 'z') {
        return character - CASE_DISTANCE;
    }
    return character;
}

pub fn equalsIgnoreCase(left: []const u8, right: []const u8) bool {
    if (left.len != right.len) {
        return false;
    }
    for (left, right) |left_character, right_character| {
        if (toUpper(left_character) != toUpper(right_character)) {
            return false;
        }
    }
    return true;
}

pub fn copyBounded(destination: []u8, source: []const u8) usize {
    const length = @min(destination.len, source.len);
    @memcpy(destination[0..length], source[0..length]);
    return length;
}

pub fn widenToUtf16(destination: []u16, source: []const u8) usize {
    const length = @min(destination.len, source.len);
    for (source[0..length], 0..) |character, index| {
        destination[index] = character;
    }
    return length;
}
