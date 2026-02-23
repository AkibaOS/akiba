//! Serial port driver (COM1)

const int = @import("../../utils/types/int.zig");
const io = @import("../../asm/io.zig");
const ports = @import("../../common/constants/ports.zig");
const serial_const = @import("../../common/constants/serial.zig");

pub fn init() void {
    io.out_byte(ports.COM1_INT_ENABLE, 0x00);
    io.out_byte(ports.COM1_LINE_CTRL, 0x80);
    io.out_byte(ports.COM1_DATA, 0x03);
    io.out_byte(ports.COM1_INT_ENABLE, 0x00);
    io.out_byte(ports.COM1_LINE_CTRL, 0x03);
    io.out_byte(ports.COM1_FIFO_CTRL, 0xC7);
    io.out_byte(ports.COM1_MODEM_CTRL, 0x0B);
}

fn is_tx_empty() bool {
    return (io.in_byte(ports.COM1_LINE_STATUS) & serial_const.LINE_STATUS_TX_EMPTY) != 0;
}

pub fn write(byte: u8) void {
    while (!is_tx_empty()) {}
    io.out_byte(ports.COM1_DATA, byte);
}

pub fn print(str: []const u8) void {
    for (str) |c| {
        write(c);
    }
}

pub fn print_hex(value: u64) void {
    const hex = "0123456789ABCDEF";
    var i: u6 = 60;
    while (true) : (i -%= 4) {
        write(hex[int.u8_of((value >> i) & 0xF)]);
        if (i == 0) break;
    }
}

pub fn print_hex_u32(value: u32) void {
    const hex = "0123456789ABCDEF";
    var i: u5 = 28;
    while (true) : (i -%= 4) {
        write(hex[int.u8_of((value >> i) & 0xF)]);
        if (i == 0) break;
    }
}

pub fn print_hex_u8(value: u8) void {
    const hex = "0123456789ABCDEF";
    write(hex[value >> 4]);
    write(hex[value & 0xF]);
}

pub fn printf(comptime fmt: []const u8, args: anytype) void {
    comptime var i: usize = 0;
    comptime var arg_index: usize = 0;

    inline while (i < fmt.len) {
        if (fmt[i] == '{' and i + 1 < fmt.len and fmt[i + 1] == '}') {
            const arg = args[arg_index];
            print_arg(arg);
            arg_index += 1;
            i += 2;
        } else if (fmt[i] == '{' and i + 2 < fmt.len and fmt[i + 2] == '}') {
            const spec = fmt[i + 1];
            const arg = args[arg_index];
            if (spec == 'x') {
                print_arg_hex(arg);
            } else if (spec == 'd') {
                print_arg_decimal(arg);
            } else if (spec == 's') {
                print_arg_string(arg);
            } else {
                write('{');
                write(spec);
                write('}');
            }
            arg_index += 1;
            i += 3;
        } else {
            write(fmt[i]);
            i += 1;
        }
    }
}

fn print_arg(arg: anytype) void {
    const T = @TypeOf(arg);
    if (T == []const u8) {
        print(arg);
    } else if (T == u8) {
        write(arg);
    } else if (@typeInfo(T) == .int or @typeInfo(T) == .comptime_int) {
        print_decimal(arg);
    } else {
        print("?");
    }
}

fn print_arg_decimal(arg: anytype) void {
    const T = @TypeOf(arg);
    if (@typeInfo(T) == .int or @typeInfo(T) == .comptime_int) {
        print_decimal(arg);
    } else {
        print("?");
    }
}

fn print_arg_string(arg: anytype) void {
    const T = @TypeOf(arg);
    const info = @typeInfo(T);
    if (T == []const u8) {
        print(arg);
    } else if (info == .pointer) {
        const child = info.pointer.child;
        const child_info = @typeInfo(child);
        if (child == u8) {
            // [*]const u8 - null-terminated string pointer
            var i: usize = 0;
            while (arg[i] != 0) : (i += 1) {
                write(arg[i]);
            }
        } else if (child_info == .array and child_info.array.child == u8) {
            // *const [N]u8 or *const [N:0]u8 - pointer to string literal
            const slice = arg.*;
            for (slice) |c| {
                if (c == 0) break;
                write(c);
            }
        } else {
            print("?ptr");
        }
    } else {
        print("?type");
    }
}

fn print_arg_hex(arg: anytype) void {
    const T = @TypeOf(arg);
    if (T == u8) {
        print_hex_u8(arg);
    } else if (T == u32) {
        print_hex_u32(arg);
    } else if (@typeInfo(T) == .int or @typeInfo(T) == .comptime_int) {
        print_hex(@as(u64, @intCast(arg)));
    } else {
        print("?");
    }
}

fn print_decimal(value: anytype) void {
    if (value == 0) {
        write('0');
        return;
    }

    var v: u64 = if (value < 0) @intCast(-value) else @intCast(value);
    if (value < 0) write('-');

    var buf: [20]u8 = undefined;
    var len: usize = 0;

    while (v > 0) : (v /= 10) {
        buf[len] = int.u8_of(v % 10) + '0';
        len += 1;
    }

    while (len > 0) {
        len -= 1;
        write(buf[len]);
    }
}
