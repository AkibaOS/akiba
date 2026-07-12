//! Serial Write Operations

const common = @import("root").common;
const asm_io = @import("asm").io;

const serial_constants = common.constants.serial;
const ports = serial_constants.ports;
const registers = serial_constants.registers;

var current_port: u16 = ports.default_port;

pub fn set_port(port: u16) void {
    current_port = port;
}

fn is_transmit_empty(port: u16) bool {
    return (asm_io.read_byte(port + registers.line_status_register) & registers.line_status_transmit_empty) != 0;
}

fn write_char(port: u16, char: u8) void {
    while (!is_transmit_empty(port)) {
        asm_io.io_wait();
    }
    asm_io.write_byte(port + registers.data_register, char);
}

pub fn printf(comptime fmt: []const u8, args: anytype) void {
    const ArgsType = @TypeOf(args);
    const fields = @typeInfo(ArgsType).@"struct".fields;

    comptime var i: usize = 0;
    comptime var arg_index: usize = 0;

    inline while (i < fmt.len) {
        if (fmt[i] == '%' and i + 1 < fmt.len) {
            switch (fmt[i + 1]) {
                's' => {
                    const str = @field(args, fields[arg_index].name);
                    for (str) |c| {
                        if (c == '\n') write_char(current_port, '\r');
                        write_char(current_port, c);
                    }
                    arg_index += 1;
                    i += 2;
                },
                'd' => {
                    const val = @field(args, fields[arg_index].name);
                    print_decimal_value(@intCast(val));
                    arg_index += 1;
                    i += 2;
                },
                'x' => {
                    const val = @field(args, fields[arg_index].name);
                    print_hex_value(@intCast(val));
                    arg_index += 1;
                    i += 2;
                },
                '%' => {
                    write_char(current_port, '%');
                    i += 2;
                },
                else => {
                    write_char(current_port, fmt[i]);
                    i += 1;
                },
            }
        } else {
            if (fmt[i] == '\n') write_char(current_port, '\r');
            write_char(current_port, fmt[i]);
            i += 1;
        }
    }
}

fn print_decimal_value(value: u64) void {
    if (value == 0) {
        write_char(current_port, '0');
        return;
    }

    var buffer: [20]u8 = undefined;
    var temp = value;
    var len: usize = 0;

    while (temp > 0) {
        buffer[len] = @truncate((temp % 10) + '0');
        temp /= 10;
        len += 1;
    }

    while (len > 0) {
        len -= 1;
        write_char(current_port, buffer[len]);
    }
}

fn print_hex_value(value: u64) void {
    const hex = "0123456789abcdef";
    write_char(current_port, '0');
    write_char(current_port, 'x');

    var started = false;
    var shift: u6 = 60;
    while (true) {
        const nibble: u4 = @truncate((value >> shift) & 0xF);
        if (nibble != 0 or started or shift == 0) {
            write_char(current_port, hex[nibble]);
            started = true;
        }
        if (shift == 0) break;
        shift -= 4;
    }
}
