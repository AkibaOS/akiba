const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 4) {
        std.debug.print("Usage: akibacompile <binary_dir> <output> <libraries_dir>\n", .{});
        return error.InvalidArgs;
    }

    const binary_dir = args[1];
    const output_path = args[2];
    const libraries_dir = args[3];

    const bin_name = std.fs.path.basename(binary_dir);
    const zig_file = try std.fmt.allocPrint(allocator, "{s}/{s}.zig", .{ binary_dir, bin_name });
    defer allocator.free(zig_file);

    const zon_file = try std.fmt.allocPrint(allocator, "{s}/{s}.zon", .{ binary_dir, bin_name });
    defer allocator.free(zon_file);

    const zon_content = std.fs.cwd().readFileAlloc(allocator, zon_file, 1024) catch {
        std.debug.print("Error: No .zon file for {s}\n", .{bin_name});
        return error.MissingZon;
    };
    defer allocator.free(zon_content);

    // Collect all libraries and their dependencies
    var all_libs = std.StringHashMap([]const u8).init(allocator);
    defer {
        var it = all_libs.iterator();
        while (it.next()) |entry| {
            allocator.free(entry.value_ptr.*);
        }
        all_libs.deinit();
    }

    // First pass: find direct dependencies from binary's zon
    var lib_dir = try std.fs.cwd().openDir(libraries_dir, .{ .iterate = true });
    defer lib_dir.close();

    var lib_iter = lib_dir.iterate();
    while (try lib_iter.next()) |entry| {
        if (entry.kind != .directory) continue;
        if (std.mem.indexOf(u8, zon_content, entry.name) != null) {
            try collectLibraryDeps(allocator, libraries_dir, entry.name, &all_libs);
        }
    }

    // Generate build.zig content
    var parts = std.ArrayList([]const u8).init(allocator);
    defer {
        for (parts.items) |part| {
            allocator.free(part);
        }
        parts.deinit();
    }

    // Header
    try parts.append(try allocator.dupe(u8,
        \\const std = @import("std");
        \\pub fn build(b: *std.Build) void {
        \\    const target = b.resolveTargetQuery(.{
        \\        .cpu_arch = .x86_64,
        \\        .os_tag = .freestanding,
        \\        .abi = .none,
        \\    });
        \\
    ));

    // Create modules for all libraries
    var lib_it = all_libs.iterator();
    while (lib_it.next()) |entry| {
        const lib_name = entry.key_ptr.*;
        try parts.append(try std.fmt.allocPrint(allocator,
            \\    const {s}_module = b.addModule("{s}", .{{
            \\        .root_source_file = b.path("../{s}/{s}/{s}.zig"),
            \\        .target = target,
            \\        .optimize = .ReleaseSmall,
            \\    }});
            \\
        , .{ lib_name, lib_name, libraries_dir, lib_name, lib_name }));
        std.debug.print("  + Library: {s}\n", .{lib_name});
    }

    // Add library-to-library dependencies
    lib_it = all_libs.iterator();
    while (lib_it.next()) |entry| {
        const lib_name = entry.key_ptr.*;
        const lib_deps = entry.value_ptr.*;

        // Parse deps string and add imports
        var dep_iter = std.mem.splitScalar(u8, lib_deps, ',');
        while (dep_iter.next()) |dep| {
            const trimmed = std.mem.trim(u8, dep, " ");
            if (trimmed.len > 0) {
                try parts.append(try std.fmt.allocPrint(allocator,
                    \\    {s}_module.addImport("{s}", {s}_module);
                    \\
                , .{ lib_name, trimmed, trimmed }));
            }
        }
    }

    // Create executable
    try parts.append(try std.fmt.allocPrint(allocator,
        \\    const exe = b.addExecutable(.{{
        \\        .name = "{s}",
        \\        .root_module = b.createModule(.{{
        \\            .root_source_file = b.path("../{s}"),
        \\            .target = target,
        \\            .optimize = .ReleaseSmall,
        \\        }}),
        \\    }});
        \\    exe.setLinkerScript(b.path("../toolchain/linker/akiba.binary.linker"));
        \\
    , .{ bin_name, zig_file }));

    // Add library imports to executable
    lib_it = all_libs.iterator();
    while (lib_it.next()) |entry| {
        const lib_name = entry.key_ptr.*;
        try parts.append(try std.fmt.allocPrint(allocator,
            \\    exe.root_module.addImport("{s}", {s}_module);
            \\
        , .{ lib_name, lib_name }));
    }

    // Footer
    try parts.append(try allocator.dupe(u8,
        \\    b.installArtifact(exe);
        \\}
        \\
    ));

    // Concatenate all parts
    const build_content = try std.mem.concat(allocator, u8, parts.items);
    defer allocator.free(build_content);

    // Create temp directory and build
    const temp_dir = try std.fmt.allocPrint(allocator, ".akiba-build-{s}", .{bin_name});
    defer allocator.free(temp_dir);

    std.fs.cwd().deleteTree(temp_dir) catch {};
    try std.fs.cwd().makeDir(temp_dir);
    defer std.fs.cwd().deleteTree(temp_dir) catch {};

    const build_path = try std.fmt.allocPrint(allocator, "{s}/build.zig", .{temp_dir});
    defer allocator.free(build_path);
    try std.fs.cwd().writeFile(.{ .sub_path = build_path, .data = build_content });

    const result = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "zig", "build" },
        .cwd = temp_dir,
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    if (result.term.Exited != 0) {
        std.debug.print("{s}\n", .{result.stderr});
        return error.CompileFailed;
    }

    const built_exe = try std.fmt.allocPrint(allocator, "{s}/zig-out/bin/{s}", .{ temp_dir, bin_name });
    defer allocator.free(built_exe);

    try std.fs.cwd().rename(built_exe, output_path);
    std.debug.print("✓ Compiled {s}\n", .{bin_name});
}

