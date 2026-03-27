//! CPU Vector Mapping

const types = @import("types.zig");
const ExceptionType = types.ExceptionType;

pub const Vector = struct { number: u8, exception_type: ExceptionType, has_error_code: bool, name: []const u8 };

pub const vectors = [_]Vector{
    .{ .number = 0, .exception_type = .overflow, .has_error_code = false, .name = "Divide Error" },
    .{ .number = 1, .exception_type = .shatter, .has_error_code = false, .name = "Debug" },
    .{ .number = 2, .exception_type = .critical, .has_error_code = false, .name = "NMI" },
    .{ .number = 3, .exception_type = .shatter, .has_error_code = false, .name = "Breakpoint" },
    .{ .number = 4, .exception_type = .overflow, .has_error_code = false, .name = "Overflow" },
    .{ .number = 5, .exception_type = .forbidden, .has_error_code = false, .name = "Bound Range" },
    .{ .number = 6, .exception_type = .forbidden, .has_error_code = false, .name = "Invalid Opcode" },
    .{ .number = 7, .exception_type = .missing, .has_error_code = false, .name = "Device Not Available" },
    .{ .number = 8, .exception_type = .collapse, .has_error_code = true, .name = "Double Fault" },
    .{ .number = 10, .exception_type = .collapse, .has_error_code = true, .name = "Invalid TSS" },
    .{ .number = 11, .exception_type = .breach, .has_error_code = true, .name = "Segment Not Present" },
    .{ .number = 12, .exception_type = .breach, .has_error_code = true, .name = "Stack Fault" },
    .{ .number = 13, .exception_type = .forbidden, .has_error_code = true, .name = "General Protection" },
    .{ .number = 14, .exception_type = .breach, .has_error_code = true, .name = "Page Fault" },
    .{ .number = 16, .exception_type = .overflow, .has_error_code = false, .name = "x87 FPU Error" },
    .{ .number = 17, .exception_type = .forbidden, .has_error_code = true, .name = "Alignment Check" },
    .{ .number = 18, .exception_type = .collapse, .has_error_code = false, .name = "Machine Check" },
    .{ .number = 19, .exception_type = .overflow, .has_error_code = false, .name = "SIMD Error" },
};

pub fn get_exception_type(vector_number: u8) ExceptionType {
    for (vectors) |v| {
        if (v.number == vector_number) return v.exception_type;
    }
    return .forbidden;
}

pub fn has_error_code(vector_number: u8) bool {
    for (vectors) |v| {
        if (v.number == vector_number) return v.has_error_code;
    }
    return false;
}

pub fn get_name(vector_number: u8) []const u8 {
    for (vectors) |v| {
        if (v.number == vector_number) return v.name;
    }
    return "Unknown";
}
