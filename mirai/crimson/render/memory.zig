//! Render Memory Around Fault

const serial = @import("../../drivers/serial/serial.zig");
const messages = @import("../strings/strings.zig").messages;

pub fn render_around_address(address: u64, bytes_before: usize, bytes_after: usize) void {
    if (address == 0) return;

    const start = if (address >= bytes_before) address - bytes_before else 0;
    const total_bytes = bytes_before + bytes_after;

    serial.printf(messages.memory_around, .{address});

    const mem_ptr: [*]const u8 = @ptrFromInt(start);

    var offset: usize = 0;
    while (offset < total_bytes) {
        serial.printf("  %x: ", .{start + offset});

        for (0..16) |i| {
            if (offset + i < total_bytes) {
                serial.printf("%x ", .{mem_ptr[offset + i]});
            } else {
                serial.printf("   ", .{});
            }
        }

        serial.printf(" |", .{});
        for (0..16) |i| {
            if (offset + i < total_bytes) {
                const c = mem_ptr[offset + i];
                if (c >= 0x20 and c < 0x7F) {
                    serial.printf("%s", .{&[_]u8{c}});
                } else {
                    serial.printf(".", .{});
                }
            }
        }
        serial.printf("|\n", .{});

        offset += 16;
    }

    serial.printf("\n", .{});
}

pub fn render_instruction_bytes(rip: u64, count: usize) void {
    serial.printf(messages.instruction_bytes, .{rip});

    const code_ptr: [*]const u8 = @ptrFromInt(rip);

    for (0..count) |i| {
        serial.printf("%x ", .{code_ptr[i]});
    }

    serial.printf("\n\n", .{});
}
