//! Export The Exact Built Image Artifact List

const std = @import("std");

const messages = @import("../strings/persona/messages.zig");
const paths = @import("../strings/paths.zig");

const Output = @import("../types/persona/artifacts.zig").Output;

pub fn install(builder: *std.Build, outputs: []const Output) *std.Build.Step {
    var text: std.ArrayList(u8) = .empty;
    for (outputs) |output| {
        if (std.mem.indexOfAny(u8, output.Path, messages.FORBIDDEN_PATH_BYTES) != null) @panic(messages.INVALID_PATH);
        var parts = std.mem.splitScalar(u8, output.Path, '/');
        while (parts.next()) |part| if (part.len == 0 or std.mem.allEqual(u8, part, '.')) @panic(messages.INVALID_PATH);
        text.appendSlice(builder.allocator, builder.fmt(messages.MANIFEST_LINE, .{output.Path})) catch @panic(messages.OUT_OF_MEMORY);
    }
    const manifest = builder.addWriteFiles().add(paths.INSTALL_MANIFEST, text.items);
    return &builder.addInstallFile(manifest, paths.INSTALL_MANIFEST).step;
}
