//! Render Memory Around Fault

const constants = @import("mirai").crimson.constants;
const serial = @import("mirai").drivers.serial;
const strings = @import("mirai").crimson.strings;

const limits = constants.limits;
const memory = strings.memory;
const messages = strings.messages;

pub fn renderAroundAddress(address: u64, bytes_before: usize, bytes_after: usize) void {
    if (address == 0) return;

    const start = if (address >= bytes_before) address - bytes_before else 0;
    const total_bytes = bytes_before + bytes_after;

    serial.write.printf(messages.MEMORY_AROUND, .{address});

    const memory_pointer: [*]const u8 = @ptrFromInt(start);

    var offset: usize = 0;
    while (offset < total_bytes) {
        serial.write.printf(memory.ROW_ADDRESS, .{start + offset});

        for (0..limits.RENDER_BYTES_PER_ROW) |index| {
            if (offset + index < total_bytes) {
                serial.write.printf(memory.HEX_BYTE, .{memory_pointer[offset + index]});
            } else {
                serial.write.printf(memory.BYTE_PADDING, .{});
            }
        }

        serial.write.printf(memory.TEXT_START, .{});
        for (0..limits.RENDER_BYTES_PER_ROW) |index| {
            if (offset + index < total_bytes) {
                const byte = memory_pointer[offset + index];
                if (byte >= 0x20 and byte < 0x7F) {
                    serial.write.printf(memory.TEXT_BYTE, .{&[_]u8{byte}});
                } else {
                    serial.write.printf(memory.NONPRINTABLE_BYTE, .{});
                }
            }
        }
        serial.write.printf(memory.TEXT_END, .{});

        offset += limits.RENDER_BYTES_PER_ROW;
    }

    serial.write.printf(messages.NEWLINE, .{});
}

pub fn renderInstructionBytes(rip: u64, count: usize) void {
    serial.write.printf(messages.INSTRUCTION_BYTES, .{rip});

    const code_pointer: [*]const u8 = @ptrFromInt(rip);

    for (0..count) |index| {
        serial.write.printf(memory.HEX_BYTE, .{code_pointer[index]});
    }

    serial.write.printf(memory.PARAGRAPH_BREAK, .{});
}
