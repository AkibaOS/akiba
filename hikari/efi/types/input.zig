//! Hikari EFI Input Types

const base = @import("base.zig");

pub const InputKey = extern struct {
    ScanCode: u16,
    UnicodeChar: base.Char16,
};
