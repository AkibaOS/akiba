//! Persona Build Inputs

pub const Profile = enum { Fixed, Dynamic, Pulse };

pub const Definition = struct {
    Name: []const u8,
    Root: []const u8,
    Entry: []const u8,
    Profile: Profile = .Dynamic,
    Linker: ?[]const u8 = null,
    Install: ?[]const u8 = null,
};
