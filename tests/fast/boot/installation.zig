//! Verify Canonical Installed Bundle And Init Locations

const std = @import("std");

const fixtures = @import("tests").fast.strings.boot.installation;
const installed = @import("shared").location.installed.resolve;
const paths = @import("shared").location.strings.installed.paths;

pub fn names() !void {
    var buffer: [256]u8 = undefined;
    try std.testing.expectEqualStrings(fixtures.DRIVER, try installed.bundleName(&buffer, fixtures.IDENTITY, .Driver));
    try std.testing.expectEqualStrings(fixtures.BUNDLE, try installed.bundleName(&buffer, fixtures.IDENTITY, .Binary));
    try std.testing.expectEqualStrings(fixtures.MANIFEST, try installed.memberPath(&buffer, .SystemDriver, fixtures.IDENTITY, .Manifest));
    try std.testing.expectEqualStrings(fixtures.BINARY, try installed.memberPath(&buffer, .SystemBinary, fixtures.IDENTITY, .Binary));
    try std.testing.expectEqualStrings(fixtures.USER, try installed.memberPath(&buffer, .UserBinary, fixtures.IDENTITY, .Binary));
    try std.testing.expectEqualStrings(fixtures.PULSE, paths.PULSE_PATH);
    try std.testing.expectError(error.NoSpaceLeft, installed.memberPath(buffer[0..1], .SystemDriver, fixtures.IDENTITY, .Binary));
}

pub fn rejectsAliases() !void {
    var buffer: [256]u8 = undefined;
    for (fixtures.VALID) |identity| try std.testing.expect(installed.validIdentity(identity));
    for (fixtures.INVALID) |identity| {
        try std.testing.expect(!installed.validIdentity(identity));
        try std.testing.expectError(error.InvalidIdentity, installed.bundleName(&buffer, identity, .Binary));
        try std.testing.expectError(error.InvalidIdentity, installed.memberPath(&buffer, .SystemDriver, identity, .Manifest));
    }
    const boundary = [_]u8{'a'} ** 129;
    try std.testing.expect(installed.validIdentity(boundary[0..128]));
    try std.testing.expect(!installed.validIdentity(&boundary));
}
