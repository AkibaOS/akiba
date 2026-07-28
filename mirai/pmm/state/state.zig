//! Physical Memory Manager State

const types = @import("mirai").pmm.types;

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

var global_state: State = .{
    .Bitmap = &[_]u8{},
    .BitmapSize = 0,
    .TotalPages = 0,
    .FreePages = 0,
    .UsedPages = 0,
    .ReservedPages = 0,
    .WiredPages = 0,
    .SearchStart = 0,
    .Initialized = false,
};

pub fn getState() *State {
    return &global_state;
}

pub fn isInitialized() bool {
    return global_state.Initialized;
}

pub fn getStatistics() types.statistics.Statistics {
    return types.statistics.Statistics{
        .TotalPages = global_state.TotalPages,
        .FreePages = global_state.FreePages,
        .UsedPages = global_state.UsedPages,
        .ReservedPages = global_state.ReservedPages,
        .WiredPages = global_state.WiredPages,
    };
}
