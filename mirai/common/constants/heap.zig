//! Heap allocator constants

pub const SIZE_CLASSES = [_]usize{ 16, 32, 64, 128, 256, 512, 1024, 2048 };
pub const NUM_CACHES: usize = SIZE_CLASSES.len;
pub const LARGE_ALLOC_THRESHOLD: usize = 2048;
pub const MAX_LARGE_PAGES: usize = 64;
