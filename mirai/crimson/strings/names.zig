//! Crimson Names

pub const TYPE_BREACH = "Breach";
pub const TYPE_FORBIDDEN = "Forbidden";
pub const TYPE_OVERFLOW = "Overflow";
pub const TYPE_SHATTER = "Shatter";
pub const TYPE_MISSING = "Missing";
pub const TYPE_CRITICAL = "Critical";
pub const TYPE_SOFTWARE = "Software";
pub const TYPE_RESOURCE = "Resource";
pub const TYPE_GUARD = "Guard";
pub const TYPE_COLLAPSE = "Collapse";

pub const DESCRIPTION_BREACH = "Memory access failure";
pub const DESCRIPTION_FORBIDDEN = "Illegal operation";
pub const DESCRIPTION_OVERFLOW = "Arithmetic exception";
pub const DESCRIPTION_SHATTER = "Debug or breakpoint";
pub const DESCRIPTION_MISSING = "Resource not available";
pub const DESCRIPTION_CRITICAL = "System-level interrupt";
pub const DESCRIPTION_SOFTWARE = "Software-raised exception";
pub const DESCRIPTION_RESOURCE = "Resource limit exceeded";
pub const DESCRIPTION_GUARD = "Guarded resource violation";
pub const DESCRIPTION_COLLAPSE = "Unrecoverable error";

pub const ACTION_RESUME = "Resume";
pub const ACTION_SKIP = "Skip";
pub const ACTION_TERMINATE = "Terminate";
pub const ACTION_TERMINATE_CORPSE = "Terminate with Corpse";
pub const ACTION_COLLAPSE = "Collapse";
pub const ACTION_DEBUG = "Debug";

pub const FLAVOR_NONE = "None";
pub const FLAVOR_GENERAL = "General";
pub const FLAVOR_FLOAT = "Float";
pub const FLAVOR_DEBUG = "Debug";
pub const FLAVOR_AVX = "AVX";
pub const FLAVOR_FULL = "Full";

pub const VECTOR_DIVIDE_ERROR = "Divide Error";
pub const VECTOR_DEBUG = "Debug";
pub const VECTOR_NMI = "NMI";
pub const VECTOR_BREAKPOINT = "Breakpoint";
pub const VECTOR_OVERFLOW = "Overflow";
pub const VECTOR_BOUND_RANGE = "Bound Range";
pub const VECTOR_INVALID_OPCODE = "Invalid Opcode";
pub const VECTOR_DEVICE_NOT_AVAILABLE = "Device Not Available";
pub const VECTOR_DOUBLE_FAULT = "Double Fault";
pub const VECTOR_INVALID_TSS = "Invalid TSS";
pub const VECTOR_SEGMENT_NOT_PRESENT = "Segment Not Present";
pub const VECTOR_STACK_FAULT = "Stack Fault";
pub const VECTOR_GENERAL_PROTECTION = "General Protection";
pub const VECTOR_PAGE_FAULT = "Page Fault";
pub const VECTOR_FPU_ERROR = "x87 FPU Error";
pub const VECTOR_ALIGNMENT_CHECK = "Alignment Check";
pub const VECTOR_MACHINE_CHECK = "Machine Check";
pub const VECTOR_SIMD_ERROR = "SIMD Error";
pub const VECTOR_UNKNOWN = "Unknown";

pub const ACCESS_EXECUTE_NON_EXECUTABLE = "Execute on non-executable page";
pub const ACCESS_EXECUTE_NON_PRESENT = "Execute on non-present page";
pub const ACCESS_WRITE_READ_ONLY = "Write to read-only page";
pub const ACCESS_WRITE_NON_PRESENT = "Write to non-present page";
pub const ACCESS_READ_PROTECTED = "Read from protected page";
pub const ACCESS_READ_NON_PRESENT = "Read from non-present page";
