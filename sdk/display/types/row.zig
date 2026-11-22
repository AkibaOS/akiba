//! Bounded Display Row Input

pub const Row = extern struct {
    X: u32,
    Y: u32,
    Width: u32,
    Reserved: u32 = 0,
    Pixels: u64,
};
