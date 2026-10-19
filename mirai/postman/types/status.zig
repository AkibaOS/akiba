//! Envelope Ownership States

pub const Status = enum {
    Free,
    OneWay,
    Queued,
    Delivered,
    Replied,
    Returned,
};
