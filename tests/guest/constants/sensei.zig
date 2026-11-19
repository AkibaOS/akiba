//! Scheduler Regression Inputs

const std = @import("std");

pub const QUEUE_POPULATION_COUNT: usize = @as(usize, std.math.maxInt(u16)) + 2;
pub const WAITER_COUNT: usize = 2;
pub const NESTED_DEPTH: u32 = 2;
