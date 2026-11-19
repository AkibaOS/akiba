//! Kernel Stack Reuse Regression Labels

pub const COLLECTED = "collected stack body is unmapped while both guards remain absent";
pub const REUSED = "collected stack virtual extent is reused after all cached stacks are admitted";
pub const ZEROED = "remapped collected stack has fresh zeroed backing and unchanged guards";
pub const RESTORED = "repeated stack collection and remapping preserve warmed cache and physical accounting";
pub const FAILURE = "each stack construction refusal restores its unpublished extent records pages tables and search";
pub const RECOVERY = "stack construction succeeds at the same reusable virtual extent after allocation failures";
pub const PREFLIGHT = "stack collection validates every cached payload mapping before changing cache or ownership";
pub const ADMISSION = "cached stack with invalid payload mapping is not admitted or replaced silently";
