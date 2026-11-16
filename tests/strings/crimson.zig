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
pub const PORT_BOUNDS = "Crimson invalid owner indices cannot alter port tables";
pub const FLOAT_ALIGNMENT = "Crimson FXSAVE storage guarantees sixteen-byte alignment and 512-byte capacity";
pub const CORPSE_COPY = "Crimson corpse retains exception metadata and copied CPU context";
pub const CORPSE_BOUNDS = "Crimson corpse omits unbounded stack and memory snapshots";
pub const CORPSE_POOL = "Crimson corpse pool tracks capacity and owned release";
pub const CORPSE_REUSE = "Crimson corpse release invalidates and reuses the same slot";
