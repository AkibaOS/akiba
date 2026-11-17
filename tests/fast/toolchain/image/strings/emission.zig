//! Active AFS Writer Fixture Paths And Publication Sentinel

pub const NESTED_DIRECTORY = "source/nested";
pub const NESTED_IDENTITY = "nested";
pub const OVERSIZED_PATH = "source/nested/large.bin";
pub const MUTABLE_PATH = "source/nested/mutable.bin";
pub const MUTABLE_IDENTITY = "mutable.bin";
pub const PARENT_DIRECTORY = "..";
pub const SIBLING_ROOT = "source-output";
pub const SENTINEL = "Previous complete image\x00\xff";
pub const WIDE_ROOT = "host space-日本";
pub const UNSUPPORTED_RECORD = "Unsupported AFS image lookup record";
