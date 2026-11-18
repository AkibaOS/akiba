//! Dedicated UEFI Handoff Regression Entry

const std = @import("std");

const assembly = @import("hikari").assembly;
const bounds = @import("common").constants.serial.format;
const efi = @import("hikari").efi;
const inputs = @import("tests").constants.firmware;
const io = @import("asm").io;
const labels = @import("tests").strings.firmware;
const loader = @import("tests").firmware.loader;
const loadinglabels = @import("tests").strings.loading;
const paging = @import("tests").firmware.paging;
const ports = @import("common").constants.serial.ports;
const registers = @import("common").constants.serial.registers;
const storage = @import("tests").firmware.storage;
const storagelabels = @import("tests").firmware.strings.storage;
const suite = @import("tests").firmware.handoff;

var passed: usize = 0;

pub fn main() void {
    initializeSerial();
    writeText(labels.BEGIN);
    writeText(labels.GROUP);
    const system_table: *efi.types.services.system.SystemTable = @ptrCast(std.os.uefi.system_table);
    const image_handle: efi.types.base.Handle = @ptrCast(std.os.uefi.handle);
    suite.run(system_table.BootServices, image_handle) catch |failure| fail(@errorName(failure));
    writeText(loadinglabels.GROUP);
    loader.run(system_table.BootServices) catch |failure| fail(@errorName(failure));
    writeText(storagelabels.GROUP);
    storage.run(system_table.BootServices) catch |failure| fail(@errorName(failure));
    writeText(labels.PAGING_GROUP);
    paging.run(system_table.BootServices) catch |failure| fail(@errorName(failure));
    if (passed != inputs.ASSERTION_COUNT) fail(labels.COUNT_MISMATCH);
    writeText(labels.COMPLETE);
    var digits: [bounds.MAX_DECIMAL_DIGITS]u8 = undefined;
    writeText(std.fmt.bufPrint(&digits, labels.COUNT, .{passed}) catch fail(labels.FORMAT_FAILED));
    writeText(labels.NEWLINE);
    assembly.halt.haltLoop();
}

pub fn require(condition: bool, comptime name: []const u8) void {
    if (!condition) fail(name);
    passed += 1;
    writeText(labels.PASS);
    writeText(name);
    writeText(labels.NEWLINE);
}

pub fn fail(reason: []const u8) noreturn {
    writeText(labels.FAIL);
    writeText(reason);
    writeText(labels.NEWLINE);
    assembly.halt.haltLoop();
}

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, return_address: ?usize) noreturn {
    _ = stack_trace;
    _ = return_address;
    _ = storage.cleanup();
    _ = loader.cleanup();
    _ = suite.cleanup();
    fail(message);
}

fn initializeSerial() void {
    io.port.writeByte(ports.COM1 + registers.INTERRUPT_ENABLE_REGISTER, 0);
    io.port.writeByte(ports.COM1 + registers.LINE_CONTROL_REGISTER, registers.LINE_CONTROL_DLAB);
    io.port.writeByte(ports.COM1 + registers.DIVISOR_LATCH_LOW, @truncate(ports.DEFAULT_BAUD_DIVISOR));
    io.port.writeByte(ports.COM1 + registers.DIVISOR_LATCH_HIGH, @truncate(ports.DEFAULT_BAUD_DIVISOR >> @bitSizeOf(u8)));
    io.port.writeByte(ports.COM1 + registers.LINE_CONTROL_REGISTER, registers.LINE_CONTROL_8_BITS);
    io.port.writeByte(ports.COM1 + registers.FIFO_CONTROL_REGISTER, registers.FIFO_ENABLE | registers.FIFO_CLEAR_RECEIVE | registers.FIFO_CLEAR_TRANSMIT);
    io.port.writeByte(ports.COM1 + registers.MODEM_CONTROL_REGISTER, registers.MODEM_DTR | registers.MODEM_RTS | registers.MODEM_OUT2);
}

fn writeText(text: []const u8) void {
    for (text) |byte| {
        if (byte == inputs.NEWLINE_BYTE) writeByte(inputs.CARRIAGE_RETURN_BYTE);
        writeByte(byte);
    }
}

fn writeByte(byte: u8) void {
    var attempt: usize = 0;
    while (attempt < inputs.SERIAL_POLL_LIMIT) : (attempt += 1) {
        if ((io.port.readByte(ports.COM1 + registers.LINE_STATUS_REGISTER) & registers.LINE_STATUS_TRANSMIT_EMPTY) != 0) {
            io.port.writeByte(ports.COM1 + registers.DATA_REGISTER, byte);
            return;
        }
    }
    assembly.halt.haltLoop();
}
