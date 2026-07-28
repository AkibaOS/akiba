//! Kagami State

const types = @import("mirai").kagami.types;

const Kagami = types.kagami.Kagami;

var kernel_kagami: Kagami = .{
    .PML4Physical = 0,
    .ReferenceCount = 1,
    .ResidentPages = 0,
    .WiredPages = 0,
    .TablePages = 0,
    .Lock = false,
};

var current_kagami: *Kagami = &kernel_kagami;

var initialized: bool = false;

pub fn getKernelKagami() *Kagami {
    return &kernel_kagami;
}

pub fn getCurrentKagami() *Kagami {
    return current_kagami;
}

pub fn setCurrentKagami(kagami: *Kagami) void {
    current_kagami = kagami;
}

pub fn setKernelPML4(pml4_physical: u64) void {
    kernel_kagami.PML4Physical = pml4_physical;
}

pub fn isInitialized() bool {
    return initialized;
}

pub fn initialize(pml4_physical: u64) void {
    kernel_kagami.PML4Physical = pml4_physical;
    initialized = true;
}
