//! Number Formatting

const constants = @import("utils").format.constants;
const strings = @import("utils").format.strings;

const limits = constants.format;

pub fn decimal(value: u64, buffer: []u8) []const u8 {
    if (value == 0) {
        buffer[0] = '0';
        return buffer[0..1];
    }

    var digits: [limits.MAX_DECIMAL_DIGITS]u8 = undefined;
    var count: usize = 0;
    var remaining = value;

    while (remaining > 0) {
        digits[count] = @truncate((remaining % limits.DECIMAL_BASE) + '0');
        remaining /= limits.DECIMAL_BASE;
        count += 1;
    }

    const length = @min(count, buffer.len);
    var index: usize = 0;
    while (index < length) : (index += 1) {
        buffer[index] = digits[count - index - 1];
    }

    return buffer[0..length];
}

fn hex(value: u64, buffer: []u8, digits: []const u8) []const u8 {
    var length: usize = 0;
    var started = false;
    var shift: u8 = @bitSizeOf(u64) - limits.HEX_NIBBLE_BITS;

    while (true) {
        const nibble: u4 = @truncate((value >> @truncate(shift)) & limits.HEX_NIBBLE_MASK);
        if (nibble != 0 or started or shift == 0) {
            if (length < buffer.len) {
                buffer[length] = digits[nibble];
                length += 1;
            }
            started = true;
        }
        if (shift == 0) break;
        shift -= limits.HEX_NIBBLE_BITS;
    }

    return buffer[0..length];
}

pub fn hexLower(value: u64, buffer: []u8) []const u8 {
    return hex(value, buffer, strings.format.HEX_DIGITS_LOWER);
}

pub fn hexUpper(value: u64, buffer: []u8) []const u8 {
    return hex(value, buffer, strings.format.HEX_DIGITS_UPPER);
}
