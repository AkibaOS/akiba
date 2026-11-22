//! Load System Libraries From The Bound AFS Origin Stack

const std = @import("std");

const afs = @import("shared").afs;
const library = @import("weaver").library;
const location = @import("shared").location.strings.installed.paths;

const Catalog = afs.types.reader.Catalog;
const ReadError = library.errors.library.ReadError;
const Source = library.types.source.Source;

pub fn source(catalog: *const Catalog) Source {
    return .{ .Context = catalog, .ReadFromOrigin = read };
}

fn read(context: *const anyopaque, allocator: std.mem.Allocator, parent: []const []const u8, name: []const u8) ReadError!?[]u8 {
    const expected = location.SYSTEM_LIBRARY_PARTS;
    if (parent.len != expected.len) return null;
    for (parent, expected) |actual, component| if (!std.mem.eql(u8, actual, component)) return null;
    const catalog: *const Catalog = @ptrCast(@alignCast(context));
    const cell = try allocator.alloc(u8, catalog.Reader.CellSize);
    defer allocator.free(cell);
    const unit = (afs.read.catalog.open(catalog, &expected, name, cell) catch return error.LibraryReadFailed) orelse return null;
    const length = afs.read.unit.size(&catalog.Reader, &unit.DataChannel) catch return error.LibraryReadFailed;
    const count = std.math.cast(usize, length) orelse return error.LibraryReadFailed;
    const bytes = try allocator.alloc(u8, count);
    errdefer allocator.free(bytes);
    _ = afs.read.unit.readUnit(&catalog.Reader, &unit, bytes, cell) catch return error.LibraryReadFailed;
    return bytes;
}
