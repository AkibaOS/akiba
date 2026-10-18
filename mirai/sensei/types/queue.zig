//! Thread Scheduling Queue

const Record = @import("mirai").sensei.types.record.Record;

pub const Queue = struct {
    Head: ?*Record = null,
    Tail: ?*Record = null,
    Count: u16 = 0,
};
