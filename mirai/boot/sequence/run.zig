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
const status = strings.sequence.status;

const BootInfo = types.sequence.info.BootInfo;
const Phase = types.sequence.phase.Phase;

pub fn execute(boot_info: *const BootInfo) bool {
    state.setBootInfo(boot_info);

    if (!serial.init.initializeDefault()) {
        return false;
    }

    print.printBanner();

    print.log(messages.STARTING, .{});
    print.log(messages.POWERED, .{});

    state.setCurrentPhase(Phase.CPU);
    if (!cpu.execute()) {
        print.fail(status.ERROR_PROCESSOR);
        return false;
    }
    state.advancePhase();

    print.log(messages.NEWLINE, .{});

    state.setCurrentPhase(Phase.Memory);
    if (!memory.execute(boot_info)) {
        print.fail(status.ERROR_MEMORY);
        return false;
    }
    state.advancePhase();

    print.log(messages.NEWLINE, .{});

    state.setCurrentPhase(Phase.Interrupts);
    if (!interrupts.execute()) {
        print.fail(status.ERROR_SERVICES);
        return false;
    }
    state.advancePhase();

    print.phase(status.READY);
    state.setCurrentPhase(Phase.Complete);

    return true;
}

pub fn haltOnFailure() noreturn {
    print.fail(status.ERROR_HALTED);
    halt.haltLoop();
}
