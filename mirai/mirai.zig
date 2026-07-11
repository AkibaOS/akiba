//! Mirai Kernel

pub const asm_ops = @import("asm/asm.zig");
pub const boot = @import("boot/boot.zig");
pub const crimson = @import("crimson/crimson.zig");
pub const drivers = @import("drivers/drivers.zig");
pub const interrupts = @import("interrupts/interrupts.zig");
pub const kagami = @import("kagami/kagami.zig");
pub const kernel = @import("kernel/kernel.zig");
pub const memory = @import("memory/memory.zig");
pub const pmm = @import("pmm/pmm.zig");

pub const common = @import("common");
pub const shared = @import("shared");

comptime {
    _ = @import("kernel/entry.zig");
}

pub export fn mirai_entry(boot_params_ptr: *kernel.BootParams) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    kernel.main(boot_params_ptr);
}

pub fn panic(msg: []const u8, stack_trace: ?*@import("std").builtin.StackTrace, ret_addr: ?usize) noreturn {
    _ = msg;
    _ = stack_trace;
    _ = ret_addr;
    asm_ops.cpu.halt.halt_loop();
}
