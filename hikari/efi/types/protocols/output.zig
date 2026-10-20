//! Hikari EFI Simple Text Output Protocol

const constants = @import("hikari").efi.constants;
const types = @import("hikari").efi.types;

const convention = constants.convention.CALLING_CONVENTION;

pub const SimpleTextOutputProtocol = extern struct {
    Reset: *const fn (
        self: *SimpleTextOutputProtocol,
        extended_verification: bool,
    ) callconv(convention) types.base.Status,

    OutputString: *const fn (
        self: *SimpleTextOutputProtocol,
        string: [*:0]const types.base.Char16,
    ) callconv(convention) types.base.Status,

    TestString: *const fn (
        self: *SimpleTextOutputProtocol,
        string: [*:0]const types.base.Char16,
    ) callconv(convention) types.base.Status,

    QueryMode: *const fn (
        self: *SimpleTextOutputProtocol,
        mode_number: usize,
        columns: *usize,
        rows: *usize,
    ) callconv(convention) types.base.Status,

    SetMode: *const fn (
        self: *SimpleTextOutputProtocol,
        mode_number: usize,
    ) callconv(convention) types.base.Status,

    SetAttribute: *const fn (
        self: *SimpleTextOutputProtocol,
        attribute: usize,
    ) callconv(convention) types.base.Status,

    ClearScreen: *const fn (
        self: *SimpleTextOutputProtocol,
    ) callconv(convention) types.base.Status,

    SetCursorPosition: *const fn (
        self: *SimpleTextOutputProtocol,
        column: usize,
        row: usize,
    ) callconv(convention) types.base.Status,

    EnableCursor: *const fn (
        self: *SimpleTextOutputProtocol,
        visible: bool,
    ) callconv(convention) types.base.Status,

    Mode: *SimpleTextOutputMode,
};

pub const SimpleTextOutputMode = extern struct {
    MaxMode: i32,
    Mode: i32,
    Attribute: i32,
    CursorColumn: i32,
    CursorRow: i32,
    CursorVisible: bool,
};
