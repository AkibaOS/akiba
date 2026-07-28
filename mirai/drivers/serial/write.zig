//! Serial Write Operations

const common = @import("common");

const io = @import("asm").io;

const constants = @import("mirai").drivers.constants;

const format = @import("utils").format;

const ports = common.constants.serial.ports;
const limits = format.constants.format;
const registers = common.constants.serial.registers;

var current_port: u16 = ports.DEFAULT_PORT;

pub fn setPort(port: u16) void {
    current_port = port;
}

fn isTransmitEmpty(port: u16) bool {
    return (io.port.readByte(port + registers.LINE_STATUS_REGISTER) & registers.LINE_STATUS_TRANSMIT_EMPTY) != 0;
}

fn writeChar(port: u16, char: u8) void {
    while (!isTransmitEmpty(port)) {
        io.port.ioWait();
    }
    io.port.writeByte(port + registers.DATA_REGISTER, char);
}

pub fn printf(comptime fmt: []const u8, args: anytype) void {
    const ArgsType = @TypeOf(args);
    const fields = @typeInfo(ArgsType).@"struct".fields;

    comptime var position: usize = 0;
    comptime var argument_index: usize = 0;

    inline while (position < fmt.len) {
        if (fmt[position] == '%' and position + 1 < fmt.len) {
            switch (fmt[position + 1]) {
                's' => {
                    const text = @field(args, fields[argument_index].name);
                    for (text) |char| {
                        if (char == '\n') writeChar(current_port, '\r');
                        writeChar(current_port, char);
                    }
                    argument_index += 1;
                    position += 2;
                },
                'd' => {
                    const value = @field(args, fields[argument_index].name);
                    printDecimalValue(@intCast(value));
                    argument_index += 1;
                    position += 2;
                },
                'x' => {
                    const value = @field(args, fields[argument_index].name);
                    printHexValue(@intCast(value));
                    argument_index += 1;
                    position += 2;
                },
                '%' => {
                    writeChar(current_port, '%');
                    position += 2;
                },
                else => {
                    writeChar(current_port, fmt[position]);
                    position += 1;
                },
            }
        } else {
            if (fmt[position] == '\n') writeChar(current_port, '\r');
            writeChar(current_port, fmt[position]);
            position += 1;
        }
    }
}

fn printDecimalValue(value: u64) void {
    var digits: [limits.MAX_DECIMAL_DIGITS]u8 = undefined;
    for (format.number.decimal(value, &digits)) |digit| {
        writeChar(current_port, digit);
    }
}

fn printHexValue(value: u64) void {
    writeChar(current_port, '0');
    writeChar(current_port, 'x');

    var digits: [limits.MAX_HEX_DIGITS]u8 = undefined;
    for (format.number.hexLower(value, &digits)) |digit| {
        writeChar(current_port, digit);
    }
}
