//! Virtual Extent Regression Labels

pub const NAME = "range-check";
pub const GEOMETRY = "invalid and overflowing virtual range geometry rejects without allocating or changing live extents";
pub const GROWTH = "virtual extents grow with stable live metadata and exact indexed membership";
pub const COPIED = "copied virtual region cannot reserve release or look up another context's allocations";
pub const INVALID = "virtual extent release rejects foreign interior and duplicate handles without mutation";
pub const NEIGHBORS = "fragmented extent release preserves every remaining live extent";
pub const MERGE = "extent release coalesces all neighboring ranges without allocating";
pub const RELEASE = "virtual region teardown returns all owned backing without allocating";
pub const SPLIT_FAILURE = "two-sided range split allocation refusal returns pre-reserved metadata and preserves original extents";
pub const SPLIT_SEED = "range split fixture reaches one remaining metadata slot";
pub const SPLIT_ACCEPTED = "two-sided split must not succeed with only one metadata slot and no frame budget";
pub const SPLIT_ERROR = "two-sided split returns actual metadata OutOfMemory";
pub const SPLIT_COUNTS = "failed split restores live record and reserved-byte counts";
pub const SPLIT_SEARCH = "failed split preserves physical allocation search cursor";
pub const SPLIT_BACKING = "failed split restores exact physical backing statistics";
pub const ALIGNMENT = "aligned virtual reservation preserves nonempty prefix and suffix ranges for reuse";
