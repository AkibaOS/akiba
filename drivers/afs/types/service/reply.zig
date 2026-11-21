//! AFS Service Reply Type And Byte Count

pub const Reply = struct {
    Kind: u64,
    Length: usize = 0,
};
