//! Thread Descriptor And Owner Bound Runtime Storage

const Observer = @import("mirai").kata.types.observer.Observer;
const Postman = @import("mirai").postman.types.record.Record;
const Scheduler = @import("mirai").sensei.types.record.Record;
const Thread = @import("mirai").thread.types.thread.Thread;

pub const Slot = struct {
    Descriptor: Thread,
    Scheduler: Scheduler = .{},
    Observer: Observer = .{},
    Postman: Postman = .{},
    OwnerPrevious: ?*Thread = null,
    OwnerNext: ?*Thread = null,
};
