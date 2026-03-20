//! Exception Classification

pub const vector = @import("vector.zig");
pub const analyze = @import("analyze.zig");

pub const classify_vector = vector.classify_vector;
pub const get_vector_name = vector.get_vector_name;
pub const vector_has_error_code = vector.vector_has_error_code;
pub const is_exception_vector = vector.is_exception_vector;
pub const PageFaultError = analyze.PageFaultError;
pub const SelectorError = analyze.SelectorError;
