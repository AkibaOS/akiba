//! AFS B-tree Errors

pub const BTreeError = error{
    ReadFailed,
    InvalidNode,
    InvalidHeader,
    KeyNotFound,
    TreeEmpty,
    AllocationFailed,
};
