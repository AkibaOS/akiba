//! Hikari EFI Time Types

pub const Time = extern struct {
    Year: u16,
    Month: u8,
    Day: u8,
    Hour: u8,
    Minute: u8,
    Second: u8,
    Pad1: u8,
    Nanosecond: u32,
    TimeZone: i16,
    Daylight: u8,
    Pad2: u8,
};

pub const TimeCapabilities = extern struct {
    Resolution: u32,
    Accuracy: u32,
    SetsToZero: bool,
};
