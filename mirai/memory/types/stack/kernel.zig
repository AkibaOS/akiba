//! Kernel Stack Type

pub const KernelStack = struct {
    Base: u64,
    Top: u64,
};
