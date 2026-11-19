//! Bounded Raw COM3 Transport For Firmware Live Context

const efi = @import("hikari").efi;
const limits = @import("tests").firmware.constants.serial;
const port = @import("asm").io.port;
const ports = @import("common").constants.serial.ports;
const registers = @import("common").constants.serial.registers;
const scenario = @import("tests").constants.scenario;

const BootServices = efi.types.services.boot.BootServices;
const status = efi.constants.status;

pub fn attach() bool {
    if (readLineStatus() == limits.UNAVAILABLE) return false;
    port.writeByte(ports.COM3 + registers.LINE_CONTROL_REGISTER, registers.LINE_CONTROL_8_BITS);
    port.writeByte(ports.COM3 + registers.INTERRUPT_ENABLE_REGISTER, 0);
    port.writeByte(ports.COM3 + registers.LINE_CONTROL_REGISTER, registers.LINE_CONTROL_DLAB);
    port.writeByte(ports.COM3 + registers.DIVISOR_LATCH_LOW, @truncate(ports.DEFAULT_BAUD_DIVISOR));
    port.writeByte(ports.COM3 + registers.DIVISOR_LATCH_HIGH, @truncate(ports.DEFAULT_BAUD_DIVISOR >> @bitSizeOf(u8)));
    port.writeByte(ports.COM3 + registers.LINE_CONTROL_REGISTER, registers.LINE_CONTROL_8_BITS);
    port.writeByte(ports.COM3 + registers.FIFO_CONTROL_REGISTER, registers.FIFO_ENABLE | registers.FIFO_CLEAR_RECEIVE | registers.FIFO_CLEAR_TRANSMIT);
    port.writeByte(ports.COM3 + registers.MODEM_CONTROL_REGISTER, registers.MODEM_DTR | registers.MODEM_RTS);
    return readLineStatus() != limits.UNAVAILABLE;
}

pub fn send(services: *BootServices, bytes: []const u8) bool {
    var offset: usize = 0;
    for (0..limits.SEND_POLLS) |_| {
        const line_status = readLineStatus();
        if (line_status == limits.UNAVAILABLE) return false;
        if (offset == bytes.len) {
            if (line_status & limits.TRANSMITTER_EMPTY != 0) return true;
        } else if (line_status & registers.LINE_STATUS_TRANSMIT_EMPTY != 0) {
            port.writeByte(ports.COM3 + registers.DATA_REGISTER, bytes[offset]);
            offset += 1;
            continue;
        }
        if (services.Stall(limits.POLL_MICROSECONDS) != status.SUCCESS) return false;
    }
    return false;
}

pub fn receive(services: *BootServices, bytes: []u8) bool {
    var offset: usize = 0;
    for (0..limits.RECEIVE_POLLS) |_| {
        if (offset == bytes.len) return true;
        const line_status = readLineStatus();
        if (line_status & scenario.PHASE_RECEIVE_ERRORS != 0) return false;
        if (line_status & registers.LINE_STATUS_DATA_READY != 0) {
            bytes[offset] = port.readByte(ports.COM3 + registers.DATA_REGISTER);
            offset += 1;
            continue;
        }
        if (services.Stall(limits.POLL_MICROSECONDS) != status.SUCCESS) return false;
    }
    return offset == bytes.len;
}

fn readLineStatus() u8 {
    return port.readByte(ports.COM3 + registers.LINE_STATUS_REGISTER);
}
