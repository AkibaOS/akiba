//! Hikari EFI Unit Protocol

const constants = @import("../constants/constants.zig");
const types = @import("../types/types.zig");

const convention = constants.convention.CALLING_CONVENTION;

pub const UnitProtocol = extern struct {
    Revision: u64,

    Open: *const fn (
        self: *UnitProtocol,
        new_handle: **UnitProtocol,
        unit_name: [*:0]const types.base.Char16,
        open_mode: u64,
        attributes: u64,
    ) callconv(convention) types.base.Status,

    Close: *const fn (
        self: *UnitProtocol,
    ) callconv(convention) types.base.Status,

    Delete: *const fn (
        self: *UnitProtocol,
    ) callconv(convention) types.base.Status,

    Read: *const fn (
        self: *UnitProtocol,
        buffer_size: *usize,
        buffer: [*]u8,
    ) callconv(convention) types.base.Status,

    Write: *const fn (
        self: *UnitProtocol,
        buffer_size: *usize,
        buffer: [*]const u8,
    ) callconv(convention) types.base.Status,

    GetPosition: *const fn (
        self: *UnitProtocol,
        position: *u64,
    ) callconv(convention) types.base.Status,

    SetPosition: *const fn (
        self: *UnitProtocol,
        position: u64,
    ) callconv(convention) types.base.Status,

    GetInfo: *const fn (
        self: *UnitProtocol,
        information_type: *align(8) const types.base.GUID,
        buffer_size: *usize,
        buffer: [*]u8,
    ) callconv(convention) types.base.Status,

    SetInfo: *const fn (
        self: *UnitProtocol,
        information_type: *align(8) const types.base.GUID,
        buffer_size: usize,
        buffer: [*]const u8,
    ) callconv(convention) types.base.Status,

    Flush: *const fn (
        self: *UnitProtocol,
    ) callconv(convention) types.base.Status,

    OpenEx: *const fn (
        self: *UnitProtocol,
        new_handle: **UnitProtocol,
        unit_name: [*:0]const types.base.Char16,
        open_mode: u64,
        attributes: u64,
        token: *UnitIoToken,
    ) callconv(convention) types.base.Status,

    ReadEx: *const fn (
        self: *UnitProtocol,
        token: *UnitIoToken,
    ) callconv(convention) types.base.Status,

    WriteEx: *const fn (
        self: *UnitProtocol,
        token: *UnitIoToken,
    ) callconv(convention) types.base.Status,

    FlushEx: *const fn (
        self: *UnitProtocol,
        token: *UnitIoToken,
    ) callconv(convention) types.base.Status,
};

pub const UnitIoToken = extern struct {
    Event: types.base.Event,
    Status: types.base.Status,
    BufferSize: usize,
    Buffer: ?*anyopaque,
};
