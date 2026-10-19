//! Postman Transport Errors

pub const PostError = error{
    NotInitialized,
    InvalidThread,
    InvalidPeer,
    Closed,
    Full,
    NoResources,
    TooLarge,
    Busy,
    WouldBlock,
    InvalidReply,
    PeerGone,
    InvalidState,
};
