//! PS/2 Keyboard Driver

const ahci_const = @import("../../common/constants/ahci.zig");
const io = @import("../../asm/io.zig");
const kb_const = @import("../../common/constants/keyboard.zig");
const kb_limits = @import("../../common/limits/keyboard.zig");
const ports = @import("../../common/constants/ports.zig");
const scancode = @import("scancode.zig");
const sensei = @import("../../kata/sensei.zig");
const serial = @import("../serial/serial.zig");

var shift_pressed = false;
var ctrl_pressed = false;
var alt_pressed = false;
var caps_lock = false;

var key_buffer: [kb_limits.BUFFER_SIZE]u8 = undefined;
var read_pos: usize = 0;
var write_pos: usize = 0;

pub fn init() void {
    serial.printf("Initializing PS/2 keyboard...\n", .{});

    while ((io.in_byte(ports.KEYBOARD_STATUS) & 0x01) != 0) {
        _ = io.in_byte(ports.KEYBOARD_DATA);
    }

    serial.printf("Keyboard ready\n", .{});
}

export fn keyboard_handler() void {
    const code = io.in_byte(ports.KEYBOARD_DATA);
    handle_scancode(code);
    io.out_byte(ports.PIC1_CMD, ahci_const.PIC_EOI);
}

fn handle_scancode(code: u8) void {
    const released = (code & kb_const.SCANCODE_RELEASED) != 0;
    const key = code & ~kb_const.SCANCODE_RELEASED;

    switch (key) {
        kb_const.SCANCODE_LSHIFT, kb_const.SCANCODE_RSHIFT => {
            shift_pressed = !released;
            return;
        },
        kb_const.SCANCODE_LCTRL => {
            ctrl_pressed = !released;
            return;
        },
        kb_const.SCANCODE_LALT => {
            alt_pressed = !released;
            return;
        },
        kb_const.SCANCODE_CAPS => {
            if (!released) caps_lock = !caps_lock;
            return;
        },
        else => {},
    }

    if (released) return;

    var ascii: u8 = if (shift_pressed) scancode.shifted[key] else scancode.normal[key];

    if (caps_lock and ascii >= 'a' and ascii <= 'z') {
        ascii -= kb_const.LOWERCASE_TO_UPPERCASE;
    }

    if (ascii != 0) {
        enqueue(ascii);
    }
}

fn enqueue(ascii: u8) void {
    const next = (write_pos + 1) % kb_limits.BUFFER_SIZE;
    if (next != read_pos) {
        key_buffer[write_pos] = ascii;
        write_pos = next;
        sensei.wake_one_blocked_kata();
    }
}

pub fn has_input() bool {
    return read_pos != write_pos;
}

pub fn read_char() ?u8 {
    if (read_pos == write_pos) return null;

    const char = key_buffer[read_pos];
    read_pos = (read_pos + 1) % kb_limits.BUFFER_SIZE;
    return char;
}
