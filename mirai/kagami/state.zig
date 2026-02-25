//! Kagami State

const types = @import("types/types.zig");
const Kagami = types.Kagami;

var kernel_kagami: Kagami = .{
    .pml4_physical = 0,
    .reference_count = 1,
    .resident_pages = 0,
    .wired_pages = 0,
    .table_pages = 0,
    .lock = false,
};

var current_kagami: *Kagami = &kernel_kagami;

var initialized: bool = false;

pub fn get_kernel_kagami() *Kagami {
    return &kernel_kagami;
}

pub fn get_current_kagami() *Kagami {
    return current_kagami;
}

pub fn set_current_kagami(kagami: *Kagami) void {
    current_kagami = kagami;
}

pub fn set_kernel_pml4(pml4_physical: u64) void {
    kernel_kagami.pml4_physical = pml4_physical;
}

pub fn is_initialized() bool {
    return initialized;
}

pub fn set_initialized() void {
    initialized = true;
}
