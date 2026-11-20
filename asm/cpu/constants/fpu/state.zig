//! FPU State Contract Constants

const std = @import("std");

pub const DEFAULT_CONTROL_WORD: u16 = 0x037F;
pub const DEFAULT_MXCSR: u32 = 0x1F80;
pub const CONTROL_OFFSET: usize = 0;
pub const MXCSR_OFFSET: usize = 24;
pub const STATE_ALIGNMENT: usize = 16;
pub const STATE_SIZE: usize = 512;
pub const INITIAL_STATE: [STATE_SIZE]u8 = initial: {
    var state = [_]u8{0} ** STATE_SIZE;
    std.mem.writeInt(u16, state[CONTROL_OFFSET..][0..@sizeOf(u16)], DEFAULT_CONTROL_WORD, .little);
    std.mem.writeInt(u32, state[MXCSR_OFFSET..][0..@sizeOf(u32)], DEFAULT_MXCSR, .little);
    break :initial state;
};
