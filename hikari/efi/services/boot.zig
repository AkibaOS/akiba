//! Hikari EFI Boot Services

const constants = @import("../constants/constants.zig");
const types = @import("../types/types.zig");

const convention = constants.convention.CALLING_CONVENTION;

pub const BootServices = extern struct {
    Header: types.table.TableHeader,

    RaiseTpl: *const fn (new_tpl: usize) callconv(convention) usize,
    RestoreTpl: *const fn (old_tpl: usize) callconv(convention) void,

    AllocatePages: *const fn (
        allocate_type: types.memory.AllocateType,
        memory_type: types.memory.MemoryType,
        pages: usize,
        physical_address: *types.base.PhysicalAddress,
    ) callconv(convention) types.base.Status,

    FreePages: *const fn (
        physical_address: types.base.PhysicalAddress,
        pages: usize,
    ) callconv(convention) types.base.Status,

    GetMemoryMap: *const fn (
        memory_map_size: *usize,
        memory_map: [*]types.memory.MemoryDescriptor,
        map_key: *usize,
        descriptor_size: *usize,
        descriptor_version: *u32,
    ) callconv(convention) types.base.Status,

    AllocatePool: *const fn (
        pool_type: types.memory.MemoryType,
        size: usize,
        buffer: *[*]align(8) u8,
    ) callconv(convention) types.base.Status,

    FreePool: *const fn (
        buffer: [*]align(8) u8,
    ) callconv(convention) types.base.Status,

    CreateEvent: *const fn (
        event_type: u32,
        notify_tpl: usize,
        notify_function: ?*const fn (types.base.Event, ?*anyopaque) callconv(convention) void,
        notify_context: ?*anyopaque,
        event: *types.base.Event,
    ) callconv(convention) types.base.Status,

    SetTimer: *const fn (
        event: types.base.Event,
        timer_type: TimerDelay,
        trigger_time: u64,
    ) callconv(convention) types.base.Status,

    WaitForEvent: *const fn (
        number_of_events: usize,
        events: [*]const types.base.Event,
        index: *usize,
    ) callconv(convention) types.base.Status,

    SignalEvent: *const fn (
        event: types.base.Event,
    ) callconv(convention) types.base.Status,

    CloseEvent: *const fn (
        event: types.base.Event,
    ) callconv(convention) types.base.Status,

    CheckEvent: *const fn (
        event: types.base.Event,
    ) callconv(convention) types.base.Status,

    InstallProtocolInterface: *const fn (
        handle: *types.base.Handle,
        protocol: *align(8) const types.base.GUID,
        interface_type: InterfaceType,
        interface: ?*anyopaque,
    ) callconv(convention) types.base.Status,

    ReinstallProtocolInterface: *const fn (
        handle: types.base.Handle,
        protocol: *align(8) const types.base.GUID,
        old_interface: ?*anyopaque,
        new_interface: ?*anyopaque,
    ) callconv(convention) types.base.Status,

    UninstallProtocolInterface: *const fn (
        handle: types.base.Handle,
        protocol: *align(8) const types.base.GUID,
        interface: ?*anyopaque,
    ) callconv(convention) types.base.Status,

    HandleProtocol: *const fn (
        handle: types.base.Handle,
        protocol: *align(8) const types.base.GUID,
        interface: *?*anyopaque,
    ) callconv(convention) types.base.Status,

    Reserved: *anyopaque,

    RegisterProtocolNotify: *const fn (
        protocol: *align(8) const types.base.GUID,
        event: types.base.Event,
        registration: **anyopaque,
    ) callconv(convention) types.base.Status,

    LocateHandle: *const fn (
        search_type: types.memory.LocateSearchType,
        protocol: ?*align(8) const types.base.GUID,
        search_key: ?*anyopaque,
        buffer_size: *usize,
        buffer: [*]types.base.Handle,
    ) callconv(convention) types.base.Status,

    LocateDeviceLocation: *const fn (
        protocol: *align(8) const types.base.GUID,
        device_location: **anyopaque,
        device: *types.base.Handle,
    ) callconv(convention) types.base.Status,

    InstallConfigurationTable: *const fn (
        guid: *align(8) const types.base.GUID,
        table_ptr: ?*anyopaque,
    ) callconv(convention) types.base.Status,

    LoadImage: *const fn (
        boot_policy: bool,
        parent_image_handle: types.base.Handle,
        device_location: ?*anyopaque,
        source_buffer: ?[*]const u8,
        source_size: usize,
        image_handle: *types.base.Handle,
    ) callconv(convention) types.base.Status,

    StartImage: *const fn (
        image_handle: types.base.Handle,
        exit_data_size: *usize,
        exit_data: ?*[*]types.base.Char16,
    ) callconv(convention) types.base.Status,

    Exit: *const fn (
        image_handle: types.base.Handle,
        exit_status: types.base.Status,
        exit_data_size: usize,
        exit_data: ?[*]const types.base.Char16,
    ) callconv(convention) types.base.Status,

    UnloadImage: *const fn (
        image_handle: types.base.Handle,
    ) callconv(convention) types.base.Status,

    ExitBootServices: *const fn (
        image_handle: types.base.Handle,
        map_key: usize,
    ) callconv(convention) types.base.Status,

    GetNextMonotonicCount: *const fn (
        count: *u64,
    ) callconv(convention) types.base.Status,

    Stall: *const fn (
        microseconds: usize,
    ) callconv(convention) types.base.Status,

    SetWatchdogTimer: *const fn (
        timeout: usize,
        watchdog_code: u64,
        data_size: usize,
        watchdog_data: ?[*]const types.base.Char16,
    ) callconv(convention) types.base.Status,

    ConnectController: *const fn (
        controller_handle: types.base.Handle,
        driver_image_handle: ?types.base.Handle,
        remaining_device_location: ?*anyopaque,
        recursive: bool,
    ) callconv(convention) types.base.Status,

    DisconnectController: *const fn (
        controller_handle: types.base.Handle,
        driver_image_handle: ?types.base.Handle,
        child_handle: ?types.base.Handle,
    ) callconv(convention) types.base.Status,

    OpenProtocol: *const fn (
        handle: types.base.Handle,
        protocol: *align(8) const types.base.GUID,
        interface: ?*?*anyopaque,
        agent_handle: ?types.base.Handle,
        controller_handle: ?types.base.Handle,
        attributes: u32,
    ) callconv(convention) types.base.Status,

    CloseProtocol: *const fn (
        handle: types.base.Handle,
        protocol: *align(8) const types.base.GUID,
        agent_handle: types.base.Handle,
        controller_handle: ?types.base.Handle,
    ) callconv(convention) types.base.Status,

    OpenProtocolInformation: *const fn (
        handle: types.base.Handle,
        protocol: *align(8) const types.base.GUID,
        entry_buffer: *[*]OpenProtocolInformationEntry,
        entry_count: *usize,
    ) callconv(convention) types.base.Status,

    ProtocolsPerHandle: *const fn (
        handle: types.base.Handle,
        protocol_buffer: *[*]*align(8) types.base.GUID,
        protocol_buffer_count: *usize,
    ) callconv(convention) types.base.Status,

    LocateHandleBuffer: *const fn (
        search_type: types.memory.LocateSearchType,
        protocol: ?*align(8) const types.base.GUID,
        search_key: ?*anyopaque,
        handle_count: *usize,
        buffer: *[*]types.base.Handle,
    ) callconv(convention) types.base.Status,

    LocateProtocol: *const fn (
        protocol: *align(8) const types.base.GUID,
        registration: ?*anyopaque,
        interface: *?*anyopaque,
    ) callconv(convention) types.base.Status,

    InstallMultipleProtocolInterfaces: *const anyopaque,
    UninstallMultipleProtocolInterfaces: *const anyopaque,

    CalculateCRC32: *const fn (
        data: [*]const u8,
        data_size: usize,
        crc32: *u32,
    ) callconv(convention) types.base.Status,

    CopyMemory: *const fn (
        destination: [*]u8,
        source: [*]const u8,
        length: usize,
    ) callconv(convention) void,

    SetMemory: *const fn (
        buffer: [*]u8,
        size: usize,
        value: u8,
    ) callconv(convention) void,

    CreateEventEx: *const fn (
        event_type: u32,
        notify_tpl: usize,
        notify_function: ?*const fn (types.base.Event, ?*anyopaque) callconv(convention) void,
        notify_context: ?*const anyopaque,
        event_group: ?*align(8) const types.base.GUID,
        event: *types.base.Event,
    ) callconv(convention) types.base.Status,
};

pub const TimerDelay = enum(u32) {
    Cancel = 0,
    Periodic = 1,
    Relative = 2,
};

pub const InterfaceType = enum(u32) {
    Native = 0,
};

pub const OpenProtocolInformationEntry = extern struct {
    AgentHandle: types.base.Handle,
    ControllerHandle: types.base.Handle,
    Attributes: u32,
    OpenCount: u32,
};