fn collectLibraryDeps(
    allocator: std.mem.Allocator,
    libraries_dir: []const u8,
    lib_name: []const u8,
    all_libs: *std.StringHashMap([]const u8),
) !void {
    // Skip if already processed
    if (all_libs.contains(lib_name)) return;

    const lib_zon_path = try std.fmt.allocPrint(allocator, "{s}/{s}/{s}.zon", .{ libraries_dir, lib_name, lib_name });
    defer allocator.free(lib_zon_path);

    const lib_zon = std.fs.cwd().readFileAlloc(allocator, lib_zon_path, 4096) catch {
        // No zon file, add with empty deps
        const key = try allocator.dupe(u8, lib_name);
        const val = try allocator.dupe(u8, "");
        try all_libs.put(key, val);
        return;
    };
    defer allocator.free(lib_zon);

    // Extract dependencies from zon
    var deps_list = std.ArrayList(u8).init(allocator);
    defer deps_list.deinit();

    // Scan for other library names in the zon file
    var lib_dir = try std.fs.cwd().openDir(libraries_dir, .{ .iterate = true });
    defer lib_dir.close();

    var lib_iter = lib_dir.iterate();
    while (try lib_iter.next()) |entry| {
        if (entry.kind != .directory) continue;
        if (std.mem.eql(u8, entry.name, lib_name)) continue; // Skip self

        if (std.mem.indexOf(u8, lib_zon, entry.name) != null) {
            if (deps_list.items.len > 0) {
                try deps_list.append(',');
            }
            try deps_list.appendSlice(entry.name);

            // Recursively collect this dependency's deps
            try collectLibraryDeps(allocator, libraries_dir, entry.name, all_libs);
        }
    }

    const key = try allocator.dupe(u8, lib_name);
    const val = try allocator.toOwnedSlice(deps_list);
    try all_libs.put(key, val);
}
