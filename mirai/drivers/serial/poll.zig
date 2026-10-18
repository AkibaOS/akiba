//! Bounded Serial Status Polling

const std = @import("std");

const constants = @import("mirai").drivers.constants.serial.format;
const io = @import("asm").io;
const registers = @import("common").constants.serial.registers;

pub fn waitForStatus(port: u16, status_mask: u8) bool {
    for (0..constants.TRANSMIT_POLL_LIMIT) |_| {
        const status = io.port.readByte(port + registers.LINE_STATUS_REGISTER);
        if (status == std.math.maxInt(u8)) return false;
        if ((status & status_mask) == status_mask) return true;
        io.port.ioWait();
    }
    return false;
}
