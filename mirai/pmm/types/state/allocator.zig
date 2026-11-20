//! Physical Memory Manager State

const types = @import("mirai").pmm.types;

pub const State = struct {
    Index: types.storage.layout.Index = .{},
    Statistics: types.statistics.Statistics = .{},
    SearchStart: u64 = 0,
};
