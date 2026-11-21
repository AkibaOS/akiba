//! Checked AFS Postman Request Body

pub const Request = struct {
    Offset: u64,
    Count: u64,
    Path: []const u8,
};
