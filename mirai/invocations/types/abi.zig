//! Invocation Register ABI Types

pub const Service = enum(u64) {
    Query = 0,
    Yield = 1,
    Send = 2,
    Receive = 3,
    Call = 4,
    Reply = 5,
    CollectReply = 6,
    Close = 7,
};

pub const Query = enum(u64) {
    ABI = 0,
    Kata = 1,
};

pub const Status = enum(u64) {
    Success = 0,
    Unsupported = 1,
    InvalidArgument = 2,
    InvalidCaller = 3,
    InvalidAddress = 4,
    TooLarge = 5,
    Full = 6,
    NoResources = 7,
    InvalidPeer = 8,
    Closed = 9,
    Busy = 10,
    InvalidReply = 11,
    PeerGone = 12,
    WouldBlock = 13,
    BufferTooSmall = 14,
    InvalidState = 15,
    NotInitialized = 16,
};
