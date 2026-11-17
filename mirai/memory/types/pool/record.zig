//! Stable Storage Record

pub fn create(comptime Value: type) type {
    return struct {
        Value: Value = undefined,
        Previous: ?*@This() = null,
        Next: ?*@This() = null,
        Generation: u64 = 0,
    };
}
