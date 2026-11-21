//! Initial AFS Driver Admission State

pub const Started = struct {
    PulseID: u64,
    DriverID: u64,
    Confirmed: bool = false,
};
