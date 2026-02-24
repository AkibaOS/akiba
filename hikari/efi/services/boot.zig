//! Hikari EFI Boot Services

const types = @import("../types/types.zig");
const table = @import("../types/table.zig");
const memory = @import("../types/memory.zig");

pub const BootServices = extern struct {
    header: table.TableHeader,

    raise_tpl: *const fn (new_tpl: usize) callconv(.C) usize,
    restore_tpl: *const fn (old_tpl: usize) callconv(.C) void,

    allocate_pages: *const fn (
        allocate_type: memory.AllocateType,
        memory_type: memory.MemoryType,
        pages: usize,
        physical_address: *types.PhysicalAddress,
    ) callconv(.C) types.Status,

    free_pages: *const fn (
        physical_address: types.PhysicalAddress,
        pages: usize,
    ) callconv(.C) types.Status,

    get_memory_map: *const fn (
        memory_map_size: *usize,
        memory_map: [*]memory.MemoryDescriptor,
        map_key: *usize,
        descriptor_size: *usize,
        descriptor_version: *u32,
    ) callconv(.C) types.Status,

    allocate_pool: *const fn (
        pool_type: memory.MemoryType,
        size: usize,
        buffer: *[*]align(8) u8,
    ) callconv(.C) types.Status,

    free_pool: *const fn (
        buffer: [*]align(8) u8,
    ) callconv(.C) types.Status,

    create_event: *const fn (
        event_type: u32,
        notify_tpl: usize,
        notify_function: ?*const fn (types.Event, ?*anyopaque) callconv(.C) void,
        notify_context: ?*anyopaque,
        event: *types.Event,
    ) callconv(.C) types.Status,

    set_timer: *const fn (
        event: types.Event,
        timer_type: TimerDelay,
        trigger_time: u64,
    ) callconv(.C) types.Status,

    wait_for_event: *const fn (
        number_of_events: usize,
        events: [*]const types.Event,
        index: *usize,
    ) callconv(.C) types.Status,

    signal_event: *const fn (
        event: types.Event,
    ) callconv(.C) types.Status,

    close_event: *const fn (
        event: types.Event,
    ) callconv(.C) types.Status,

    check_event: *const fn (
        event: types.Event,
    ) callconv(.C) types.Status,

    install_protocol_interface: *const fn (
        handle: *types.Handle,
        protocol: *align(8) const types.Guid,
        interface_type: InterfaceType,
        interface: ?*anyopaque,
    ) callconv(.C) types.Status,

    reinstall_protocol_interface: *const fn (
        handle: types.Handle,
        protocol: *align(8) const types.Guid,
        old_interface: ?*anyopaque,
        new_interface: ?*anyopaque,
    ) callconv(.C) types.Status,

    uninstall_protocol_interface: *const fn (
        handle: types.Handle,
        protocol: *align(8) const types.Guid,
        interface: ?*anyopaque,
    ) callconv(.C) types.Status,

    handle_protocol: *const fn (
        handle: types.Handle,
        protocol: *align(8) const types.Guid,
        interface: *?*anyopaque,
    ) callconv(.C) types.Status,

    reserved: *anyopaque,

    register_protocol_notify: *const fn (
        protocol: *align(8) const types.Guid,
        event: types.Event,
        registration: **anyopaque,
    ) callconv(.C) types.Status,

    locate_handle: *const fn (
        search_type: memory.LocateSearchType,
        protocol: ?*align(8) const types.Guid,
        search_key: ?*anyopaque,
        buffer_size: *usize,
        buffer: [*]types.Handle,
    ) callconv(.C) types.Status,

    locate_device_location: *const fn (
        protocol: *align(8) const types.Guid,
        device_location: **anyopaque,
        device: *types.Handle,
    ) callconv(.C) types.Status,

    install_configuration_table: *const fn (
        guid: *align(8) const types.Guid,
        table_ptr: ?*anyopaque,
    ) callconv(.C) types.Status,

    load_image: *const fn (
        boot_policy: bool,
        parent_image_handle: types.Handle,
        device_location: ?*anyopaque,
        source_buffer: ?[*]const u8,
        source_size: usize,
        image_handle: *types.Handle,
    ) callconv(.C) types.Status,

    start_image: *const fn (
        image_handle: types.Handle,
        exit_data_size: *usize,
        exit_data: ?*[*]types.Char16,
    ) callconv(.C) types.Status,

    exit: *const fn (
        image_handle: types.Handle,
        exit_status: types.Status,
        exit_data_size: usize,
        exit_data: ?[*]const types.Char16,
    ) callconv(.C) types.Status,

    unload_image: *const fn (
        image_handle: types.Handle,
    ) callconv(.C) types.Status,

    exit_boot_services: *const fn (
        image_handle: types.Handle,
        map_key: usize,
    ) callconv(.C) types.Status,

    get_next_monotonic_count: *const fn (
        count: *u64,
    ) callconv(.C) types.Status,

    stall: *const fn (
        microseconds: usize,
    ) callconv(.C) types.Status,

    set_watchdog_timer: *const fn (
        timeout: usize,
        watchdog_code: u64,
        data_size: usize,
        watchdog_data: ?[*]const types.Char16,
    ) callconv(.C) types.Status,

    connect_controller: *const fn (
        controller_handle: types.Handle,
        driver_image_handle: ?types.Handle,
        remaining_device_location: ?*anyopaque,
        recursive: bool,
    ) callconv(.C) types.Status,

    disconnect_controller: *const fn (
        controller_handle: types.Handle,
        driver_image_handle: ?types.Handle,
        child_handle: ?types.Handle,
    ) callconv(.C) types.Status,

    open_protocol: *const fn (
        handle: types.Handle,
        protocol: *align(8) const types.Guid,
        interface: ?*?*anyopaque,
        agent_handle: ?types.Handle,
        controller_handle: ?types.Handle,
        attributes: u32,
    ) callconv(.C) types.Status,

    close_protocol: *const fn (
        handle: types.Handle,
        protocol: *align(8) const types.Guid,
        agent_handle: types.Handle,
        controller_handle: ?types.Handle,
    ) callconv(.C) types.Status,

    open_protocol_information: *const fn (
        handle: types.Handle,
        protocol: *align(8) const types.Guid,
        entry_buffer: *[*]OpenProtocolInformationEntry,
        entry_count: *usize,
    ) callconv(.C) types.Status,

    protocols_per_handle: *const fn (
        handle: types.Handle,
        protocol_buffer: *[*]*align(8) types.Guid,
        protocol_buffer_count: *usize,
    ) callconv(.C) types.Status,

    locate_handle_buffer: *const fn (
        search_type: memory.LocateSearchType,
        protocol: ?*align(8) const types.Guid,
        search_key: ?*anyopaque,
        handle_count: *usize,
        buffer: *[*]types.Handle,
    ) callconv(.C) types.Status,

    locate_protocol: *const fn (
        protocol: *align(8) const types.Guid,
        registration: ?*anyopaque,
        interface: *?*anyopaque,
    ) callconv(.C) types.Status,

    install_multiple_protocol_interfaces: *const anyopaque,
    uninstall_multiple_protocol_interfaces: *const anyopaque,

    calculate_crc32: *const fn (
        data: [*]const u8,
        data_size: usize,
        crc32: *u32,
    ) callconv(.C) types.Status,

    copy_memory: *const fn (
        destination: [*]u8,
        source: [*]const u8,
        length: usize,
    ) callconv(.C) void,

    set_memory: *const fn (
        buffer: [*]u8,
        size: usize,
        value: u8,
    ) callconv(.C) void,

    create_event_ex: *const fn (
        event_type: u32,
        notify_tpl: usize,
        notify_function: ?*const fn (types.Event, ?*anyopaque) callconv(.C) void,
        notify_context: ?*const anyopaque,
        event_group: ?*align(8) const types.Guid,
        event: *types.Event,
    ) callconv(.C) types.Status,
};

