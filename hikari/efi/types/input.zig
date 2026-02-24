//! Hikari EFI Input Types

const base = @import("base.zig");

pub const InputKey = extern struct {
    scan_code: u16,
    unicode_char: base.Char16,
};
