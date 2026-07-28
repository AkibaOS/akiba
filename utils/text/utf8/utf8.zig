//! UTF-8 Decoding

pub const REPLACEMENT: u32 = 0xFFFD;

const CONTINUATION_MASK: u8 = 0xC0;
const CONTINUATION_MARK: u8 = 0x80;
const PAYLOAD_MASK: u8 = 0x3F;
const PAYLOAD_BITS: u5 = 6;

const SURROGATE_START: u32 = 0xD800;
const SURROGATE_END: u32 = 0xDFFF;
const MAXIMUM: u32 = 0x10FFFF;

pub const Decoded = struct {
    Codepoint: u32,
    Length: u8,
};

pub fn decode(bytes: []const u8) Decoded {
    if (bytes.len == 0) {
        return Decoded{ .Codepoint = REPLACEMENT, .Length = 1 };
    }

    const lead = bytes[0];

    if (lead < 0x80) {
        return Decoded{ .Codepoint = lead, .Length = 1 };
    }

    const length: u8 = if (lead >= 0xF0 and lead <= 0xF4)
        4
    else if (lead >= 0xE0 and lead <= 0xEF)
        3
    else if (lead >= 0xC2 and lead <= 0xDF)
        2
    else
        0;

    if (length == 0 or bytes.len < length) {
        return Decoded{ .Codepoint = REPLACEMENT, .Length = 1 };
    }

    var codepoint: u32 = switch (length) {
        2 => lead & 0x1F,
        3 => lead & 0x0F,
        else => lead & 0x07,
    };

    var index: u8 = 1;
    while (index < length) : (index += 1) {
        const byte = bytes[index];
        if ((byte & CONTINUATION_MASK) != CONTINUATION_MARK) {
            return Decoded{ .Codepoint = REPLACEMENT, .Length = 1 };
        }
        codepoint = (codepoint << PAYLOAD_BITS) | (byte & PAYLOAD_MASK);
    }

    if (codepoint > MAXIMUM) {
        return Decoded{ .Codepoint = REPLACEMENT, .Length = length };
    }
    if (codepoint >= SURROGATE_START and codepoint <= SURROGATE_END) {
        return Decoded{ .Codepoint = REPLACEMENT, .Length = length };
    }
    if (isOverlong(codepoint, length)) {
        return Decoded{ .Codepoint = REPLACEMENT, .Length = length };
    }

    return Decoded{ .Codepoint = codepoint, .Length = length };
}

fn isOverlong(codepoint: u32, length: u8) bool {
    return switch (length) {
        2 => codepoint < 0x80,
        3 => codepoint < 0x800,
        else => codepoint < 0x10000,
    };
}
