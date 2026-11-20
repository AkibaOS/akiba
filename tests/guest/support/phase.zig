//! Test Only COM2 Phase Selection

const common = @import("common");
const inputs = @import("tests").machine.constants.serial;
const phase = @import("tests").phase;
const poll = @import("mirai").drivers.serial.poll;
const port = @import("asm").io.port;

const Scenario = @import("tests").phase.types.scenario.Scenario;
const registers = common.constants.serial.registers;
const ports = common.constants.serial.ports;

var accepted_epoch: ?u64 = null;
var live_offer: ?phase.types.live.frames.Offer = null;

pub fn context() ?phase.types.live.frames.Offer {
    return live_offer;
}

pub fn selectLive() ?Scenario {
    initialize();
    if (!send(&phase.constants.live.frame.READY)) return null;
    var frame: phase.types.live.frames.OfferFrame = undefined;
    if (!receive(&frame)) return null;
    const offer = phase.live.decodeOffer(&frame) orelse return null;
    if (offer.Ticket.Scenario == .Firmware) return null;
    const acknowledgement = phase.live.encodeAcknowledgement(offer.Ticket);
    if (!send(&acknowledgement)) return null;
    live_offer = offer;
    accepted_epoch = offer.Ticket.Epoch;
    return offer.Ticket.Scenario;
}

pub fn epoch() ?u64 {
    return accepted_epoch;
}

pub fn cancel(boot_epoch: u64) bool {
    const frame = phase.action.encode(boot_epoch, .Cancel) orelse return false;
    return send(&frame);
}

pub fn select() ?Scenario {
    initialize();
    if (!send(&phase.constants.wire.frame.READY)) return null;
    var frame: phase.types.ticket.Frame = undefined;
    if (!receive(&frame)) return null;
    const ticket = phase.wire.decode(&frame, .Offer) orelse return null;
    const acknowledgement = phase.wire.encode(ticket, .Acknowledgement) orelse return null;
    if (!send(&acknowledgement)) return null;
    accepted_epoch = ticket.Epoch;
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

fn receive(frame: []u8) bool {
    var offset: usize = 0;
    for (0..inputs.PHASE_POLL_LIMIT) |_| {
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
