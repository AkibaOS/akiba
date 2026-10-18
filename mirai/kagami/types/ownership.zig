//! Kagami Ownership Types

pub const Ownership = enum {
    Borrowed,
    Kernel,
    Shared,
    User,
};
