//! Mirai Kernel

const std = @import("std");

const force = @import("utils").analysis.force;

pub const common = @import("common");
pub const shared = @import("shared");

pub const assembly = @import("asm");
pub const boot = @import("boot/boot.zig");
pub const crimson = @import("crimson/crimson.zig");
pub const drivers = @import("drivers/drivers.zig");
pub const interrupts = @import("interrupts/interrupts.zig");
pub const kagami = @import("kagami/kagami.zig");
pub const kernel = @import("kernel/kernel.zig");
pub const memory = @import("memory/memory.zig");
pub const pmm = @import("pmm/pmm.zig");

comptime {
    force.all(boot);
    force.all(crimson);
    force.all(drivers);
    force.all(interrupts);
    force.all(kagami);
    force.all(kernel);
    force.all(memory);
    force.all(pmm);
}

fn panicHandler(message: []const u8, first_trace_address: ?usize) noreturn {
    _ = first_trace_address;
    drivers.serial.write.printf(crimson.strings.messages.KERNEL_PANIC, .{message});
    assembly.cpu.halt.haltLoop();
}

pub const panic = std.debug.FullPanic(panicHandler);
