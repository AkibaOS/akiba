//! Akiba format parser

const akiba_const = @import("../../common/constants/akiba.zig");
const types = @import("types.zig");

pub fn parse(data: []const u8) !types.Executable {
    if (data.len < @sizeOf(types.Header)) {
        return error.TooSmall;
    }

    const header = @as(*const types.Header, @ptrCast(@alignCast(data.ptr)));

    for (akiba_const.MAGIC, 0..) |byte, i| {
        if (header.magic[i] != byte) {
            return error.InvalidMagic;
        }
    }

    if (header.version == 0 or header.version > akiba_const.VERSION) {
        return error.UnsupportedVersion;
    }

    if (header.exec_type > akiba_const.TYPE_LIBRARY) {
        return error.InvalidExecutableType;
    }

    if (header.elf_size == 0) {
        return error.EmptyELF;
    }

    if (header.elf_offset < @sizeOf(types.Header)) {
        return error.InvalidELFOffset;
    }

    if (header.elf_offset + header.elf_size > data.len) {
        return error.InvalidELFBounds;
    }

    const elf_data = data[header.elf_offset .. header.elf_offset + header.elf_size];

    var metadata: ?types.Metadata = null;
    if (header.metadata_offset > 0 and header.metadata_size > 0) {
        if (header.metadata_offset + header.metadata_size <= data.len) {
            const meta_ptr = data.ptr + header.metadata_offset;
            metadata = @as(*const types.Metadata, @ptrCast(@alignCast(meta_ptr))).*;
        }
    }

    return types.Executable{
        .header = header.*,
        .elf_data = elf_data,
        .metadata = metadata,
    };
}

pub fn validate_magic(data: []const u8) bool {
    if (data.len < 8) return false;

    for (akiba_const.MAGIC, 0..) |byte, i| {
        if (data[i] != byte) return false;
    }

    return true;
}
