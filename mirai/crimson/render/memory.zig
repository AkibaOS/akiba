//! Render Memory Around Fault

const constants = @import("mirai").crimson.constants;
const serial = @import("mirai").drivers.serial;
const strings = @import("mirai").crimson.strings;

const limits = constants.limits;
const messages = strings.messages;

pub fn renderAroundAddress(address: u64, bytes_before: usize, bytes_after: usize) void {
    if (address == 0) return;

    const start = if (address >= bytes_before) address - bytes_before else 0;
    const total_bytes = bytes_before + bytes_after;

    serial.write.printf(messages.MEMORY_AROUND, .{address});

    const memory_pointer: [*]const u8 = @ptrFromInt(start);

    var offset: usize = 0;
    while (offset < total_bytes) {
        serial.write.printf("  %x: ", .{start + offset});

        for (0..limits.RENDER_BYTES_PER_ROW) |index| {
            if (offset + index < total_bytes) {
                serial.write.printf("%x ", .{memory_pointer[offset + index]});
            } else {
                serial.write.printf("   ", .{});
            }
        }

        serial.write.printf(" |", .{});
        for (0..limits.RENDER_BYTES_PER_ROW) |index| {
            if (offset + index < total_bytes) {
                const byte = memory_pointer[offset + index];
                if (byte >= 0x20 and byte < 0x7F) {
                    serial.write.printf("%s", .{&[_]u8{byte}});
                } else {
                    serial.write.printf(".", .{});
                }
            }
        }
        serial.write.printf("|\n", .{});

        offset += limits.RENDER_BYTES_PER_ROW;
    }

    serial.write.printf("\n", .{});
}

pub fn renderInstructionBytes(rip: u64, count: usize) void {
    serial.write.printf(messages.INSTRUCTION_BYTES, .{rip});

    const code_pointer: [*]const u8 = @ptrFromInt(rip);

    for (0..count) |index| {
        serial.write.printf("%x ", .{code_pointer[index]});
    }

    serial.write.printf("\n\n", .{});
}
