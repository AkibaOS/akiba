//! Boot Messages

const serial = @import("../../../drivers/serial/serial.zig");

pub fn log(comptime fmt: []const u8, args: anytype) void {
    serial.printf(fmt, args);
}

pub fn print_banner() void {
    serial.printf("\n", .{});
    serial.printf("+-----------------------+\n", .{});
    serial.printf("|       A K I B A       |\n", .{});
    serial.printf("+-----------------------+\n", .{});
    serial.printf("\n", .{});
}
