//! Dedicated UEFI Handoff Regression Entry

const std = @import("std");

const assembly = @import("hikari").assembly;
const bounds = @import("common").constants.serial.format;
const display = @import("tests").firmware.display;
const efi = @import("hikari").efi;
const inputs = @import("tests").constants.firmware;
const io = @import("asm").io;
const kernel = @import("tests").firmware.kernel;
const labels = @import("tests").strings.firmware;
const live = @import("tests").firmware.live;
const loader = @import("tests").firmware.loader;
const loadinglabels = @import("tests").strings.loading;
const paging = @import("tests").firmware.paging;
const ports = @import("common").constants.serial.ports;
const registers = @import("common").constants.serial.registers;
const runner = @import("tests").strings.runner;
const status = @import("tests").firmware.status;
const storage = @import("tests").firmware.storage;
const storagelabels = @import("tests").firmware.strings.storage;
const suite = @import("tests").firmware.handoff;

var passed: usize = 0;
var failing: bool = false;

pub fn main() void {
    initializeSerial();
    const system_table: *efi.types.services.system.SystemTable = @ptrCast(std.os.uefi.system_table);
    const image_handle: efi.types.base.Handle = @ptrCast(std.os.uefi.handle);
    live.start(system_table.BootServices) catch |failure| failAtEdge(@errorName(failure));
    writeText(labels.BEGIN);
    writeText(labels.GROUP);
    checkpoint(system_table.BootServices);
    status.run(system_table);
    suite.run(system_table.BootServices, image_handle) catch |failure| failAtEdge(@errorName(failure));
    checkpoint(system_table.BootServices);
    writeText(loadinglabels.GROUP);
    loader.run(system_table.BootServices) catch |failure| failAtEdge(@errorName(failure));
    kernel.run(system_table.BootServices) catch |failure| failAtEdge(@errorName(failure));
    checkpoint(system_table.BootServices);
    writeText(storagelabels.GROUP);
    storage.run(system_table.BootServices) catch |failure| failAtEdge(@errorName(failure));
    checkpoint(system_table.BootServices);
    writeText(labels.PAGING_GROUP);
    paging.run(system_table.BootServices) catch |failure| failAtEdge(@errorName(failure));
    if (passed != inputs.ASSERTION_COUNT) failAtEdge(labels.COUNT_MISMATCH);
    checkpoint(system_table.BootServices);
    if (!display.release()) fail(@errorName(error.FirmwareViewportReleaseFailed));
    writeText(labels.COMPLETE);
    var digits: [bounds.MAX_DECIMAL_DIGITS]u8 = undefined;
    writeText(std.fmt.bufPrint(&digits, labels.COUNT, .{passed}) catch fail(labels.FORMAT_FAILED));
    writeText(labels.NEWLINE);
    assembly.halt.haltLoop();
}

fn checkpoint(services: *efi.types.services.boot.BootServices) void {
    if (live.pendingCancellation() catch |failure| failAtEdge(@errorName(failure))) cancel(services);
    display.refresh();
}

fn cancel(services: *efi.types.services.boot.BootServices) noreturn {
    if (!display.release()) fail(@errorName(error.FirmwareViewportReleaseFailed));
    var digits: [bounds.MAX_DECIMAL_DIGITS]u8 = undefined;
    const count = std.fmt.bufPrint(&digits, labels.COUNT, .{passed}) catch fail(labels.FORMAT_FAILED);
    writeText(runner.CHECK_CANCELLED);
    writeText(count);
    writeText(labels.NEWLINE);
    if (!live.sendCancellation(services)) fail(@errorName(error.FirmwareCancelTransmissionFailed));
    assembly.halt.haltLoop();
}

pub fn require(condition: bool, comptime name: []const u8) void {
    if (!condition) fail(name);
    passed += 1;
    writeText(labels.PASS);
    writeText(name);
    writeText(labels.NEWLINE);
    display.record(name);
}

pub fn fail(reason: []const u8) noreturn {
    terminateFailure(reason, false);
}

pub fn panic(message: []const u8, stack_trace: ?*std.builtin.StackTrace, return_address: ?usize) noreturn {
    _ = stack_trace;
    _ = return_address;
    if (!failing) {
        _ = storage.cleanup();
        _ = loader.cleanup();
        _ = suite.cleanup();
    }
    fail(message);
}

fn failAtEdge(reason: []const u8) noreturn {
    terminateFailure(reason, true);
}

fn terminateFailure(reason: []const u8, paint: bool) noreturn {
    if (!failing) {
        failing = true;
        writeText(labels.FAIL);
        writeText(reason);
        writeText(labels.NEWLINE);
        if (paint) display.showFailure(reason);
    }
    haltAfterFailure();
}

fn haltAfterFailure() noreturn {
    _ = display.release();
    assembly.halt.haltLoop();
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
    failing = true;
    haltAfterFailure();
}
