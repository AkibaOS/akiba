//! Native Persona Invocation Instruction

const std = @import("std");

const vectors = @import("common").constants.interrupts.vectors;

pub const FORMAT = "int ${d}";
pub const CALL = std.fmt.comptimePrint(FORMAT, .{vectors.INVOCATION_VECTOR});
