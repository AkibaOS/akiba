//! Standalone Persona ELF Build Inputs

pub const Definition = struct {
    Name: []const u8,
    Root: []const u8,
    Entry: []const u8,
    Symbol: []const u8,
    Linker: []const u8,
};
