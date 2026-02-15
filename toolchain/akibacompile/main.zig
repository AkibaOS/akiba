const std = @import("std");

const MAX_LIBS = 32;
const MAX_NAME = 64;

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

    // Get all available library names
    var available: [MAX_LIBS][MAX_NAME]u8 = undefined;
    var available_len: [MAX_LIBS]usize = undefined;
    var available_count: usize = 0;

    var lib_dir = try std.fs.cwd().openDir(libraries_dir, .{ .iterate = true });
    var lib_iter = lib_dir.iterate();
    while (try lib_iter.next()) |entry| {
        if (entry.kind != .directory) continue;
        if (entry.name.len < MAX_NAME and available_count < MAX_LIBS) {
            @memcpy(available[available_count][0..entry.name.len], entry.name);
            available_len[available_count] = entry.name.len;
            available_count += 1;
        }
    }
    lib_dir.close();

    // Track which libs are needed
    var needed: [MAX_LIBS]bool = [_]bool{false} ** MAX_LIBS;
    var deps: [MAX_LIBS][256]u8 = undefined;
    var deps_len: [MAX_LIBS]usize = [_]usize{0} ** MAX_LIBS;

    // Mark direct dependencies from binary's zon
    for (0..available_count) |i| {
        const name = available[i][0..available_len[i]];
        if (std.mem.indexOf(u8, zon_content, name) != null) {
            needed[i] = true;
        }
    }

    // Iteratively find transitive dependencies (max 10 passes)
    for (0..10) |_| {
        var changed = false;
        for (0..available_count) |i| {
            if (!needed[i]) continue;

            // Read this lib's zon
            const lib_zon_path = try std.fmt.allocPrint(allocator, "{s}/{s}/{s}.zon", .{
                libraries_dir,
                available[i][0..available_len[i]],
                available[i][0..available_len[i]],
            });
            defer allocator.free(lib_zon_path);

            const lib_zon = std.fs.cwd().readFileAlloc(allocator, lib_zon_path, 4096) catch continue;
            defer allocator.free(lib_zon);

            // Check for dependencies on other libs
            for (0..available_count) |j| {
                if (i == j) continue;
                const dep_name = available[j][0..available_len[j]];
                if (std.mem.indexOf(u8, lib_zon, dep_name) != null) {
                    if (!needed[j]) {
                        needed[j] = true;
                        changed = true;
                    }
                    // Record dependency
                    if (deps_len[i] > 0) {
                        deps[i][deps_len[i]] = ',';
                        deps_len[i] += 1;
                    }
                    // Check if already in deps
                    var already = false;
                    var check_iter = std.mem.splitScalar(u8, deps[i][0..deps_len[i]], ',');
                    while (check_iter.next()) |existing| {
                        if (std.mem.eql(u8, existing, dep_name)) {
                            already = true;
                            break;
                        }
                    }
                    if (!already) {
                        @memcpy(deps[i][deps_len[i]..][0..dep_name.len], dep_name);
                        deps_len[i] += dep_name.len;
                    } else if (deps_len[i] > 0) {
                        deps_len[i] -= 1; // Remove the comma we added
                    }
                }
            }
        }
        if (!changed) break;
    }

    // Build the build.zig content
    var content = std.ArrayListUnmanaged(u8){};
    defer content.deinit(allocator);

    try content.appendSlice(allocator,
        \\const std = @import("std");
        \\pub fn build(b: *std.Build) void {
        \\    const target = b.resolveTargetQuery(.{
        \\        .cpu_arch = .x86_64,
        \\        .os_tag = .freestanding,
        \\        .abi = .none,
        \\    });
        \\
    );

    // Create modules for needed libs
    for (0..available_count) |i| {
        if (!needed[i]) continue;
        const name = available[i][0..available_len[i]];
        const module_decl = try std.fmt.allocPrint(allocator,
            \\    const {s}_module = b.addModule("{s}", .{{
            \\        .root_source_file = b.path("../{s}/{s}/{s}.zig"),
            \\        .target = target,
            \\        .optimize = .ReleaseSmall,
            \\    }});
            \\
        , .{ name, name, libraries_dir, name, name });
        defer allocator.free(module_decl);
        try content.appendSlice(allocator, module_decl);
        std.debug.print("  + Library: {s}\n", .{name});
    }

    // Add inter-library dependencies
    for (0..available_count) |i| {
        if (!needed[i]) continue;
        const name = available[i][0..available_len[i]];
        var dep_iter = std.mem.splitScalar(u8, deps[i][0..deps_len[i]], ',');
        while (dep_iter.next()) |dep| {
            if (dep.len > 0) {
                const import_stmt = try std.fmt.allocPrint(allocator,
                    \\    {s}_module.addImport("{s}", {s}_module);
                    \\
                , .{ name, dep, dep });
                defer allocator.free(import_stmt);
                try content.appendSlice(allocator, import_stmt);
            }
        }
    }

    // Create executable
    const exe_decl = try std.fmt.allocPrint(allocator,
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
    defer allocator.free(exe_decl);
    try content.appendSlice(allocator, exe_decl);

    // Add library imports to exe
    for (0..available_count) |i| {
        if (!needed[i]) continue;
        const name = available[i][0..available_len[i]];
        const import_stmt = try std.fmt.allocPrint(allocator,
            \\    exe.root_module.addImport("{s}", {s}_module);
            \\
        , .{ name, name });
        defer allocator.free(import_stmt);
        try content.appendSlice(allocator, import_stmt);
    }

    try content.appendSlice(allocator,
        \\    b.installArtifact(exe);
        \\}
        \\
    );

    // Create temp directory and build
    const temp_dir = try std.fmt.allocPrint(allocator, ".akiba-build-{s}", .{bin_name});
    defer allocator.free(temp_dir);

    std.fs.cwd().deleteTree(temp_dir) catch {};
    try std.fs.cwd().makeDir(temp_dir);
    defer std.fs.cwd().deleteTree(temp_dir) catch {};

    const build_path = try std.fmt.allocPrint(allocator, "{s}/build.zig", .{temp_dir});
    defer allocator.free(build_path);
    try std.fs.cwd().writeFile(.{ .sub_path = build_path, .data = content.items });

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
