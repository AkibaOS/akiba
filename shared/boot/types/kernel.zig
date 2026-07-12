//! Boot Kernel Info

pub const KernelInfo = extern struct {
    PhysicalBase: u64,
    VirtualBase: u64,
    Size: u64,
    EntryPoint: u64,
    PML4Address: u64,
    PhysmapBase: u64,
    PhysmapSize: u64,
    StackTop: u64,
    StackSize: u64,
};
