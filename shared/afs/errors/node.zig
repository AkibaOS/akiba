//! AFS B-tree Node Errors

pub const NodeError = error{
    ReadFailed,
    InvalidNode,
    OutOfBounds,
};
