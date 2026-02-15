//! I/O Limits - Input/output related limits

// ============================================================================
// Buffer Limits
// ============================================================================

/// Maximum size for a single mark operation (1MB)
pub const MAX_MARK_SIZE: u64 = 1024 * 1024;

/// Maximum size for a single view operation (1MB)
pub const MAX_VIEW_SIZE: u64 = 1024 * 1024;

/// Mirai buffer size for copying kata data
pub const MIRAI_COPY_BUFFER_SIZE: usize = 256;

/// Maximum string length for invocation string parameters
pub const MAX_STRING_LENGTH: usize = 4096;
