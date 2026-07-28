//! Serial Initialization

const common = @import("common");

const io = @import("asm").io;

const constants = @import("mirai").drivers.constants;

const ports = common.constants.serial.ports;
const registers = common.constants.serial.registers;

pub fn initialize(port: u16) bool {
    io.port.writeByte(port + registers.INTERRUPT_ENABLE_REGISTER, 0x00);

    io.port.writeByte(port + registers.LINE_CONTROL_REGISTER, registers.LINE_CONTROL_DLAB);
    io.port.writeByte(port + registers.DIVISOR_LATCH_LOW, @truncate(ports.DEFAULT_BAUD_DIVISOR));
    io.port.writeByte(port + registers.DIVISOR_LATCH_HIGH, @truncate(ports.DEFAULT_BAUD_DIVISOR >> @bitSizeOf(u8)));

    io.port.writeByte(port + registers.LINE_CONTROL_REGISTER, registers.LINE_CONTROL_8_BITS);

    io.port.writeByte(port + registers.FIFO_CONTROL_REGISTER, registers.FIFO_ENABLE | registers.FIFO_CLEAR_RECEIVE | registers.FIFO_CLEAR_TRANSMIT | registers.FIFO_TRIGGER_14);

    io.port.writeByte(port + registers.MODEM_CONTROL_REGISTER, registers.MODEM_DTR | registers.MODEM_RTS | registers.MODEM_OUT2);

    io.port.writeByte(port + registers.MODEM_CONTROL_REGISTER, registers.MODEM_DTR | registers.MODEM_RTS | registers.MODEM_OUT1 | registers.MODEM_OUT2 | registers.MODEM_LOOPBACK);

    io.port.writeByte(port + registers.DATA_REGISTER, constants.serial.format.LOOPBACK_TEST_BYTE);

    if (io.port.readByte(port + registers.DATA_REGISTER) != constants.serial.format.LOOPBACK_TEST_BYTE) {
        return false;
    }

    io.port.writeByte(port + registers.MODEM_CONTROL_REGISTER, registers.MODEM_DTR | registers.MODEM_RTS | registers.MODEM_OUT1 | registers.MODEM_OUT2);

    return true;
}

pub fn initializeDefault() bool {
    return initialize(ports.DEFAULT_PORT);
}
