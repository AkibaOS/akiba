//! Boot Sequence

const asm_cpu = @import("../../asm/cpu/cpu.zig");
const serial = @import("../../drivers/serial/serial.zig");

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

    serial.printf("Starting Akiba boot sequence\n", .{});
    serial.printf("Powered by the Mirai kernel\n\n", .{});

    state.set_current_phase(Phase.cpu);
    if (!phases.execute_cpu()) {
        serial.printf("\nCPU initialization failed, cannot continue\n", .{});
        return false;
    }
    state.advance_phase();

    serial.printf("\n", .{});

    state.set_current_phase(Phase.memory);
    if (!phases.execute_memory(boot_info)) {
        serial.printf("\nMemory initialization failed, cannot continue\n", .{});
        return false;
    }
    state.advance_phase();

    serial.printf("\nBoot sequence complete, Akiba is ready\n", .{});
    state.set_current_phase(Phase.complete);

    return true;
}

pub fn halt_on_failure() noreturn {
    serial.printf("\nSystem halted due to unrecoverable error\n", .{});
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
