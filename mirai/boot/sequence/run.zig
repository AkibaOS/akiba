//! Boot Sequence Runner

const cpu = @import("mirai").boot.sequence.cpu;
const halt = @import("asm").cpu.halt;
const interrupts = @import("mirai").boot.sequence.interrupts;
const memory = @import("mirai").boot.sequence.memory;
const print = @import("mirai").boot.sequence.print;
const serial = @import("mirai").drivers.serial;
const state = @import("mirai").boot.sequence.state;
const strings = @import("mirai").boot.strings;
const types = @import("mirai").boot.types;

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
