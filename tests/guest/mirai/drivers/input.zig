//! Actual PIT And Injected Keyboard IRQ Checks

const cpu = @import("asm").cpu;
const drivers = @import("mirai").drivers;
const guard = @import("asm").interrupts.guard;
const inputs = @import("tests").constants.drivers;
const labels = @import("tests").strings.drivers;
const ports = @import("common").constants.serial.ports;
const verify = @import("tests").guest.support.verify;

pub fn run() void {
    verify.require(drivers.serial.state.isAvailable() and drivers.serial.state.getPort() == ports.COM1, labels.SERIAL);
    var flags = guard.acquire();
    const before = drivers.pit.handler.getTicks();
    guard.release(flags);
    var ticks = before;
    var attempts: usize = 0;
    while (ticks - before < inputs.REQUIRED_TICKS and attempts < inputs.WAIT_LIMIT) : (attempts += 1) {
        cpu.halt.pause();
        flags = guard.acquire();
        ticks = drivers.pit.handler.getTicks();
        guard.release(flags);
    }
    verify.require(ticks >= before and ticks - before >= inputs.REQUIRED_TICKS, labels.TIMER);
    flags = guard.acquire();
    const initial = drivers.keyboard.handler.getLastScancode();
    drivers.serial.write.printf(labels.READY_LINE, .{});
    const started = drivers.pit.handler.getTicks();
    guard.release(flags);
    var armed = initial != inputs.BREAK_CODE;
    while (true) {
        flags = guard.acquire();
        const scancode = drivers.keyboard.handler.getLastScancode();
        ticks = drivers.pit.handler.getTicks();
        guard.release(flags);
        if (scancode != inputs.BREAK_CODE) armed = true;
        if (armed and scancode == inputs.BREAK_CODE) {
            verify.require(true, labels.KEYBOARD);
            return;
        }
        if (ticks -% started >= inputs.INPUT_WAIT_TICKS) break;
        cpu.halt.waitForInterrupt();
    }
    verify.require(false, labels.KEYBOARD);
}
