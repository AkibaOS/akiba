//! Copied Letter Views

pub const Header = extern struct {
    Sender: u64,
    Type: u64,
    Length: u64,
    ReplyTicket: u64,
};

pub const View = struct {
    Header: Header,
    Payload: []const u8,
};
