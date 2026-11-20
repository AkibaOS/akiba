//! Bounded Raw UART Transport For Firmware Checks And Boot Selection

const efi = @import("hikari").efi;
const limits = @import("tests").efi.constants.serial;
const port = @import("asm").io.port;
const ports = @import("common").constants.serial.ports;
const registers = @import("common").constants.serial.registers;
const scenario = @import("tests").machine.constants.serial;

const BootServices = efi.types.services.boot.BootServices;
const status = efi.constants.status.codes;

pub fn attach(base: u16) bool {
    if (readLineStatus(base) == limits.UNAVAILABLE) return false;
    port.writeByte(base + registers.LINE_CONTROL_REGISTER, registers.LINE_CONTROL_8_BITS);
    port.writeByte(base + registers.INTERRUPT_ENABLE_REGISTER, 0);
    port.writeByte(base + registers.LINE_CONTROL_REGISTER, registers.LINE_CONTROL_DLAB);
    port.writeByte(base + registers.DIVISOR_LATCH_LOW, @truncate(ports.DEFAULT_BAUD_DIVISOR));
    port.writeByte(base + registers.DIVISOR_LATCH_HIGH, @truncate(ports.DEFAULT_BAUD_DIVISOR >> @bitSizeOf(u8)));
    port.writeByte(base + registers.LINE_CONTROL_REGISTER, registers.LINE_CONTROL_8_BITS);
    port.writeByte(base + registers.FIFO_CONTROL_REGISTER, registers.FIFO_ENABLE | registers.FIFO_CLEAR_RECEIVE | registers.FIFO_CLEAR_TRANSMIT);
    port.writeByte(base + registers.MODEM_CONTROL_REGISTER, registers.MODEM_DTR | registers.MODEM_RTS);
    return readLineStatus(base) != limits.UNAVAILABLE;
}

pub fn send(services: *BootServices, base: u16, bytes: []const u8) bool {
    var offset: usize = 0;
    for (0..limits.SEND_POLLS) |_| {
        const line_status = readLineStatus(base);
        if (line_status == limits.UNAVAILABLE) return false;
        if (offset == bytes.len) {
            if (line_status & limits.TRANSMITTER_EMPTY != 0) return true;
        } else if (line_status & registers.LINE_STATUS_TRANSMIT_EMPTY != 0) {
            port.writeByte(base + registers.DATA_REGISTER, bytes[offset]);
            offset += 1;
            continue;
        }
        if (services.Stall(limits.POLL_MICROSECONDS) != status.SUCCESS) return false;
    }
    return false;
}

pub fn receive(services: *BootServices, base: u16, bytes: []u8) bool {
    var offset: usize = 0;
    for (0..limits.RECEIVE_POLLS) |_| {
        if (offset == bytes.len) return true;
        const line_status = readLineStatus(base);
        if (line_status & scenario.PHASE_RECEIVE_ERRORS != 0) return false;
        if (line_status & registers.LINE_STATUS_DATA_READY != 0) {
            bytes[offset] = port.readByte(base + registers.DATA_REGISTER);
            offset += 1;
            continue;
        }
        if (services.Stall(limits.POLL_MICROSECONDS) != status.SUCCESS) return false;
    }
    return offset == bytes.len;
}

fn readLineStatus(base: u16) u8 {
    return port.readByte(base + registers.LINE_STATUS_REGISTER);
}
