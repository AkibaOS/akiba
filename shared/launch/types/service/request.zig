//! Installed Unit Identity And Its Startup Parameters

pub const Attached = struct {
    Instance: u64,
    Binary: Request,
};

pub const Request = struct {
    Identity: []const u8,
    Parameters: []const u8,
};
