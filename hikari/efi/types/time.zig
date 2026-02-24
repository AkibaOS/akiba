//! Hikari EFI Time Types

pub const Time = extern struct {
    year: u16,
    month: u8,
    day: u8,
    hour: u8,
    minute: u8,
    second: u8,
    pad1: u8,
    nanosecond: u32,
    time_zone: i16,
    daylight: u8,
    pad2: u8,
};

pub const TimeCapabilities = extern struct {
    resolution: u32,
    accuracy: u32,
    sets_to_zero: bool,
};

pub const timezone_unspecified: i16 = 0x07FF;

pub const daylight_adjust: u8 = 0x01;
pub const daylight_time: u8 = 0x02;
