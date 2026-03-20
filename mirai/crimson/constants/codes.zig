//! Exception Codes

pub const BreachCode = enum(u8) { page_not_present = 0, page_protection = 1, page_write = 2, page_execute = 3, page_user = 4, segment_not_present = 5, stack_fault = 6, stack_overflow = 7 };
pub const ForbiddenCode = enum(u8) { invalid_opcode = 0, general_protection = 1, privilege_violation = 2, alignment_check = 3, bound_range = 4 };
pub const OverflowCode = enum(u8) { divide_by_zero = 0, integer_overflow = 1, fpu_error = 2, simd_error = 3 };
pub const ShatterCode = enum(u8) { breakpoint = 0, single_step = 1, watchpoint = 2, debug_exception = 3 };
pub const MissingCode = enum(u8) { fpu_not_available = 0, device_not_available = 1 };
pub const CriticalCode = enum(u8) { nmi = 0, machine_check = 1 };
pub const SoftwareCode = enum(u8) { assertion = 0, abort = 1, user_defined = 2 };
pub const ResourceCode = enum(u8) { memory_limit = 0, cpu_limit = 1, file_limit = 2 };
pub const GuardCode = enum(u8) { port_guard = 0, file_guard = 1, memory_guard = 2 };
pub const CollapseCode = enum(u8) { double_fault = 0, triple_fault = 1, machine_check = 2, kernel_panic = 3, invalid_tss = 4 };
