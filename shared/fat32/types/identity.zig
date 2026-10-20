//! Parsed FAT32 Identity

pub const ParsedIdentity = struct {
    Name: []const u8,
    Extension: []const u8,
};
