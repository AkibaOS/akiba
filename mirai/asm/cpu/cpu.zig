//! CPU Operations

pub const control = @import("control.zig");
pub const halt = @import("halt.zig");

pub const read_cr0 = control.read_cr0;
pub const write_cr0 = control.write_cr0;
pub const read_cr2 = control.read_cr2;
pub const read_cr3 = control.read_cr3;
pub const write_cr3 = control.write_cr3;
pub const read_cr4 = control.read_cr4;
pub const write_cr4 = control.write_cr4;
pub const flush_tlb = control.flush_tlb;
pub const invalidate_page = control.invalidate_page;

pub const halt_cpu = halt.halt;
pub const halt_loop = halt.halt_loop;
pub const enable_interrupts = halt.enable_interrupts;
pub const disable_interrupts = halt.disable_interrupts;
pub const are_interrupts_enabled = halt.are_interrupts_enabled;
pub const read_flags = halt.read_flags;
pub const pause = halt.pause;
