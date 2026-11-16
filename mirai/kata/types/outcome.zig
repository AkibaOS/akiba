//! Kata Terminal Outcome

const Fault = @import("mirai").kata.types.fault.Fault;

pub const Outcome = union(enum) {
    Completed,
    Exited: u64,
    Faulted: Fault,
};
