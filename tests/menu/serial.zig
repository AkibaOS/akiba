//! Bounded EFI Diagnostic UART Transport

const efi = @import("hikari").efi;
const inputs = @import("tests").constants.scenario;
const labels = @import("menu").strings.summary;
const limits = @import("menu").constants.limits;
const port = @import("asm").io.port;
const ports = @import("common").constants.serial.ports;
const registers = @import("common").constants.serial.registers;

const BootServices = efi.types.services.boot.BootServices;
const status = efi.constants.status;

pub fn attach() bool {
    return configure(ports.COM3);
}

pub fn reportFailure(services: *BootServices, reason: []const u8) void {
    if (!configure(ports.COM1)) return;
    _ = sendTo(services, ports.COM1, labels.FAILURE);
    _ = sendTo(services, ports.COM1, reason);
    _ = sendTo(services, ports.COM1, labels.NEWLINE);
}

fn configure(base: u16) bool {
    port.writeByte(base + registers.LINE_CONTROL_REGISTER, registers.LINE_CONTROL_8_BITS);
    port.writeByte(base + registers.INTERRUPT_ENABLE_REGISTER, 0);
    port.writeByte(base + registers.LINE_CONTROL_REGISTER, registers.LINE_CONTROL_DLAB);
    port.writeByte(base + registers.DIVISOR_LATCH_LOW, @truncate(ports.DEFAULT_BAUD_DIVISOR));
    port.writeByte(base + registers.DIVISOR_LATCH_HIGH, @truncate(ports.DEFAULT_BAUD_DIVISOR >> @bitSizeOf(u8)));
    port.writeByte(base + registers.LINE_CONTROL_REGISTER, registers.LINE_CONTROL_8_BITS);
    port.writeByte(base + registers.FIFO_CONTROL_REGISTER, registers.FIFO_ENABLE | registers.FIFO_CLEAR_RECEIVE | registers.FIFO_CLEAR_TRANSMIT);
    port.writeByte(base + registers.MODEM_CONTROL_REGISTER, registers.MODEM_DTR | registers.MODEM_RTS);
    return readLineStatus(base) != limits.SERIAL_UNAVAILABLE;
}

pub fn send(services: *BootServices, bytes: []const u8) bool {
    return sendTo(services, ports.COM3, bytes);
}

fn sendTo(services: *BootServices, base: u16, bytes: []const u8) bool {
    var offset: usize = 0;
    for (0..limits.SERIAL_SEND_POLLS) |_| {
        const line_status = readLineStatus(base);
        if (line_status == limits.SERIAL_UNAVAILABLE) return false;
        if (offset == bytes.len) {
            if (line_status & limits.SERIAL_TRANSMITTER_EMPTY != 0) return true;
        } else if (line_status & registers.LINE_STATUS_TRANSMIT_EMPTY != 0) {
            port.writeByte(base + registers.DATA_REGISTER, bytes[offset]);
            offset += 1;
            continue;
        }
        if (services.Stall(limits.SERIAL_POLL_MICROSECONDS) != status.SUCCESS) return false;
    }
    return false;
}

pub fn receive(services: *BootServices, bytes: []u8) bool {
    var offset: usize = 0;
    for (0..limits.SERIAL_RECEIVE_POLLS) |_| {
        if (offset == bytes.len) return true;
        const line_status = readLineStatus(ports.COM3);
        if (line_status & inputs.PHASE_RECEIVE_ERRORS != 0) return false;
        if (line_status & registers.LINE_STATUS_DATA_READY != 0) {
            bytes[offset] = port.readByte(ports.COM3 + registers.DATA_REGISTER);
            offset += 1;
            continue;
        }
        if (services.Stall(limits.SERIAL_POLL_MICROSECONDS) != status.SUCCESS) return false;
    }
    return offset == bytes.len;
}

fn readLineStatus(base: u16) u8 {
    return port.readByte(base + registers.LINE_STATUS_REGISTER);
}
