//! Normalized Keyboard Text And Editing Events

pub const Kind = enum(u8) { Text, Key };

pub const Key = enum(u32) {
    Escape,
    Backspace,
    Tab,
    Enter,
    Home,
    End,
    Left,
    Right,
    Up,
    Down,
    Insert,
    Delete,
    PageUp,
    PageDown,
    Pause,
};

pub const Modifiers = packed struct(u8) {
    Shift: bool = false,
    Control: bool = false,
    Alt: bool = false,
    CapsLock: bool = false,
    Reserved: u4 = 0,
};

pub const Event = extern struct {
    Kind: Kind,
    Modifiers: Modifiers = .{},
    Reserved: u16 = 0,
    Value: u32,
};
