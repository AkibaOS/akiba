//! Minimal Inline Span AFS Library Fixture Geometry

const afs = @import("shared").afs;

pub const CELL_SIZE = afs.constants.sizes.DEFAULT_CELL_SIZE;
pub const CATALOG_START: u64 = 1;
pub const LEAF_CELL: u64 = 2;
pub const DATA_START: u64 = 3;
pub const SYSTEM_ID = afs.constants.nodes.FIRST_USER;
pub const INSTALLED_ID = SYSTEM_ID + 1;
pub const SYSTEM_LIBRARIES_ID = INSTALLED_ID + 1;
pub const AUTHOR_UNIT_ID = SYSTEM_LIBRARIES_ID + 1;
pub const SYSTEM_UNIT_ID = AUTHOR_UNIT_ID + 1;
pub const STACK_COUNT: u32 = 4;
pub const PRESENT_RECORDS: u16 = 6;
pub const MISSING_RECORDS: u16 = 5;
pub const NODE_COUNT: u32 = 2;
pub const STACK_MODE: u16 = 0o755;
pub const UNIT_MODE: u16 = 0o644;
