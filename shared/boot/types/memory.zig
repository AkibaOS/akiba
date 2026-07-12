//! Boot Memory Info

pub const MemoryMapInfo = extern struct {
    Entries: u64,
    EntryCount: u32,
    EntrySize: u32,
    DescriptorVersion: u32,
    Reserved: u32,
};

pub const MemoryType = enum(u32) {
    Usable = 0,
    Reserved = 1,
    ACPIReclaimable = 2,
    ACPINVS = 3,
    BadMemory = 4,
    BootloaderReclaimable = 5,
    Kernel = 6,
    Framebuffer = 7,
};

pub const MemoryRegion = extern struct {
    Base: u64,
    Size: u64,
    RegionType: MemoryType,
    Attributes: u64,
};

pub const UefiMemoryType = enum(u32) {
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
    _,
};

pub const UefiMemoryDescriptor = extern struct {
    MemoryType: UefiMemoryType,
    PhysicalStart: u64,
    VirtualStart: u64,
    NumberOfPages: u64,
    Attribute: u64,
};
