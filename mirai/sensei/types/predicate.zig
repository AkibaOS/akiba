//! Atomic Wait Condition

pub const Predicate = *const fn (?*anyopaque) bool;
