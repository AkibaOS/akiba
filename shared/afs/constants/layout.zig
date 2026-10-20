//! AFS Wire Layout

pub const VOLUME_HEADER_BYTES: usize = 376;
pub const VOLUME_HEADER_ALIGNMENT: usize = 8;
pub const VOLUME_HEADER_OFFSETS = [_]usize{
    0,   8,   12,  16,  24,  32,  40,  48,  56,  64,  68,
    72,  76,  80,  84,  88,  96,  104, 108, 112, 116, 120,
    124, 128, 132, 136, 140, 144, 148, 152, 156, 160, 164,
    168, 172, 176, 180, 184, 188, 192, 196, 200, 204, 208,
    212, 216, 224, 240, 256, 272, 288, 304, 308, 312,
};
pub const VOLUME_HEADER_FIELD_BYTES = [_]usize{
    8, 2, 4,  8,  8,  8,  8,  8, 8, 4,  4,
    4, 4, 4,  4,  4,  8,  4,  4, 4, 4,  4,
    4, 4, 4,  4,  2,  4,  4,  4, 4, 4,  4,
    4, 4, 2,  4,  4,  4,  4,  4, 4, 4,  4,
    2, 4, 16, 16, 16, 16, 16, 4, 4, 64,
};

pub const SPAN_DESCRIPTOR_BYTES: usize = 16;
pub const SPAN_DESCRIPTOR_ALIGNMENT: usize = 8;
pub const SPAN_START_OFFSET: usize = 0;
pub const SPAN_COUNT_OFFSET: usize = 8;
