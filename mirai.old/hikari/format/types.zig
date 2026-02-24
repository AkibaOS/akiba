//! Akiba format type definitions

pub const Header = extern struct {
    magic: [8]u8,
    version: u32,
    exec_type: u32,
    elf_offset: u64,
    elf_size: u64,
    metadata_offset: u64,
    metadata_size: u64,
    entry_point: u64,
    reserved: [16]u8,
};

pub const Metadata = struct {
    name: [64]u8,
    version: [16]u8,
    author: [64]u8,
    description: [256]u8,
    icon_offset: u64,
    icon_size: u64,
};

pub const Executable = struct {
    header: Header,
    elf_data: []const u8,
    metadata: ?Metadata,
};
