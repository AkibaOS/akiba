//! Kernel Stack Reservation Phase

pub const Phase = enum {
    Reserved,
    Live,
    Cached,
};
