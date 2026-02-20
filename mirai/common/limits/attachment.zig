//! Attachment limits

/// Storage buffer size for location in attachment struct
/// Validation limit is fs_limits.MAX_LOCATION_LENGTH (4096)
pub const MAX_LOCATION_LENGTH: usize = 256;
