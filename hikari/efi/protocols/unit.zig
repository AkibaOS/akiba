//! Hikari EFI Unit Protocol

const efi = @import("../efi.zig");
const types = @import("../types/types.zig");

pub const UnitProtocol = extern struct {
    revision: u64,

    open: *const fn (
        self: *UnitProtocol,
        new_handle: **UnitProtocol,
        unit_name: [*:0]const types.Char16,
        open_mode: u64,
        attributes: u64,
    ) callconv(efi.akiba) types.Status,

    close: *const fn (
        self: *UnitProtocol,
    ) callconv(efi.akiba) types.Status,

    delete: *const fn (
        self: *UnitProtocol,
    ) callconv(efi.akiba) types.Status,

    read: *const fn (
        self: *UnitProtocol,
        buffer_size: *usize,
        buffer: [*]u8,
    ) callconv(efi.akiba) types.Status,

    write: *const fn (
        self: *UnitProtocol,
        buffer_size: *usize,
        buffer: [*]const u8,
    ) callconv(efi.akiba) types.Status,

    get_position: *const fn (
        self: *UnitProtocol,
        position: *u64,
    ) callconv(efi.akiba) types.Status,

    set_position: *const fn (
        self: *UnitProtocol,
        position: u64,
    ) callconv(efi.akiba) types.Status,

    get_info: *const fn (
        self: *UnitProtocol,
        information_type: *align(8) const types.Guid,
        buffer_size: *usize,
        buffer: [*]u8,
    ) callconv(efi.akiba) types.Status,

    set_info: *const fn (
        self: *UnitProtocol,
        information_type: *align(8) const types.Guid,
        buffer_size: usize,
        buffer: [*]const u8,
    ) callconv(efi.akiba) types.Status,

    flush: *const fn (
        self: *UnitProtocol,
    ) callconv(efi.akiba) types.Status,

    open_ex: *const fn (
        self: *UnitProtocol,
        new_handle: **UnitProtocol,
        unit_name: [*:0]const types.Char16,
        open_mode: u64,
        attributes: u64,
        token: *UnitIoToken,
    ) callconv(efi.akiba) types.Status,

    read_ex: *const fn (
        self: *UnitProtocol,
        token: *UnitIoToken,
    ) callconv(efi.akiba) types.Status,

    write_ex: *const fn (
        self: *UnitProtocol,
        token: *UnitIoToken,
    ) callconv(efi.akiba) types.Status,

    flush_ex: *const fn (
        self: *UnitProtocol,
        token: *UnitIoToken,
    ) callconv(efi.akiba) types.Status,
};

pub const UnitIoToken = extern struct {
    event: types.Event,
    status: types.Status,
    buffer_size: usize,
    buffer: ?*anyopaque,
};

pub const unit_position_end: u64 = 0xFFFFFFFFFFFFFFFF;
