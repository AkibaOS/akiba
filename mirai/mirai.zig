//! Mirai Kernel

const std = @import("std");

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

const crimson_strings = @import("crimson/strings/strings.zig");

comptime {
    _ = @import("kernel/entry.zig");
}

pub export fn mirai_entry(boot_params_ptr: *kernel.BootParams) callconv(.{ .x86_64_sysv = .{} }) noreturn {
    kernel.main(boot_params_ptr);
}

fn panic_handler(message: []const u8, first_trace_address: ?usize) noreturn {
    _ = first_trace_address;
    drivers.serial.printf(crimson_strings.messages.kernel_panic, .{message});
    asm_ops.cpu.halt.halt_loop();
}

pub const panic = std.debug.FullPanic(panic_handler);
