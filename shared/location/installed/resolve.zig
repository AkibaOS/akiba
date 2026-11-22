//! Derive Exact Locations From A Validated Logical Bundle Identity

const std = @import("std");

const format = @import("shared").location.strings.installed.format;
const limits = @import("shared").location.constants.installed.identity;
const paths = @import("shared").location.strings.installed.paths;
const reserved = @import("shared").location.strings.installed.reserved;

const Kind = @import("shared").location.types.installed.location.Kind;
const Member = @import("shared").location.types.installed.location.Member;
const Scope = @import("shared").location.types.installed.location.Scope;

pub fn validIdentity(id: []const u8) bool {
    if (id.len == 0 or id.len > limits.MAX_BYTES or !lower(id[0])) return false;
    var hyphen = false;
    for (id[1..]) |character| {
        if (character == '-') {
            if (hyphen) return false;
            hyphen = true;
        } else {
            if (!lower(character) and !std.ascii.isDigit(character)) return false;
            hyphen = false;
        }
    }
    return !hyphen and !reservedName(id);
}

pub fn bundleName(out: []u8, id: []const u8, kind: Kind) ![]const u8 {
    if (!validIdentity(id)) return error.InvalidIdentity;
    return std.fmt.bufPrint(out, format.BUNDLE, .{ id, suffix(kind) });
}

pub fn memberPath(out: []u8, scope: Scope, id: []const u8, member: Member) ![]const u8 {
    if (!validIdentity(id)) return error.InvalidIdentity;
    const unit = switch (member) {
        .Manifest => paths.MANIFEST_UNIT,
        .Binary => paths.BINARY_UNIT,
    };
    return std.fmt.bufPrint(out, format.MEMBER, .{ scopePath(scope), id, suffix(scopeKind(scope)), unit });
}

pub fn scopePath(scope: Scope) []const u8 {
    return switch (scope) {
        .SystemBinary => paths.SYSTEM_BINARIES,
        .UserBinary => paths.BINARIES,
        .SystemDriver => paths.SYSTEM_DRIVERS,
    };
}

pub fn scopeKind(scope: Scope) Kind {
    return if (scope == .SystemDriver) .Driver else .Binary;
}

pub fn suffix(kind: Kind) []const u8 {
    return switch (kind) {
        .Binary => paths.BUNDLE_SUFFIX,
        .Driver => paths.DRIVER_SUFFIX,
    };
}

fn lower(character: u8) bool {
    return character >= 'a' and character <= 'z';
}

fn reservedName(id: []const u8) bool {
    for (reserved.EXACT) |name| if (std.mem.eql(u8, name, id)) return true;
    for (reserved.NUMBERED) |prefix| {
        if (id.len != prefix.len + 1 or !std.mem.startsWith(u8, id, prefix)) continue;
        const digit = id[prefix.len];
        if (digit >= '1' and digit <= '9') return true;
    }
    return false;
}
