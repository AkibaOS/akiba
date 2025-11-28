//! PS/2 Keyboard Driver

const serial = @import("serial.zig");

const KEYBOARD_DATA_PORT: u16 = 0x60;
const KEYBOARD_STATUS_PORT: u16 = 0x64;

const SCANCODE_RELEASED: u8 = 0x80;

var shift_pressed = false;
var ctrl_pressed = false;
var alt_pressed = false;
var caps_lock = false;

// Input buffer for shell
const BUFFER_SIZE = 256;
var input_buffer: [BUFFER_SIZE]u8 = undefined;
var buffer_pos: usize = 0;

// External function to send keys to terminal/shell
extern fn on_key_typed(char: u8) void;

const SCANCODE_TO_ASCII: [128]u8 = .{
    0,    27,  '1', '2',  '3',  '4', '5',    '6',
    '7',  '8', '9', '0',  '-',  '=', '\x08', '\t',
    'q',  'w', 'e', 'r',  't',  'y', 'u',    'i',
    'o',  'p', '[', ']',  '\n', 0,   'a',    's',
    'd',  'f', 'g', 'h',  'j',  'k', 'l',    ';',
    '\'', '`', 0,   '\\', 'z',  'x', 'c',    'v',
    'b',  'n', 'm', ',',  '.',  '/', 0,      '*',
    0,    ' ', 0,   0,    0,    0,   0,      0,
    0,    0,   0,   0,    0,    0,   0,      '7',
    '8',  '9', '-', '4',  '5',  '6', '+',    '1',
    '2',  '3', '0', '.',  0,    0,   0,      0,
    0,    0,   0,   0,    0,    0,   0,      0,
    0,    0,   0,   0,    0,    0,   0,      0,
    0,    0,   0,   0,    0,    0,   0,      0,
    0,    0,   0,   0,    0,    0,   0,      0,
    0,    0,   0,   0,    0,    0,   0,      0,
};

const SCANCODE_TO_ASCII_SHIFT: [128]u8 = .{
    0,   27,  '!', '@', '#',  '$', '%',    '^',
    '&', '*', '(', ')', '_',  '+', '\x08', '\t',
    'Q', 'W', 'E', 'R', 'T',  'Y', 'U',    'I',
    'O', 'P', '{', '}', '\n', 0,   'A',    'S',
    'D', 'F', 'G', 'H', 'J',  'K', 'L',    ':',
    '"', '~', 0,   '|', 'Z',  'X', 'C',    'V',
    'B', 'N', 'M', '<', '>',  '?', 0,      '*',
    0,   ' ', 0,   0,   0,    0,   0,      0,
    0,   0,   0,   0,   0,    0,   0,      '7',
    '8', '9', '-', '4', '5',  '6', '+',    '1',
    '2', '3', '0', '.', 0,    0,   0,      0,
    0,   0,   0,   0,   0,    0,   0,      0,
    0,   0,   0,   0,   0,    0,   0,      0,
    0,   0,   0,   0,   0,    0,   0,      0,
    0,   0,   0,   0,   0,    0,   0,      0,
    0,   0,   0,   0,   0,    0,   0,      0,
};

const SCANCODE_LSHIFT: u8 = 0x2A;
const SCANCODE_RSHIFT: u8 = 0x36;
const SCANCODE_LCTRL: u8 = 0x1D;
const SCANCODE_LALT: u8 = 0x38;
const SCANCODE_CAPS: u8 = 0x3A;

fn inb(port: u16) u8 {
    return asm volatile ("inb %[port], %[result]"
        : [result] "={al}" (-> u8),
        : [port] "{dx}" (port),
    );
}

fn outb(port: u16, value: u8) void {
    asm volatile ("outb %[value], %[port]"
        :
        : [value] "{al}" (value),
          [port] "{dx}" (port),
    );
}

pub fn init() void {
    serial.print("Initializing PS/2 keyboard...\n");

    // Clear keyboard buffer
    while ((inb(KEYBOARD_STATUS_PORT) & 0x01) != 0) {
        _ = inb(KEYBOARD_DATA_PORT);
    }

    serial.print("Keyboard ready\n");
}

export fn keyboard_handler() void {
    const scancode = inb(KEYBOARD_DATA_PORT);
    handle_scancode(scancode);

    // Send EOI to PIC
    outb(0x20, 0x20);
}

fn handle_scancode(scancode: u8) void {
    const released = (scancode & SCANCODE_RELEASED) != 0;
    const code = scancode & ~SCANCODE_RELEASED;

    // Handle modifier keys
    switch (code) {
        SCANCODE_LSHIFT, SCANCODE_RSHIFT => {
            shift_pressed = !released;
            return;
        },
        SCANCODE_LCTRL => {
            ctrl_pressed = !released;
            return;
        },
        SCANCODE_LALT => {
            alt_pressed = !released;
            return;
        },
        SCANCODE_CAPS => {
            if (!released) {
                caps_lock = !caps_lock;
            }
            return;
        },
        else => {},
    }

    if (released) return;

    // Convert scancode to ASCII
    var ascii: u8 = 0;
    if (shift_pressed) {
        ascii = SCANCODE_TO_ASCII_SHIFT[code];
    } else {
        ascii = SCANCODE_TO_ASCII[code];

        if (caps_lock and ascii >= 'a' and ascii <= 'z') {
            ascii = ascii - 32;
        }
    }

    if (ascii != 0) {
        on_key_press(ascii);
    }
}

fn on_key_press(ascii: u8) void {
    // Echo to serial
    serial.write(ascii);

    // Send to terminal/shell
    on_key_typed(ascii);

    // Handle backspace
    if (ascii == '\x08') {
        if (buffer_pos > 0) {
            buffer_pos -= 1;
        }
        return;
    }

    // Handle enter
    if (ascii == '\n') {
        serial.print("\n");
        buffer_pos = 0;
        return;
    }

    // Add to buffer
    if (buffer_pos < BUFFER_SIZE - 1) {
        input_buffer[buffer_pos] = ascii;
        buffer_pos += 1;
    }
}

pub fn get_input_buffer() []const u8 {
    return input_buffer[0..buffer_pos];
}

pub fn clear_buffer() void {
    buffer_pos = 0;
}
