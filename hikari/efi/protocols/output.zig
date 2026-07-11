//! Hikari EFI Simple Text Output Protocol

const efi = @import("../efi.zig");
const types = @import("../types/types.zig");

pub const SimpleTextOutputProtocol = extern struct {
    reset: *const fn (
        self: *SimpleTextOutputProtocol,
        extended_verification: bool,
    ) callconv(efi.akiba) types.Status,

    output_string: *const fn (
        self: *SimpleTextOutputProtocol,
        string: [*:0]const types.Char16,
    ) callconv(efi.akiba) types.Status,

    test_string: *const fn (
        self: *SimpleTextOutputProtocol,
        string: [*:0]const types.Char16,
    ) callconv(efi.akiba) types.Status,

    query_mode: *const fn (
        self: *SimpleTextOutputProtocol,
        mode_number: usize,
        columns: *usize,
        rows: *usize,
    ) callconv(efi.akiba) types.Status,

    set_mode: *const fn (
        self: *SimpleTextOutputProtocol,
        mode_number: usize,
    ) callconv(efi.akiba) types.Status,

    set_attribute: *const fn (
        self: *SimpleTextOutputProtocol,
        attribute: usize,
    ) callconv(efi.akiba) types.Status,

    clear_screen: *const fn (
        self: *SimpleTextOutputProtocol,
    ) callconv(efi.akiba) types.Status,

    set_cursor_position: *const fn (
        self: *SimpleTextOutputProtocol,
        column: usize,
        row: usize,
    ) callconv(efi.akiba) types.Status,

    enable_cursor: *const fn (
        self: *SimpleTextOutputProtocol,
        visible: bool,
    ) callconv(efi.akiba) types.Status,

    mode: *SimpleTextOutputMode,
};

pub const SimpleTextOutputMode = extern struct {
    max_mode: i32,
    mode: i32,
    attribute: i32,
    cursor_column: i32,
    cursor_row: i32,
    cursor_visible: bool,
};

pub const text_attribute_black: usize = 0x00;
pub const text_attribute_blue: usize = 0x01;
pub const text_attribute_green: usize = 0x02;
pub const text_attribute_cyan: usize = 0x03;
pub const text_attribute_red: usize = 0x04;
pub const text_attribute_magenta: usize = 0x05;
pub const text_attribute_brown: usize = 0x06;
pub const text_attribute_lightgray: usize = 0x07;
pub const text_attribute_bright: usize = 0x08;
pub const text_attribute_darkgray: usize = 0x08;
pub const text_attribute_lightblue: usize = 0x09;
pub const text_attribute_lightgreen: usize = 0x0A;
pub const text_attribute_lightcyan: usize = 0x0B;
pub const text_attribute_lightred: usize = 0x0C;
pub const text_attribute_lightmagenta: usize = 0x0D;
pub const text_attribute_yellow: usize = 0x0E;
pub const text_attribute_white: usize = 0x0F;

pub const background_black: usize = 0x00;
pub const background_blue: usize = 0x10;
pub const background_green: usize = 0x20;
pub const background_cyan: usize = 0x30;
pub const background_red: usize = 0x40;
pub const background_magenta: usize = 0x50;
pub const background_brown: usize = 0x60;
pub const background_lightgray: usize = 0x70;
