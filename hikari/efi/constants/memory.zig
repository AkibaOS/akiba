//! Hikari EFI Memory Constants

pub const memory_type_reserved: u32 = 0;
pub const memory_type_loader_code: u32 = 1;
pub const memory_type_loader_data: u32 = 2;
pub const memory_type_boot_services_code: u32 = 3;
pub const memory_type_boot_services_data: u32 = 4;
pub const memory_type_runtime_services_code: u32 = 5;
pub const memory_type_runtime_services_data: u32 = 6;
pub const memory_type_conventional: u32 = 7;
pub const memory_type_unusable: u32 = 8;
pub const memory_type_acpi_reclaim: u32 = 9;
pub const memory_type_acpi_nvs: u32 = 10;
pub const memory_type_mmio: u32 = 11;
pub const memory_type_mmio_port_space: u32 = 12;
pub const memory_type_pal_code: u32 = 13;
pub const memory_type_persistent: u32 = 14;
pub const memory_type_unaccepted: u32 = 15;

pub const memory_attribute_uncacheable: u64 = 0x0000000000000001;
pub const memory_attribute_write_combining: u64 = 0x0000000000000002;
pub const memory_attribute_write_through: u64 = 0x0000000000000004;
pub const memory_attribute_write_back: u64 = 0x0000000000000008;
pub const memory_attribute_uncacheable_exported: u64 = 0x0000000000000010;
pub const memory_attribute_write_protected: u64 = 0x0000000000001000;
pub const memory_attribute_read_protected: u64 = 0x0000000000002000;
pub const memory_attribute_execute_protected: u64 = 0x0000000000004000;
pub const memory_attribute_nonvolatile: u64 = 0x0000000000008000;
pub const memory_attribute_more_reliable: u64 = 0x0000000000010000;
pub const memory_attribute_read_only: u64 = 0x0000000000020000;
pub const memory_attribute_specific_purpose: u64 = 0x0000000000040000;
pub const memory_attribute_crypto_capable: u64 = 0x0000000000080000;
pub const memory_attribute_runtime: u64 = 0x8000000000000000;

pub const allocate_type_any_pages: u32 = 0;
pub const allocate_type_max_address: u32 = 1;
pub const allocate_type_address: u32 = 2;

pub const page_size: u64 = 4096;
