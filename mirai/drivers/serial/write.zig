//! Serial Write Operations

const bounds = @import("common").constants.serial.format;
const io = @import("asm").io;
const limits = @import("mirai").drivers.constants.serial.number;
const number = @import("mirai").drivers.serial.number;
const poll = @import("mirai").drivers.serial.poll;
const registers = @import("common").constants.serial.registers;
const state = @import("mirai").drivers.serial.state;

pub fn setPort(port: u16) void {
    state.selectPort(port);
}

fn writeChar(char: u8) bool {
    if (!state.isAvailable()) return false;

    const port = state.getPort();
    if (!poll.waitForStatus(port, registers.LINE_STATUS_TRANSMIT_EMPTY)) {
        state.setAvailable(false);
        return false;
    }
    io.port.writeByte(port + registers.DATA_REGISTER, char);
    return true;
}

fn writeText(text: []const u8) bool {
    for (text) |char| {
        if (char == '\n' and !writeChar('\r')) return false;
        if (!writeChar(char)) return false;
    }
    return true;
}

pub fn printf(comptime fmt: []const u8, args: anytype) void {
    if (!state.isAvailable()) return;

    const ArgsType = @TypeOf(args);
    const fields = @typeInfo(ArgsType).@"struct".fields;

    comptime var position: usize = 0;
    comptime var argument_index: usize = 0;

    inline while (position < fmt.len) {
        if (fmt[position] == '%' and position + 1 < fmt.len) {
            switch (fmt[position + 1]) {
                's' => {
                    const text = @field(args, fields[argument_index].name);
                    if (!writeText(text)) return;
                    argument_index += 1;
                    position += 2;
                },
                'd' => {
                    const value = @field(args, fields[argument_index].name);
                    if (!printDecimalValue(@intCast(value))) return;
                    argument_index += 1;
                    position += 2;
                },
                'x' => {
                    const value = @field(args, fields[argument_index].name);
                    if (!printHexValue(@intCast(value))) return;
                    argument_index += 1;
                    position += 2;
                },
                '%' => {
                    if (!writeChar('%')) return;
                    position += 2;
                },
                else => {
                    if (!writeChar(fmt[position])) return;
                    position += 1;
                },
            }
        } else {
            if (fmt[position] == '\n' and !writeChar('\r')) return;
            if (!writeChar(fmt[position])) return;
            position += 1;
        }
    }
}

fn printDecimalValue(value: u64) bool {
    var digits: [bounds.MAX_DECIMAL_DIGITS]u8 = undefined;
    return writeText(number.decimal(value, &digits));
}

fn printHexValue(value: u64) bool {
    if (!writeChar('0') or !writeChar('x')) return false;

    var digits: [limits.MAX_HEX_DIGITS]u8 = undefined;
    return writeText(number.hexLower(value, &digits));
}
