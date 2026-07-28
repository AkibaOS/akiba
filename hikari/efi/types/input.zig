//! Hikari EFI Input Types

const base = @import("hikari").efi.types.base;

pub const InputKey = extern struct {
    ScanCode: u16,
    UnicodeChar: base.Char16,
};
