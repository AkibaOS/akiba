//! Hikari Disk Acquisition Regression Labels

pub const GROUP = "CHECK GROUP Hikari disk acquisition\n";
pub const GPT_SIGNATURE = "EFI PART";
pub const GPT_VALID = "Hikari GPT honors entry stride CRC length alignment and bounded partition lookup";
pub const GPT_CRC = "Hikari GPT rejects independently corrupted header and entry bytes and releases buffers";
pub const GPT_HEADER = "Hikari GPT rejects invalid signatures revisions and header sizes";
pub const GPT_LAYOUT = "Hikari GPT rejects empty excessive undersized and overlapping entry tables before reading them";
pub const GPT_READ_FAILURE = "Hikari GPT reports header and entry read failures without retained allocations";
pub const GPT_POOL_FAILURE = "Hikari GPT reports header and entry allocation failures and releases earlier ownership";
pub const UNIT_VALID = "Hikari AFS acquires real Unit bytes and releases successful buffer and reader ownership";
pub const UNIT_PREALLOCATION = "Hikari AFS rejects empty caller-oversized and volume-oversized Units before allocation or reads";
pub const UNIT_SPAN_ROLLBACK = "Hikari AFS malformed Unit channels and spans release allocated buffers before disk reads";
pub const UNIT_READ_FAILURE = "Hikari AFS Unit read failure releases its allocation and all reader buffers";
pub const FIXTURE_LIFETIME = "Hikari acquisition fixture retained an allocation across reset";
