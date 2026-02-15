//! Filesystem Limits - Unit and location related limits

// ============================================================================
// Location Limits
// ============================================================================

/// Maximum location length for units and stacks
pub const MAX_LOCATION_LENGTH: usize = 255;

/// Maximum identity length
pub const MAX_IDENTITY_LENGTH: usize = 255;

// ============================================================================
// Unit Size Limits
// ============================================================================

/// Maximum unit size that can be loaded into memory (1MB)
pub const MAX_UNIT_SIZE: u64 = 1024 * 1024;
