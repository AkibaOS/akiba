//! Hikari Kernel Jump

const activate = @import("asm").cpu.transition.activate;
const strings = @import("hikari").assembly.strings.jump;
const types = @import("asm").cpu.types.transition;

pub fn jumpToKernel(entry_point: u64, stack_top: u64, boot_params: u64, pml4_address: u64) noreturn {
    asm volatile (strings.FLUSH_CACHES ::: .{ .memory = true });
    const continuation: types.Continuation = @ptrFromInt(entry_point);
    const context: *const anyopaque = @ptrFromInt(boot_params);
    activate.enterKernel(pml4_address, stack_top, continuation, context);
}
