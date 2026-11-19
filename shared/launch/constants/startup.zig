//! Private Launch Startup Header Layout

pub const VERSION: u64 = 1;
pub const IDENTITY_LENGTH = @sizeOf(u64);
pub const PARAMETER_LENGTH = IDENTITY_LENGTH + @sizeOf(u64);
pub const HEADER_BYTES = PARAMETER_LENGTH + @sizeOf(u64);
