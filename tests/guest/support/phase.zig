//! Test Only COM2 Phase Selection

const common = @import("common");
const control = @import("asm").cpu.constants.control;
const cpu = @import("asm").cpu.state;
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").constants.scenario;
const phase = @import("tests").phase;
const pit = @import("mirai").drivers.constants.pit.limits;
const poll = @import("mirai").drivers.serial.poll;
const port = @import("asm").io.port;
const ticks = @import("mirai").drivers.pit.handler;

const Scenario = @import("tests").types.scenario.Scenario;
const registers = common.constants.serial.registers;
const ports = common.constants.serial.ports;

var accepted: ?phase.types.ticket.Ticket = null;

pub fn select() ?Scenario {
    if (accepted) |ticket| return ticket.Scenario;
    if ((cpu.readFlags() & control.RFLAGS_INTERRUPT_ENABLE) == 0) return null;
    initialize();
    if (!send(&phase.constants.wire.READY)) return null;
    var frame: phase.types.ticket.Frame = undefined;
    if (!receive(&frame)) return null;
    const ticket = phase.wire.decode(&frame, .Offer) orelse return null;
    const acknowledgement = phase.wire.encode(ticket, .Acknowledgement) orelse return null;
    if (!send(&acknowledgement)) return null;
    accepted = ticket;
    return ticket.Scenario;
}

fn initialize() void {
    const base = inputs.PHASE_PORT;
    port.writeByte(base + registers.LINE_CONTROL_REGISTER, registers.LINE_CONTROL_8_BITS);
    port.writeByte(base + registers.INTERRUPT_ENABLE_REGISTER, 0);
    port.writeByte(base + registers.LINE_CONTROL_REGISTER, registers.LINE_CONTROL_DLAB);
    port.writeByte(base + registers.DIVISOR_LATCH_LOW, @truncate(ports.DEFAULT_BAUD_DIVISOR));
    port.writeByte(base + registers.DIVISOR_LATCH_HIGH, @truncate(ports.DEFAULT_BAUD_DIVISOR >> @bitSizeOf(u8)));
    port.writeByte(base + registers.LINE_CONTROL_REGISTER, registers.LINE_CONTROL_8_BITS);
    port.writeByte(base + registers.FIFO_CONTROL_REGISTER, registers.FIFO_ENABLE | registers.FIFO_CLEAR_RECEIVE | registers.FIFO_CLEAR_TRANSMIT);
    port.writeByte(base + registers.MODEM_CONTROL_REGISTER, registers.MODEM_DTR | registers.MODEM_RTS);
}

fn send(bytes: []const u8) bool {
    for (bytes) |byte| {
        if (!poll.waitForStatus(inputs.PHASE_PORT, registers.LINE_STATUS_TRANSMIT_EMPTY)) return false;
        port.writeByte(inputs.PHASE_PORT + registers.DATA_REGISTER, byte);
    }
    return true;
}

fn readTicks() u64 {
    const flags = guard.acquire();
    defer guard.release(flags);
    return ticks.getTicks();
}

fn receive(frame: *phase.types.ticket.Frame) bool {
    const deadline = inputs.PHASE_WAIT_SECONDS * pit.TARGET_FREQUENCY;
    const start = readTicks();
    var offset: usize = 0;
    for (0..inputs.PHASE_POLL_LIMIT) |_| {
        if (readTicks() -% start >= deadline) return false;
        const status = port.readByte(inputs.PHASE_PORT + registers.LINE_STATUS_REGISTER);
        if ((status & inputs.PHASE_RECEIVE_ERRORS) != 0) return false;
        if ((status & registers.LINE_STATUS_DATA_READY) != 0) {
            frame[offset] = port.readByte(inputs.PHASE_PORT + registers.DATA_REGISTER);
            offset += 1;
            if (offset == frame.len) return true;
        } else {
            port.ioWait();
        }
    }
    return false;
}
