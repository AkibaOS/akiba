//! Resolve And Validate Exact Installed Bundle Members

const std = @import("std");

const executable = @import("shared").elf.read.executable;
const limits = @import("shared").bundle.constants.contract;
const location = @import("shared").location.installed.resolve;
const manifest = @import("shared").bundle.manifest.read;
const paths = @import("shared").location.constants.installed.identity;

const Descriptor = @import("shared").bundle.types.manifest.descriptor.Descriptor;
const Reader = @import("shared").bundle.types.installed.reader.Reader;
const ResolveError = @import("shared").bundle.errors.installed.resolve.ResolveError;
const Scope = @import("shared").location.types.installed.location.Scope;
const Snapshot = @import("shared").bundle.types.installed.snapshot.Snapshot;

pub fn open(reader: Reader, allocator: std.mem.Allocator, scope: Scope, identity: []const u8, maximum: usize) ResolveError!Snapshot {
    const description = try describe(reader, allocator, scope, identity);
    var buffer: [paths.MAX_PATH_BYTES]u8 = undefined;
    const path = location.memberPath(&buffer, scope, identity, .Binary) catch return error.InvalidIdentity;
    const bytes = (try reader.Read(reader.Context, allocator, path, maximum)) orelse return error.MissingBinary;
    errdefer allocator.free(bytes);
    executable.check(bytes) catch return error.InvalidExecutable;
    return .{ .Description = description, .Bytes = bytes };
}

pub fn describe(reader: Reader, allocator: std.mem.Allocator, scope: Scope, identity: []const u8) ResolveError!Descriptor {
    var buffer: [paths.MAX_PATH_BYTES]u8 = undefined;
    const path = location.memberPath(&buffer, scope, identity, .Manifest) catch return error.InvalidIdentity;
    const bytes = (try reader.Read(reader.Context, allocator, path, limits.MAX_MANIFEST_BYTES)) orelse return error.MissingManifest;
    defer allocator.free(bytes);
    const description = try manifest.parse(allocator, bytes);
    if ((scope == .SystemDriver) != (description.Type == .Driver)) return error.TypeMismatch;
    if (description.Type == .Gui) return error.UnsupportedType;
    return description;
}

pub fn checkBinary(reader: Reader, scope: Scope, identity: []const u8) ResolveError!void {
    var buffer: [paths.MAX_PATH_BYTES]u8 = undefined;
    const path = location.memberPath(&buffer, scope, identity, .Binary) catch return error.InvalidIdentity;
    const length = (try reader.Size(reader.Context, path)) orelse return error.MissingBinary;
    if (length == 0) return error.InvalidExecutable;
}
