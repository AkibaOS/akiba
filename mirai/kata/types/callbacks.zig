//! Kata Release Callback Types

const Kata = @import("mirai").kata.types.kata.Kata;

pub const ReleaseObserver = *const fn (*Kata) void;
