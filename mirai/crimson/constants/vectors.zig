//! CPU Vector Mapping

const strings = @import("../strings/strings.zig");
const types = @import("../types/types.zig");

const names = strings.names;
const Vector = types.vector.Vector;

pub const PAGE_FAULT_VECTOR: u8 = 14;

pub const VECTORS = [_]Vector{
    .{ .Number = 0, .ExceptionType = .Overflow, .HasErrorCode = false, .Name = names.VECTOR_DIVIDE_ERROR },
    .{ .Number = 1, .ExceptionType = .Shatter, .HasErrorCode = false, .Name = names.VECTOR_DEBUG },
    .{ .Number = 2, .ExceptionType = .Critical, .HasErrorCode = false, .Name = names.VECTOR_NMI },
    .{ .Number = 3, .ExceptionType = .Shatter, .HasErrorCode = false, .Name = names.VECTOR_BREAKPOINT },
    .{ .Number = 4, .ExceptionType = .Overflow, .HasErrorCode = false, .Name = names.VECTOR_OVERFLOW },
    .{ .Number = 5, .ExceptionType = .Forbidden, .HasErrorCode = false, .Name = names.VECTOR_BOUND_RANGE },
    .{ .Number = 6, .ExceptionType = .Forbidden, .HasErrorCode = false, .Name = names.VECTOR_INVALID_OPCODE },
    .{ .Number = 7, .ExceptionType = .Missing, .HasErrorCode = false, .Name = names.VECTOR_DEVICE_NOT_AVAILABLE },
    .{ .Number = 8, .ExceptionType = .Collapse, .HasErrorCode = true, .Name = names.VECTOR_DOUBLE_FAULT },
    .{ .Number = 10, .ExceptionType = .Collapse, .HasErrorCode = true, .Name = names.VECTOR_INVALID_TSS },
    .{ .Number = 11, .ExceptionType = .Breach, .HasErrorCode = true, .Name = names.VECTOR_SEGMENT_NOT_PRESENT },
    .{ .Number = 12, .ExceptionType = .Breach, .HasErrorCode = true, .Name = names.VECTOR_STACK_FAULT },
    .{ .Number = 13, .ExceptionType = .Forbidden, .HasErrorCode = true, .Name = names.VECTOR_GENERAL_PROTECTION },
    .{ .Number = 14, .ExceptionType = .Breach, .HasErrorCode = true, .Name = names.VECTOR_PAGE_FAULT },
    .{ .Number = 16, .ExceptionType = .Overflow, .HasErrorCode = false, .Name = names.VECTOR_FPU_ERROR },
    .{ .Number = 17, .ExceptionType = .Forbidden, .HasErrorCode = true, .Name = names.VECTOR_ALIGNMENT_CHECK },
    .{ .Number = 18, .ExceptionType = .Collapse, .HasErrorCode = false, .Name = names.VECTOR_MACHINE_CHECK },
    .{ .Number = 19, .ExceptionType = .Overflow, .HasErrorCode = false, .Name = names.VECTOR_SIMD_ERROR },
};
