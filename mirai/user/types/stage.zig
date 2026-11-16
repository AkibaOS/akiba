//! Owned User Page Stage

pub const Stage = enum {
    Loading,
    Writable,
    ReadOnly,
    Executable,
};
