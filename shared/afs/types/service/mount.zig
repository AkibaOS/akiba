//! Trusted Initial AFS Driver Startup Parameters

pub const Mount = extern struct {
    PulseID: u64,
    DiskDriverID: u64,
    LastSector: u64,
};
