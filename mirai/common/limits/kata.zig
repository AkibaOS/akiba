//! Kata Limits - Kata-related limits

// ============================================================================
// Kata Limits
// ============================================================================

/// Maximum number of concurrent katas
pub const MAX_KATAS: usize = 256;

/// Maximum number of attachments per kata
pub const MAX_ATTACHMENTS: usize = 16;

/// Maximum command line arguments
pub const MAX_ARGS: usize = 32;

/// Maximum environment variables
pub const MAX_ENV_VARS: usize = 64;

/// Maximum location (working directory) length
pub const MAX_LOCATION_LENGTH: usize = 256;

/// Maximum postman letter length
pub const MAX_LETTER_LENGTH: usize = 256;
