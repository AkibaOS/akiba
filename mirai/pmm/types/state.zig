//! Physical Memory Manager State

pub const State = struct {
    Bitmap: []u8,
    BitmapSize: u64,
    TotalPages: u64,
    FreePages: u64,
    UsedPages: u64,
    ReservedPages: u64,
    WiredPages: u64,
    SearchStart: u64,
    Initialized: bool,
};
