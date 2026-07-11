//! Boot Parameters
//!
//! This structure matches what Hikari bootloader passes to the kernel.

pub const boot_params_magic: u64 = 0x494152494D424B41; // "AKBMIRAI"
pub const boot_params_version: u32 = 1;

pub const BootParams = extern struct {
    magic: u64,
    version: u32,
    size: u32,

    framebuffer: FramebufferInfo,
    memory_map: MemoryMapInfo,
    kernel: KernelInfo,
    acpi: AcpiInfo,
    boot_time: u64,

    reserved: [256]u8,

    pub fn is_valid(self: *const BootParams) bool {
        return self.magic == boot_params_magic and
            self.version == boot_params_version;
    }
};

pub const FramebufferInfo = extern struct {
    base: u64,
    size: u64,
    width: u32,
    height: u32,
    stride: u32,
    pixel_format: PixelFormat,
    red_mask_size: u8,
    red_mask_shift: u8,
    green_mask_size: u8,
    green_mask_shift: u8,
    blue_mask_size: u8,
    blue_mask_shift: u8,
    reserved: [2]u8,
};

pub const PixelFormat = enum(u32) {
    rgb = 0,
    bgr = 1,
    bitmask = 2,
    unknown = 255,
};

pub const MemoryMapInfo = extern struct {
    entries: u64,
    entry_count: u32,
    entry_size: u32,
    descriptor_version: u32,
    reserved: u32,
};

pub const UefiMemoryType = enum(u32) {
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
    _,
};

pub const UefiMemoryDescriptor = extern struct {
    memory_type: UefiMemoryType,
    physical_start: u64,
    virtual_start: u64,
    number_of_pages: u64,
    attribute: u64,
};

pub const MemoryRegion = extern struct {
    base: u64,
    size: u64,
    region_type: MemoryType,
    attributes: u64,
};

pub const MemoryType = enum(u32) {
    usable = 0,
    reserved = 1,
    acpi_reclaimable = 2,
    acpi_nvs = 3,
    bad_memory = 4,
    bootloader_reclaimable = 5,
    kernel = 6,
    framebuffer = 7,
};

pub const KernelInfo = extern struct {
    physical_base: u64,
    virtual_base: u64,
    size: u64,
    entry_point: u64,
    pml4_address: u64,
    physmap_base: u64,
    physmap_size: u64,
    stack_top: u64,
    stack_size: u64,
};

pub const AcpiInfo = extern struct {
    rsdp_address: u64,
    rsdp_version: u32,
    reserved: u32,
};
