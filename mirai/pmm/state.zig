//! Physical Memory Manager State

pub const State = struct {
    bitmap: []u8,
    bitmap_size: u64,
    total_pages: u64,
    free_pages: u64,
    used_pages: u64,
    reserved_pages: u64,
    wired_pages: u64,
    search_start: u64,
    initialized: bool,
};

var global_state: State = .{
    .bitmap = &[_]u8{},
    .bitmap_size = 0,
    .total_pages = 0,
    .free_pages = 0,
    .used_pages = 0,
    .reserved_pages = 0,
    .wired_pages = 0,
    .search_start = 0,
    .initialized = false,
};

pub fn get_state() *State {
    return &global_state;
}

pub fn is_initialized() bool {
    return global_state.initialized;
}
