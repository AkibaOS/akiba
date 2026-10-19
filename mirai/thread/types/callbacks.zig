//! Thread Lifecycle Callback Types

const Thread = @import("mirai").thread.types.thread.Thread;

pub const InactiveObserver = *const fn (*Thread) void;
pub const SwitchHandler = *const fn () void;