pub const TimerDelay = enum(u32) {
    cancel = 0,
    periodic = 1,
    relative = 2,
};

pub const InterfaceType = enum(u32) {
    native = 0,
};

pub const OpenProtocolInformationEntry = extern struct {
    agent_handle: types.Handle,
    controller_handle: types.Handle,
    attributes: u32,
    open_count: u32,
};

pub const open_protocol_by_handle_protocol: u32 = 0x00000001;
pub const open_protocol_get_protocol: u32 = 0x00000002;
pub const open_protocol_test_protocol: u32 = 0x00000004;
pub const open_protocol_by_child_controller: u32 = 0x00000008;
pub const open_protocol_by_driver: u32 = 0x00000010;
pub const open_protocol_exclusive: u32 = 0x00000020;

pub const tpl_application: usize = 4;
pub const tpl_callback: usize = 8;
pub const tpl_notify: usize = 16;
pub const tpl_high_level: usize = 31;

pub const event_timer: u32 = 0x80000000;
pub const event_runtime: u32 = 0x40000000;
pub const event_notify_wait: u32 = 0x00000100;
pub const event_notify_signal: u32 = 0x00000200;
pub const event_signal_exit_boot_services: u32 = 0x00000201;
pub const event_signal_virtual_address_change: u32 = 0x60000202;
