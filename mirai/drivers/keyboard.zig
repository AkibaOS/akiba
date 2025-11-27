//! PS/2 Keyboard Driver

const serial = @import("serial.zig");
const ash = @import("../ash/ash.zig");

const KEYBOARD_DATA_PORT: u16 = 0x60;
const KEYBOARD_STATUS_PORT: u16 = 0x64;

const SCANCODE_RELEASED: u8 = 0x80;

// Keyboard state
var shift_pressed = false;
var ctrl_pressed = false;
var alt_pressed = false;
var caps_lock = false;

// Scancode to ASCII mapping (US QWERTY)
const SCANCODE_TO_ASCII: [128]u8 = .{
    0, 27, '1', '2', '3', '4', '5', '6', // 0-7
    '7', '8', '9', '0', '-', '=', '\x08', '\t', // 8-15
    'q', 'w', 'e', 'r', 't', 'y', 'u', 'i', // 16-23
    'o', 'p', '[', ']', '\n', 0, 'a', 's', // 24-31
    'd', 'f', 'g', 'h', 'j', 'k', 'l', ';', // 32-39
    '\'', '`', 0, '\\', 'z', 'x', 'c', 'v', // 40-47
    'b', 'n', 'm', ',', '.', '/', 0, '*', // 48-55
    0, ' ', 0, 0, 0, 0, 0, 0, // 56-63
    0, 0, 0, 0, 0, 0, 0, '7', // 64-71
    '8', '9', '-', '4', '5', '6', '+', '1', // 72-79
    '2', '3', '0', '.', 0, 0, 0, 0, // 80-87
    0, 0, 0, 0, 0, 0, 0, 0, // 88-95
    0, 0, 0, 0, 0, 0, 0, 0, // 96-103
    0, 0, 0, 0, 0, 0, 0, 0, // 104-111
    0, 0, 0, 0, 0, 0, 0, 0, // 112-119
    0, 0, 0, 0, 0, 0, 0, 0, // 120-127
};

const SCANCODE_TO_ASCII_SHIFT: [128]u8 = .{
    0, 27, '!', '@', '#', '$', '%', '^', // 0-7
    '&', '*', '(', ')', '_', '+', '\x08', '\t', // 8-15
    'Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', // 16-23
    'O', 'P', '{', '}', '\n', 0, 'A', 'S', // 24-31
    'D', 'F', 'G', 'H', 'J', 'K', 'L', ':', // 32-39
    '"', '~', 0, '|', 'Z', 'X', 'C', 'V', // 40-47
    'B', 'N', 'M', '<', '>', '?', 0, '*', // 48-55
    0, ' ', 0, 0, 0, 0, 0, 0, // 56-63
    0, 0, 0, 0, 0, 0, 0, '7', // 64-71
    '8', '9', '-', '4', '5', '6', '+', '1', // 72-79
    '2', '3', '0', '.', 0, 0, 0, 0, // 80-87
    0, 0, 0, 0, 0, 0, 0, 0, // 88-95
    0, 0, 0, 0, 0, 0, 0, 0, // 96-103
    0, 0, 0, 0, 0, 0, 0, 0, // 104-111
    0, 0, 0, 0, 0, 0, 0, 0, // 112-119
    0, 0, 0, 0, 0, 0, 0, 0, // 120-127
};

// Special scancodes
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
    serial.print("Initializing PS/2 keyboard...\r\n");

    // Keyboard is already initialized by BIOS, just need to enable interrupts
    // Clear keyboard buffer
    while ((inb(KEYBOARD_STATUS_PORT) & 0x01) != 0) {
        _ = inb(KEYBOARD_DATA_PORT);
    }

    serial.print("Keyboard ready\r\n");
}

export fn keyboard_interrupt_handler() void {
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

    // Only process key press (not release)
    if (released) return;

    // Convert scancode to ASCII
    var ascii: u8 = 0;
    if (shift_pressed) {
        ascii = SCANCODE_TO_ASCII_SHIFT[code];
    } else {
        ascii = SCANCODE_TO_ASCII[code];

        // Apply caps lock for letters
        if (caps_lock and ascii >= 'a' and ascii <= 'z') {
            ascii = ascii - 32;
        }
    }

    if (ascii != 0) {
        on_key_press(ascii);
    }
}

fn on_key_press(ascii: u8) void {
    serial.write(ascii);
    ash.on_key_press(ascii);
}
