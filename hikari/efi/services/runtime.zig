//! Hikari EFI Runtime Services

const efi = @import("../efi.zig");
const types = @import("../types/types.zig");
const table = @import("../types/table.zig");
const time = @import("../types/time.zig");
const memory = @import("../types/memory.zig");
const reset = @import("../types/reset.zig");

pub const RuntimeServices = extern struct {
    header: table.TableHeader,

    get_time: *const fn (
        current_time: *time.Time,
        capabilities: ?*time.TimeCapabilities,
    ) callconv(efi.akiba) types.Status,

    set_time: *const fn (
        new_time: *const time.Time,
    ) callconv(efi.akiba) types.Status,

    get_wakeup_time: *const fn (
        enabled: *bool,
        pending: *bool,
        wakeup_time: *time.Time,
    ) callconv(efi.akiba) types.Status,

    set_wakeup_time: *const fn (
        enable: bool,
        wakeup_time: ?*const time.Time,
    ) callconv(efi.akiba) types.Status,

    set_virtual_address_map: *const fn (
        memory_map_size: usize,
        descriptor_size: usize,
        descriptor_version: u32,
        virtual_map: [*]memory.MemoryDescriptor,
    ) callconv(efi.akiba) types.Status,

    convert_pointer: *const fn (
        debug_disposition: usize,
        address: **anyopaque,
    ) callconv(efi.akiba) types.Status,

    get_variable: *const fn (
        variable_name: [*:0]const types.Char16,
        vendor_guid: *align(8) const types.Guid,
        attributes: ?*u32,
        data_size: *usize,
        data: ?[*]u8,
    ) callconv(efi.akiba) types.Status,

    get_next_variable_name: *const fn (
        variable_name_size: *usize,
        variable_name: [*:0]types.Char16,
        vendor_guid: *align(8) types.Guid,
    ) callconv(efi.akiba) types.Status,

    set_variable: *const fn (
        variable_name: [*:0]const types.Char16,
        vendor_guid: *align(8) const types.Guid,
        attributes: u32,
        data_size: usize,
        data: [*]const u8,
    ) callconv(efi.akiba) types.Status,

    get_next_high_monotonic_count: *const fn (
        high_count: *u32,
    ) callconv(efi.akiba) types.Status,

    reset_system: *const fn (
        reset_type: reset.ResetType,
        reset_status: types.Status,
        data_size: usize,
        reset_data: ?*const anyopaque,
    ) callconv(efi.akiba) noreturn,

    update_capsule: *const fn (
        capsule_header_array: **CapsuleHeader,
        capsule_count: usize,
        scatter_gather_list: types.PhysicalAddress,
    ) callconv(efi.akiba) types.Status,

    query_capsule_capabilities: *const fn (
        capsule_header_array: **CapsuleHeader,
        capsule_count: usize,
        maximum_capsule_size: *u64,
        reset_type: *reset.ResetType,
    ) callconv(efi.akiba) types.Status,

    query_variable_info: *const fn (
        attributes: u32,
        maximum_variable_storage_size: *u64,
        remaining_variable_storage_size: *u64,
        maximum_variable_size: *u64,
    ) callconv(efi.akiba) types.Status,
};

pub const CapsuleHeader = extern struct {
    capsule_guid: types.Guid,
    header_size: u32,
    flags: u32,
    capsule_image_size: u32,
};

pub const variable_non_volatile: u32 = 0x00000001;
pub const variable_bootservice_access: u32 = 0x00000002;
pub const variable_runtime_access: u32 = 0x00000004;
pub const variable_hardware_error_record: u32 = 0x00000008;
pub const variable_authenticated_write_access: u32 = 0x00000010;
pub const variable_time_based_authenticated_write_access: u32 = 0x00000020;
pub const variable_append_write: u32 = 0x00000040;
pub const variable_enhanced_authenticated_access: u32 = 0x00000080;

pub const capsule_flags_persist_across_reset: u32 = 0x00010000;
pub const capsule_flags_populate_system_table: u32 = 0x00020000;
pub const capsule_flags_initiate_reset: u32 = 0x00040000;
