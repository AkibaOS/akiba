//! Boot Sequence Runner

const cpu = @import("cpu.zig");
const halt = @import("asm").cpu.halt;
const interrupts = @import("interrupts.zig");
const memory = @import("memory.zig");
const print = @import("print.zig");
const serial = @import("../../drivers/serial/serial.zig");
const state = @import("state.zig");
const strings = @import("../strings/strings.zig");
const types = @import("../types/types.zig");

const messages = strings.sequence.messages;

const BootInfo = types.sequence.info.BootInfo;
const Phase = types.sequence.phase.Phase;

pub fn execute(boot_info: *const BootInfo) bool {
    state.setBootInfo(boot_info);

    if (!serial.init.initializeDefault()) {
        return false;
    }

    print.printBanner();

    serial.write.printf(messages.STARTING, .{});
    serial.write.printf(messages.POWERED, .{});

    state.setCurrentPhase(Phase.CPU);
    if (!cpu.execute()) {
        serial.write.printf(messages.CPU_FAILED, .{});
        return false;
    }
    state.advancePhase();

    serial.write.printf(messages.NEWLINE, .{});

    state.setCurrentPhase(Phase.Memory);
    if (!memory.execute(boot_info)) {
        serial.write.printf(messages.MEMORY_FAILED, .{});
        return false;
    }
    state.advancePhase();

    serial.write.printf(messages.NEWLINE, .{});

    state.setCurrentPhase(Phase.Interrupts);
    if (!interrupts.execute()) {
        serial.write.printf(messages.INTERRUPTS_FAILED, .{});
        return false;
    }
    state.advancePhase();

    serial.write.printf(messages.COMPLETE, .{});
    state.setCurrentPhase(Phase.Complete);

    return true;
}

pub fn haltOnFailure() noreturn {
    serial.write.printf(messages.HALTED, .{});
    halt.haltLoop();
}
