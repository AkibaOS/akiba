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

    var parts: [100][]const u8 = undefined;
    var parts_count: usize = 0;

    parts[parts_count] =
        \\const std = @import("std");
        \\pub fn build(b: *std.Build) void {
        \\    const target = b.resolveTargetQuery(.{
        \\        .cpu_arch = .x86_64,
        \\        .os_tag = .freestanding,
        \\        .abi = .none,
        \\    });
        \\
    ;
    parts_count += 1;

    var lib_iter_dir = try std.fs.cwd().openDir(libraries_dir, .{ .iterate = true });
    defer lib_iter_dir.close();

    var lib_iter = lib_iter_dir.iterate();
    while (try lib_iter.next()) |entry| {
        if (entry.kind != .directory) continue;
        if (std.mem.indexOf(u8, zon_content, entry.name) != null) {
            parts[parts_count] = try std.fmt.allocPrint(allocator,
                \\    const {s}_module = b.addModule("{s}", .{{
                \\        .root_source_file = b.path("../{s}/{s}/{s}.zig"),
                \\        .target = target,
                \\        .optimize = .ReleaseSmall,
                \\    }});
                \\
            , .{ entry.name, entry.name, libraries_dir, entry.name, entry.name });
            parts_count += 1;
            std.debug.print("  + Library: {s}\n", .{entry.name});
        }
    }

    parts[parts_count] = try std.fmt.allocPrint(allocator,
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
    , .{ bin_name, zig_file });
    parts_count += 1;

    lib_iter_dir = try std.fs.cwd().openDir(libraries_dir, .{ .iterate = true });
    lib_iter = lib_iter_dir.iterate();
    while (try lib_iter.next()) |entry| {
        if (entry.kind != .directory) continue;
        if (std.mem.indexOf(u8, zon_content, entry.name) != null) {
            parts[parts_count] = try std.fmt.allocPrint(allocator,
                \\    exe.root_module.addImport("{s}", {s}_module);
                \\
            , .{ entry.name, entry.name });
            parts_count += 1;
        }
    }

    parts[parts_count] =
        \\    b.installArtifact(exe);
        \\}
        \\
    ;
    parts_count += 1;

    const build_content = try std.mem.concat(allocator, u8, parts[0..parts_count]);
    defer allocator.free(build_content);

    // Free allocated strings
    for (parts[1 .. parts_count - 1]) |part| {
        allocator.free(part);
    }

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
