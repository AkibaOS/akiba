//! System-wide limits and constants for Akiba OS
//! Centralizes all magic numbers and hardcoded values in one place

const constants = @import("constants.zig");

// ============================================================================
// Memory Address Space Layout
// ============================================================================

/// Userspace virtual address maximum (below higher-half)
pub const USER_SPACE_MAX: u64 = constants.USER_SPACE_END;

/// First valid userspace page (page 0 is always invalid for null pointer detection)
pub const USER_SPACE_MIN: u64 = constants.USER_SPACE_START;

/// Higher-half kernel space start
pub const KERNEL_SPACE_START: u64 = constants.HIGHER_HALF_START;

// ============================================================================
// File System Limits
// ============================================================================

/// Maximum file size that can be loaded into memory (1MB)
pub const MAX_FILE_SIZE: u64 = 1024 * 1024;

/// Maximum path length for files
pub const MAX_PATH_LENGTH: usize = 255;

/// Maximum filename component length
pub const MAX_FILENAME_LENGTH: usize = 255;

// ============================================================================
// I/O Limits
// ============================================================================

/// Maximum size for a single write operation (1MB)
pub const MAX_WRITE_SIZE: u64 = 1024 * 1024;

/// Maximum size for a single read operation (1MB)
pub const MAX_READ_SIZE: u64 = 1024 * 1024;

/// Kernel buffer size for copying userspace data
pub const KERNEL_COPY_BUFFER_SIZE: usize = 256;

// ============================================================================
// Process Limits
// ============================================================================

/// Maximum number of concurrent processes (katas)
pub const MAX_PROCESSES: usize = 256;

/// Maximum number of open file descriptors per process
pub const MAX_FILE_DESCRIPTORS: usize = 16;

/// Maximum command line arguments
pub const MAX_ARGS: usize = 32;

/// Maximum environment variables
pub const MAX_ENV_VARS: usize = 64;

// ============================================================================
// String and Buffer Limits
// ============================================================================

/// Maximum string length for syscall string parameters
pub const MAX_STRING_LENGTH: usize = 4096;

/// Maximum working directory path length
pub const MAX_CWD_LENGTH: usize = 256;

// Maximum postman letter length
pub const MAX_LETTER_LENGTH: usize = 256;

// ============================================================================
// Validation Helpers
// ============================================================================

/// Check if a pointer is in valid userspace range
pub inline fn is_valid_user_pointer(ptr: u64) bool {
    return ptr >= USER_SPACE_MIN and ptr < USER_SPACE_MAX;
}

/// Check if a virtual address is in userspace
pub inline fn is_userspace_address(addr: u64) bool {
    return addr < USER_SPACE_MAX;
}

/// Check if a virtual address is in kernel space
pub inline fn is_kernel_address(addr: u64) bool {
    return addr >= KERNEL_SPACE_START;
}

/// Check if a memory range is entirely within userspace
pub inline fn is_userspace_range(start: u64, size: u64) bool {
    if (start >= USER_SPACE_MAX) return false;
    if (size == 0) return true;
    // Check for overflow
    const end = start +% size;
    if (end < start) return false; // Overflow occurred
    return end <= USER_SPACE_MAX;
}
