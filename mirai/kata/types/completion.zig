//! Independently Retained Kata Completion

const Outcome = @import("mirai").kata.types.outcome.Outcome;

pub const Completion = struct {
    ID: u64 = 0,
    Outcome: ?Outcome = null,
    Reclaimed: bool = false,
};
