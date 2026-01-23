//! Akiba Executable Format (.akiba)
//! Wraps ELF64 with Akiba-specific metadata and branding

const serial = @import("../drivers/serial.zig");

// Akiba magic signature
pub const AKIBA_MAGIC = [8]u8{ 'A', 'K', 'I', 'B', 'A', 'E', 'L', 'F' };

// Akiba format version
pub const AKIBA_VERSION: u32 = 1;

// Executable types
pub const AKIBA_TYPE_CLI: u32 = 0; // Command-line program
pub const AKIBA_TYPE_GUI: u32 = 1; // GUI application
pub const AKIBA_TYPE_SERVICE: u32 = 2; // Background service
pub const AKIBA_TYPE_LIBRARY: u32 = 3; // Shared library

// Akiba executable header (64 bytes, aligned)
pub const AkibaHeader = extern struct {
    magic: [8]u8, // "AKIBAELF"
    version: u32, // Format version (1)
    exec_type: u32, // Executable type
    elf_offset: u64, // Offset to ELF binary
    elf_size: u64, // Size of ELF binary
    metadata_offset: u64, // Offset to metadata (0 if none)
    metadata_size: u64, // Size of metadata (0 if none)
    entry_point: u64, // Quick access to entry point (from ELF)
    reserved: [16]u8, // Reserved for future use
};

// Optional metadata (for GUI apps, icons, etc.)
pub const AkibaMetadata = struct {
    name: [64]u8, // Program name
    version: [16]u8, // Version string
    author: [64]u8, // Author name
    description: [256]u8, // Description
    icon_offset: u64, // Offset to icon data (0 if none)
    icon_size: u64, // Size of icon data
};

pub const AkibaExecutable = struct {
    header: AkibaHeader,
    elf_data: []const u8,
    metadata: ?AkibaMetadata,
};

pub fn parse_akiba(data: []const u8) !AkibaExecutable {
    // Verify minimum size
    if (data.len < @sizeOf(AkibaHeader)) {
        return error.TooSmall;
    }

    // Parse header
    const header = @as(*const AkibaHeader, @ptrCast(@alignCast(data.ptr)));

    // Validate magic
    for (AKIBA_MAGIC, 0..) |byte, i| {
        if (header.magic[i] != byte) {
            return error.InvalidMagic;
        }
    }

    // Validate version
    if (header.version != AKIBA_VERSION) {
        return error.UnsupportedVersion;
    }

    // Validate type
    const type_name = switch (header.exec_type) {
        AKIBA_TYPE_CLI => "CLI",
        AKIBA_TYPE_GUI => "GUI",
        AKIBA_TYPE_SERVICE => "Service",
        AKIBA_TYPE_LIBRARY => "Library",
        else => "Unknown",
    };
    _ = type_name;

    // Validate ELF offset and size
    if (header.elf_offset + header.elf_size > data.len) {
        return error.InvalidELFBounds;
    }

    // Extract ELF data
    const elf_data = data[header.elf_offset .. header.elf_offset + header.elf_size];

    // Parse metadata if present
    var metadata: ?AkibaMetadata = null;
    if (header.metadata_offset > 0 and header.metadata_size > 0) {
        if (header.metadata_offset + header.metadata_size <= data.len) {
            const meta_ptr = data.ptr + header.metadata_offset;
            metadata = @as(*const AkibaMetadata, @ptrCast(@alignCast(meta_ptr))).*;
        }
    }

    return AkibaExecutable{
        .header = header.*,
        .elf_data = elf_data,
        .metadata = metadata,
    };
}

pub fn validate_akiba_magic(data: []const u8) bool {
    if (data.len < 8) return false;

    for (AKIBA_MAGIC, 0..) |byte, i| {
        if (data[i] != byte) return false;
    }

    return true;
}
