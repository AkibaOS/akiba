//! Serial Initialization

const common = @import("root").common;
const asm_io = @import("asm").io;

const serial_constants = common.constants.serial;
const ports = serial_constants.ports;
const registers = serial_constants.registers;

pub fn initialize(port: u16) bool {
    asm_io.write_byte(port + registers.interrupt_enable_register, 0x00);

    asm_io.write_byte(port + registers.line_control_register, registers.line_control_dlab);
    asm_io.write_byte(port + registers.divisor_latch_low, @truncate(ports.default_baud_divisor));
    asm_io.write_byte(port + registers.divisor_latch_high, @truncate(ports.default_baud_divisor >> 8));

    asm_io.write_byte(port + registers.line_control_register, registers.line_control_8_bits);

    asm_io.write_byte(port + registers.fifo_control_register, registers.fifo_enable | registers.fifo_clear_receive | registers.fifo_clear_transmit | registers.fifo_trigger_14);

    asm_io.write_byte(port + registers.modem_control_register, registers.modem_dtr | registers.modem_rts | registers.modem_out2);

    asm_io.write_byte(port + registers.modem_control_register, registers.modem_dtr | registers.modem_rts | registers.modem_out1 | registers.modem_out2 | registers.modem_loopback);

    asm_io.write_byte(port + registers.data_register, 0xAE);

    if (asm_io.read_byte(port + registers.data_register) != 0xAE) {
        return false;
    }

    asm_io.write_byte(port + registers.modem_control_register, registers.modem_dtr | registers.modem_rts | registers.modem_out1 | registers.modem_out2);

    return true;
}

pub fn initialize_default() bool {
    return initialize(ports.default_port);
}
