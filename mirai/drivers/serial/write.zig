//! Serial Write Operations

const common = @import("../../../common/common.zig");
const asm_io = @import("../../asm/io/io.zig");

const serial_constants = common.constants.serial;
const ports = serial_constants.ports;
const registers = serial_constants.registers;

var current_port: u16 = ports.default_port;

pub fn set_port(port: u16) void {
    current_port = port;
}

pub fn is_transmit_empty(port: u16) bool {
    return (asm_io.read_byte(port + registers.line_status_register) & registers.line_status_transmit_empty) != 0;
}

pub fn write_character(port: u16, character: u8) void {
    while (!is_transmit_empty(port)) {
        asm_io.io_wait();
    }
    asm_io.write_byte(port + registers.data_register, character);
}

pub fn write_string(port: u16, string: []const u8) void {
    for (string) |character| {
        if (character == '\n') {
            write_character(port, '\r');
        }
        write_character(port, character);
    }
}

pub fn print(string: []const u8) void {
    write_string(current_port, string);
}

pub fn print_character(character: u8) void {
    if (character == '\n') {
        write_character(current_port, '\r');
    }
    write_character(current_port, character);
}

pub fn print_hex(value: u64) void {
    const hex_chars = "0123456789ABCDEF";
    var buffer: [18]u8 = undefined;
    buffer[0] = '0';
    buffer[1] = 'x';

    var temp_value = value;
    var index: usize = 17;
    while (index > 1) : (index -= 1) {
        buffer[index] = hex_chars[@truncate(temp_value & 0xF)];
        temp_value >>= 4;
    }

    print(&buffer);
}

pub fn print_decimal(value: u64) void {
    if (value == 0) {
        print_character('0');
        return;
    }

    var buffer: [20]u8 = undefined;
    var temp_value = value;
    var index: usize = 20;

    while (temp_value > 0) {
        index -= 1;
        buffer[index] = @truncate((temp_value % 10) + '0');
        temp_value /= 10;
    }

    print(buffer[index..]);
}
