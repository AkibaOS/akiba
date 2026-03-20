//! Vector Classification

const constants = @import("../constants/constants.zig");
const ExceptionType = constants.ExceptionType;
const vectors = constants.vectors;

pub fn classify_vector(vector_number: u8) ExceptionType { return vectors.get_exception_type(vector_number); }
pub fn get_vector_name(vector_number: u8) []const u8 { return vectors.get_name(vector_number); }
pub fn vector_has_error_code(vector_number: u8) bool { return vectors.has_error_code(vector_number); }
pub fn is_exception_vector(vector_number: u8) bool { return vector_number < 32; }
