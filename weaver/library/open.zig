//! Select And Validate One Native System Library

const std = @import("std");

const afs = @import("shared").afs;
const elf = @import("shared").elf;
const library = @import("weaver").library;
const location = @import("weaver").library.strings.location;
const separators = @import("utils").path.constants.separators;

const Library = library.types.library.Library;
const LibraryError = library.errors.library.LibraryError;
const Metadata = elf.types.dynamic.Metadata;
const Source = library.types.source.Source;

pub fn open(allocator: std.mem.Allocator, source: Source, name: []const u8) LibraryError!Library {
    try checkName(name);
    const bytes = (try source.ReadFromOrigin(source.Context, allocator, &location.SYSTEM_LIBRARIES, name)) orelse return error.LibraryNotFound;
    errdefer allocator.free(bytes);
    const metadata = try elf.read.dynamic.read(bytes);
    const identity = try checkIdentity(metadata, name);
    return .{ .Allocator = allocator, .Bytes = bytes, .Identity = identity, .Metadata = metadata };
}

fn checkName(name: []const u8) LibraryError!void {
    if (name.len <= location.LIBRARY_SUFFIX.len or name.len > @as(afs.types.btree.IndexKey, undefined).Identity.len or
        !std.mem.endsWith(u8, name, location.LIBRARY_SUFFIX)) return error.InvalidLibraryName;
    for (name) |character| {
        switch (character) {
            0, separators.FORWARD_SLASH, separators.BACK_SLASH => return error.InvalidLibraryName,
            else => {},
        }
    }
}

fn checkIdentity(metadata: Metadata, name: []const u8) LibraryError![]const u8 {
    for (metadata.Entries) |entry| {
        if (entry.Tag != elf.constants.dynamic.SONAME) continue;
        const identity = try metadata.string(entry.Value);
        if (!std.mem.eql(u8, identity, name)) return error.LibraryNameMismatch;
        return identity;
    }
    return error.LibraryNameMismatch;
}
