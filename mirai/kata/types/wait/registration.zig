//! Registered Completion Wait Context

const Completion = @import("mirai").kata.types.completion.result.Completion;
const Observer = @import("mirai").kata.types.observer.Observer;
const Thread = @import("mirai").thread.types.thread.Thread;

pub const Registration = struct {
    Observer: *Observer,
    Completion: *Completion,
    Thread: *Thread,
};
