//! Boot Sequence

const asm_cpu = @import("asm").cpu;
const serial = @import("../../drivers/serial/serial.zig");
const messages = @import("strings/strings.zig").messages;

pub const constants = @import("constants/constants.zig");
pub const types = @import("types/types.zig");
pub const phases = @import("phases/phases.zig");
pub const message = @import("message/message.zig");
pub const state = @import("state.zig");

pub const Phase = constants.Phase;
pub const BootInfo = types.BootInfo;

pub fn execute(boot_info: *const BootInfo) bool {
    state.set_boot_info(boot_info);

    if (!serial.initialize_default()) {
        return false;
    }

    message.print_banner();

    serial.printf(messages.STARTING, .{});
    serial.printf(messages.POWERED, .{});

    state.set_current_phase(Phase.cpu);
    if (!phases.execute_cpu()) {
        serial.printf(messages.CPU_FAILED, .{});
        return false;
    }
    state.advance_phase();

    serial.printf(messages.NEWLINE, .{});

    state.set_current_phase(Phase.memory);
    if (!phases.execute_memory(boot_info)) {
        serial.printf(messages.MEMORY_FAILED, .{});
        return false;
    }
    state.advance_phase();

    serial.printf(messages.NEWLINE, .{});

    state.set_current_phase(Phase.interrupts);
    if (!phases.execute_interrupts()) {
        serial.printf(messages.INTERRUPTS_FAILED, .{});
        return false;
    }
    state.advance_phase();

    serial.printf(messages.COMPLETE, .{});
    state.set_current_phase(Phase.complete);

    return true;
}

pub fn halt_on_failure() noreturn {
    serial.printf(messages.HALTED, .{});
    asm_cpu.halt_loop();
}

pub fn get_current_phase() Phase {
    return state.get_current_phase();
}

pub fn get_boot_info() ?*const BootInfo {
    return state.get_boot_info();
}

pub fn is_complete() bool {
    return state.is_complete();
}
