//! Copied Postman Invocation Descriptor

pub const Call = extern struct {
    Destination: u64,
    Type: u64,
    Request: u64,
    RequestLength: u64,
    Reply: u64,
    ReplyCapacity: u64,
    Metadata: u64,
};
