const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .freestanding,
        .abi = .none,
    });

    var lib_dir = std.fs.cwd().openDir(".", .{ .iterate = true }) catch return;
    defer lib_dir.close();

    var lib_iter = lib_dir.iterate();
    while (lib_iter.next() catch null) |entry| {
        if (entry.kind != .directory) continue;

        const lib_name = b.allocator.dupe(u8, entry.name) catch continue;
        const lib_file = std.fmt.allocPrint(b.allocator, "{s}/{s}.zig", .{ lib_name, lib_name }) catch continue;

        std.fs.cwd().access(lib_file, .{}) catch continue;

        const lib = b.addLibrary(.{
            .name = lib_name,
            .root_module = b.createModule(.{
                .root_source_file = b.path(lib_file),
                .target = target,
                .optimize = .ReleaseSmall,
            }),
        });

        lib.linkage = .static;
        b.installArtifact(lib);
    }
}
