//! Hikari EFI Runtime Services

const constants = @import("../constants/constants.zig");
const types = @import("../types/types.zig");

const convention = constants.convention.CALLING_CONVENTION;

pub const RuntimeServices = extern struct {
    Header: types.table.TableHeader,

    GetTime: *const fn (
        current_time: *types.time.Time,
        capabilities: ?*types.time.TimeCapabilities,
    ) callconv(convention) types.base.Status,

    SetTime: *const fn (
        new_time: *const types.time.Time,
    ) callconv(convention) types.base.Status,

    GetWakeupTime: *const fn (
        enabled: *bool,
        pending: *bool,
        wakeup_time: *types.time.Time,
    ) callconv(convention) types.base.Status,

    SetWakeupTime: *const fn (
        enable: bool,
        wakeup_time: ?*const types.time.Time,
    ) callconv(convention) types.base.Status,

    SetVirtualAddressMap: *const fn (
        memory_map_size: usize,
        descriptor_size: usize,
        descriptor_version: u32,
        virtual_map: [*]types.memory.MemoryDescriptor,
    ) callconv(convention) types.base.Status,

    ConvertPointer: *const fn (
        debug_disposition: usize,
        address: **anyopaque,
    ) callconv(convention) types.base.Status,

    GetVariable: *const fn (
        variable_name: [*:0]const types.base.Char16,
        vendor_guid: *align(8) const types.base.GUID,
        attributes: ?*u32,
        data_size: *usize,
        data: ?[*]u8,
    ) callconv(convention) types.base.Status,

    GetNextVariableName: *const fn (
        variable_name_size: *usize,
        variable_name: [*:0]types.base.Char16,
        vendor_guid: *align(8) types.base.GUID,
    ) callconv(convention) types.base.Status,

    SetVariable: *const fn (
        variable_name: [*:0]const types.base.Char16,
        vendor_guid: *align(8) const types.base.GUID,
        attributes: u32,
        data_size: usize,
        data: [*]const u8,
    ) callconv(convention) types.base.Status,

    GetNextHighMonotonicCount: *const fn (
        high_count: *u32,
    ) callconv(convention) types.base.Status,

    ResetSystem: *const fn (
        reset_type: types.reset.ResetType,
        reset_status: types.base.Status,
        data_size: usize,
        reset_data: ?*const anyopaque,
    ) callconv(convention) noreturn,

    UpdateCapsule: *const fn (
        capsule_header_array: **CapsuleHeader,
        capsule_count: usize,
        scatter_gather_list: types.base.PhysicalAddress,
    ) callconv(convention) types.base.Status,

    QueryCapsuleCapabilities: *const fn (
        capsule_header_array: **CapsuleHeader,
        capsule_count: usize,
        maximum_capsule_size: *u64,
        reset_type: *types.reset.ResetType,
    ) callconv(convention) types.base.Status,

    QueryVariableInfo: *const fn (
        attributes: u32,
        maximum_variable_storage_size: *u64,
        remaining_variable_storage_size: *u64,
        maximum_variable_size: *u64,
    ) callconv(convention) types.base.Status,
};

pub const CapsuleHeader = extern struct {
    CapsuleGUID: types.base.GUID,
    HeaderSize: u32,
    Flags: u32,
    CapsuleImageSize: u32,
};
