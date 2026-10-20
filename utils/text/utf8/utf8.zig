//! UTF-8 Decoding

const constants = @import("utils").text.constants.utf8;

const Decoded = @import("utils").text.types.decoded.Decoded;

pub fn decode(bytes: []const u8) Decoded {
    if (bytes.len == 0) {
        return Decoded{ .Codepoint = constants.REPLACEMENT, .Length = 1 };
    }

    const lead = bytes[0];

    if (lead < constants.ASCII_LIMIT) {
        return Decoded{ .Codepoint = lead, .Length = 1 };
    }

    const length: u8 = if (lead >= constants.FOUR_BYTE_LEAD_START and lead <= constants.FOUR_BYTE_LEAD_END)
        4
    else if (lead >= constants.THREE_BYTE_LEAD_START and lead <= constants.THREE_BYTE_LEAD_END)
        3
    else if (lead >= constants.TWO_BYTE_LEAD_START and lead <= constants.TWO_BYTE_LEAD_END)
        2
    else
        0;

    if (length == 0 or bytes.len < length) {
        return Decoded{ .Codepoint = constants.REPLACEMENT, .Length = 1 };
    }

    var codepoint: u32 = switch (length) {
        2 => lead & constants.TWO_BYTE_PAYLOAD_MASK,
        3 => lead & constants.THREE_BYTE_PAYLOAD_MASK,
        else => lead & constants.FOUR_BYTE_PAYLOAD_MASK,
    };

    var index: u8 = 1;
    while (index < length) : (index += 1) {
        const byte = bytes[index];
        if ((byte & constants.CONTINUATION_MASK) != constants.CONTINUATION_MARK) {
            return Decoded{ .Codepoint = constants.REPLACEMENT, .Length = 1 };
        }
        codepoint = (codepoint << constants.PAYLOAD_BITS) | (byte & constants.PAYLOAD_MASK);
    }

    if (codepoint > constants.MAXIMUM) {
        return Decoded{ .Codepoint = constants.REPLACEMENT, .Length = length };
    }
    if (codepoint >= constants.SURROGATE_START and codepoint <= constants.SURROGATE_END) {
        return Decoded{ .Codepoint = constants.REPLACEMENT, .Length = length };
    }
    if (isOverlong(codepoint, length)) {
        return Decoded{ .Codepoint = constants.REPLACEMENT, .Length = length };
    }

    return Decoded{ .Codepoint = codepoint, .Length = length };
}

fn isOverlong(codepoint: u32, length: u8) bool {
    return switch (length) {
        2 => codepoint < constants.ASCII_LIMIT,
        3 => codepoint < constants.THREE_BYTE_MINIMUM,
        else => codepoint < constants.FOUR_BYTE_MINIMUM,
    };
}
