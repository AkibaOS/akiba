//! Hikari EFI Memory Types

const base = @import("base.zig");

pub const MemoryType = enum(u32) {
    reserved = 0,
    loader_code = 1,
    loader_data = 2,
    boot_services_code = 3,
    boot_services_data = 4,
    runtime_services_code = 5,
    runtime_services_data = 6,
    conventional = 7,
    unusable = 8,
    acpi_reclaim = 9,
    acpi_nvs = 10,
    mmio = 11,
    mmio_port_space = 12,
    pal_code = 13,
    persistent = 14,
    unaccepted = 15,
};

pub const AllocateType = enum(u32) {
    any_pages = 0,
    max_address = 1,
    address = 2,
};

pub const MemoryDescriptor = extern struct {
    memory_type: MemoryType,
    physical_start: base.PhysicalAddress,
    virtual_start: base.VirtualAddress,
    number_of_pages: u64,
    attribute: u64,
};

pub const LocateSearchType = enum(u32) {
    all_handles = 0,
    by_register_notify = 1,
    by_protocol = 2,
};
