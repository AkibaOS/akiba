//! Kernel Stack Type

pub const KernelStack = struct {
    base: u64,
    top: u64,
};
