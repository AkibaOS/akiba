//! PIT Constants

pub const limits = @import("limits.zig");

pub const channel0_data = limits.channel0_data;
pub const channel1_data = limits.channel1_data;
pub const channel2_data = limits.channel2_data;
pub const command = limits.command;

pub const base_frequency = limits.base_frequency;
pub const target_frequency = limits.target_frequency;

pub const mode_square_wave = limits.mode_square_wave;
pub const mode_rate_generator = limits.mode_rate_generator;

pub const irq = limits.irq;
pub const vector = limits.vector;
