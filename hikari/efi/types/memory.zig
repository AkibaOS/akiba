//! Hikari EFI Memory Types

const base = @import("base.zig");

pub const MemoryType = enum(u32) {
    Reserved = 0,
    LoaderCode = 1,
    LoaderData = 2,
    BootServicesCode = 3,
    BootServicesData = 4,
    RuntimeServicesCode = 5,
    RuntimeServicesData = 6,
    Conventional = 7,
    Unusable = 8,
    ACPIReclaim = 9,
    ACPINVS = 10,
    MMIO = 11,
    MMIOPortSpace = 12,
    PALCode = 13,
    Persistent = 14,
    Unaccepted = 15,
};

pub const AllocateType = enum(u32) {
    AnyPages = 0,
    MaxAddress = 1,
    Address = 2,
};

pub const MemoryDescriptor = extern struct {
    MemoryType: MemoryType,
    PhysicalStart: base.PhysicalAddress,
    VirtualStart: base.VirtualAddress,
    NumberOfPages: u64,
    Attribute: u64,
};

pub const LocateSearchType = enum(u32) {
    AllHandles = 0,
    ByRegisterNotify = 1,
    ByProtocol = 2,
};
