//! Diagnostic Escape Cancellation At Quiescent Checkpoints

const config = @import("tests").machine.config;
const guard = @import("asm").interrupts.guard;
const halt = @import("asm").cpu.halt;
const inputs = @import("tests").constants.drivers;
const labels = @import("tests").strings.guest;
const markers = @import("tests").phase.strings.serial;
const phase = @import("tests").guest.support.phase;
const port = @import("asm").io.port;
const ports = @import("mirai").drivers.constants.keyboard.ports;
const serial = @import("mirai").drivers.serial.write;
const verify = @import("tests").verify;

var armed: bool = false;
var requested: bool = false;

pub fn enable() bool {
    armed = phase.epoch() != null and config.cancellationEnabled();
    return armed;
}

pub fn enabled() bool {
    return armed;
}

pub fn observe(scancode: u8) void {
    if (armed and scancode == inputs.ESCAPE_MAKE) requested = true;
}

pub fn earlyCheckpoint() void {
    if (armed and port.readByte(ports.STATUS) & inputs.KEYBOARD_OUTPUT_MASK == inputs.KEYBOARD_OUTPUT_READY) {
        observe(port.readByte(ports.DATA));
    }
    checkpoint();
}

pub fn checkpoint() void {
    const flags = guard.acquire();
    if (armed and requested) cancel();
    guard.release(flags);
}

pub fn finish() void {
    const flags = guard.acquire();
    if (armed and requested) cancel();
    armed = false;
    guard.release(flags);
}

fn cancel() noreturn {
    armed = false;
    const epoch = phase.epoch() orelse @panic(labels.CANCELLATION_FAILED);
    serial.printf(markers.CANCELLED_FORMAT, .{verify.count()});
    if (!phase.cancel(epoch)) @panic(labels.CANCELLATION_FAILED);
    halt.haltLoop();
}
