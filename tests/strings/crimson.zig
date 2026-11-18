//! Crimson Regression Labels

pub const GROUP = "CHECK GROUP Crimson local contracts\n";
pub const VECTORS = "Crimson classifies hardware vectors and error-code layouts";
pub const BOUNDS = "Crimson distinguishes exception vectors from IRQ vectors";
pub const ACTIONS = "Crimson action codec preserves explicit action and state flag";
pub const INVALID_ACTION = "Crimson rejects unknown action codes without requesting state changes";
pub const PORT_HOST = "Crimson lookup uses host fallback and preserves exception masks";
pub const PORT_KATA = "Crimson Kata port overrides host fallback";
pub const PORT_THREAD = "Crimson Thread port overrides Kata and host ports";
pub const PORT_FALLBACK = "Crimson cleared ports reveal their next active fallback";
pub const PORT_HIGH_IDS = "Crimson registers supplied u64 owner keys beyond former numeric bounds";
pub const PORT_SLOTS = "Crimson independent exception slots preserve defaults metadata and active-owner borrows";
pub const PORT_GROWTH = "Crimson sparse owner registrations grow beyond the old backing populations";
pub const PORT_STABLE = "Crimson active port addresses survive unrelated registration growth and clears";
pub const PORT_RELEASE = "Crimson final clears reclaim sparse backing without allocation";
pub const PORT_FAILURE = "Crimson failed growth preserves registered values and allocator state";
pub const PORT_RECOVERY = "Crimson registration remains usable after allocation refusal and complete clearing";
pub const PORT_NOALLOC = "Crimson missing lookup and clear paths allocate nothing under refusal";
pub const FLOAT_ALIGNMENT = "Crimson FXSAVE storage guarantees sixteen-byte alignment and 512-byte capacity";
pub const CORPSE_COPY = "Crimson corpse retains exception metadata and copied CPU context";
pub const CORPSE_BOUNDS = "Crimson corpse omits unbounded stack and memory snapshots";
pub const CORPSE_POOL = "Crimson corpse pool tracks capacity and owned release";
pub const CORPSE_REUSE = "Crimson corpse release invalidates and reuses the same slot";
pub const MODULE_NAME = "Crimson diagnostic module registration refuses oversized names without truncation or publication";
pub const MODULE_BOUNDARY = "Crimson diagnostic module registration preserves full boundary-length names and half-open ranges";
pub const MODULE_RANGE = "Crimson diagnostic module registration rejects overflowing address ranges";
pub const MODULE_CAPACITY = "Crimson diagnostic registry refuses full retention without overwriting existing records";
