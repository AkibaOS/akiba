//! Isolated Guest Runner Path Discovery

const builtin = @import("builtin");
const std = @import("std");

const host = @import("tests").types.host;
const limits = @import("tests").constants.runner;
const options = @import("runneroptions");
const strings = @import("tests").strings.paths;

pub fn prepare(allocator: std.mem.Allocator) !host.Paths {
    const repo = try std.fs.cwd().realpathAlloc(allocator, strings.CURRENT_DIRECTORY);
    defer allocator.free(repo);
    try safePath(repo);
    const qemu = try findQemu(allocator);
    errdefer allocator.free(qemu);
    const qemu_image = try findQemuImage(allocator, qemu);
    errdefer allocator.free(qemu_image);
    const image = try checkImage(allocator, options.GUEST_IMAGE);
    errdefer allocator.free(image);
    const firmware_image = try checkImage(allocator, options.FIRMWARE_IMAGE);
    errdefer allocator.free(firmware_image);
    const firmware = try findFirmware(allocator, qemu);
    errdefer for (firmware) |path| allocator.free(path);
    const run = try createRun(allocator, repo);
    errdefer {
        std.fs.deleteDirAbsolute(run) catch |failure| std.log.err(strings.RUN_CLEANUP, .{@errorName(failure)});
        allocator.free(run);
    }
    const serial = try std.fs.path.join(allocator, &.{ run, strings.SERIAL_FILE });
    errdefer allocator.free(serial);
    const variables = try std.fs.path.join(allocator, &.{ run, strings.VARIABLES_FILE });
    errdefer allocator.free(variables);
    return .{
        .Run = run,
        .Image = image,
        .FirmwareImage = firmware_image,
        .Serial = serial,
        .Variables = variables,
        .State = try std.fs.path.join(allocator, &.{ run, strings.STATE_FILE }),
        .FirmwareCode = firmware[0],
        .FirmwareTemplate = firmware[1],
        .Qemu = qemu,
        .QemuImage = qemu_image,
    };
}

fn checkImage(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    return (try canonicalFile(allocator, path)) orelse {
        std.log.err(strings.MISSING_IMAGE, .{});
        return error.MissingCheckImage;
    };
}

pub fn same(allocator: std.mem.Allocator, left: []const u8, right: []const u8) !bool {
    const left_real = try std.fs.cwd().realpathAlloc(allocator, left);
    defer allocator.free(left_real);
    const right_real = try std.fs.cwd().realpathAlloc(allocator, right);
    defer allocator.free(right_real);
    return if (builtin.os.tag == .windows)
        std.os.windows.eqlIgnoreCaseWtf8(left_real, right_real)
    else
        std.mem.eql(u8, left_real, right_real);
}

fn environment(allocator: std.mem.Allocator, name: []const u8) !?[]const u8 {
    return std.process.getEnvVarOwned(allocator, name) catch |err| switch (err) {
        error.EnvironmentVariableNotFound => null,
        else => return err,
    };
}

fn safePath(path: []const u8) !void {
    if (std.mem.indexOfAny(u8, path, strings.UNSAFE_PATH_CHARACTERS) != null) {
        std.log.err(strings.UNSAFE_PATH, .{});
        return error.UnsafeQemuPath;
    }
}

fn canonicalFile(allocator: std.mem.Allocator, path: []const u8) !?[]const u8 {
    if (std.mem.indexOfScalar(u8, path, 0) != null) try safePath(path);
    const canonical = std.fs.cwd().realpathAlloc(allocator, path) catch |err| switch (err) {
        error.FileNotFound, error.NotDir => return null,
        else => return err,
    };
    errdefer allocator.free(canonical);
    const stat = try std.fs.cwd().statFile(canonical);
    if (stat.kind != .file) {
        allocator.free(canonical);
        return null;
    }
    try safePath(canonical);
    return canonical;
}

fn projectFile(allocator: std.mem.Allocator, repo: []const u8, relative: []const u8) !?[]const u8 {
    const path = try std.fs.path.join(allocator, &.{ repo, relative });
    defer allocator.free(path);
    return canonicalFile(allocator, path);
}

fn createRun(allocator: std.mem.Allocator, repo: []const u8) ![]const u8 {
    const location = try std.fs.path.join(allocator, &.{ repo, strings.RUNS_DIRECTORY });
    defer allocator.free(location);
    try std.fs.cwd().makePath(location);
    const runs = try std.fs.cwd().realpathAlloc(allocator, location);
    defer allocator.free(runs);
    try safePath(runs);
    while (true) {
        const name = try std.fmt.allocPrint(allocator, strings.RUN_NAME, .{std.crypto.random.int(u128)});
        defer allocator.free(name);
        const path = try std.fs.path.join(allocator, &.{ runs, name });
        defer allocator.free(path);
        std.fs.makeDirAbsolute(path) catch |err| switch (err) {
            error.PathAlreadyExists => continue,
            else => return err,
        };
        errdefer std.fs.deleteDirAbsolute(path) catch |failure| std.log.err(strings.RUN_CLEANUP, .{@errorName(failure)});
        const canonical = try std.fs.cwd().realpathAlloc(allocator, path);
        errdefer allocator.free(canonical);
        try safePath(canonical);
        return canonical;
    }
}

fn findQemu(allocator: std.mem.Allocator) ![]const u8 {
    const override = try environment(allocator, strings.QEMU_ENV);
    defer if (override) |value| allocator.free(value);
    const name = override orelse strings.QEMU_NAME;
    if (name.len != 0) {
        const markers = if (builtin.os.tag == .windows) strings.PATH_MARKERS_WINDOWS else strings.PATH_MARKERS;
        if (std.mem.indexOfAny(u8, name, markers) != null) {
            if (try executableCandidate(allocator, name)) |path| return path;
        } else if (try findOnPath(allocator, name)) |path| return path;
    }
    std.log.err(strings.MISSING_QEMU, .{});
    return error.MissingQemuExecutable;
}

fn findQemuImage(allocator: std.mem.Allocator, qemu: []const u8) ![]const u8 {
    const directory = std.fs.path.dirname(qemu) orelse return error.MissingQemuDirectory;
    const sibling = try std.fs.path.join(allocator, &.{ directory, strings.QEMU_IMAGE_NAME });
    defer allocator.free(sibling);
    if (try executableCandidate(allocator, sibling)) |path| return path;
    if (try findOnPath(allocator, strings.QEMU_IMAGE_NAME)) |path| return path;
    std.log.err(strings.MISSING_QEMU_IMAGE, .{});
    return error.MissingQemuImageTool;
}

fn findOnPath(allocator: std.mem.Allocator, name: []const u8) !?[]const u8 {
    const search = (try environment(allocator, strings.PATH_ENV)) orelse return null;
    defer allocator.free(search);
    var directories = std.mem.splitScalar(u8, search, if (builtin.os.tag == .windows) ';' else ':');
    while (directories.next()) |entry| {
        const directory = if (builtin.os.tag == .windows) unquote(entry) else entry;
        const candidate = try std.fs.path.join(allocator, &.{ directory, name });
        defer allocator.free(candidate);
        if (try executableCandidate(allocator, candidate)) |path| return path;
    }
    return null;
}

fn executableCandidate(allocator: std.mem.Allocator, candidate: []const u8) !?[]const u8 {
    if (builtin.os.tag == .windows and !std.ascii.endsWithIgnoreCase(candidate, strings.EXECUTABLE_SUFFIX)) {
        const suffixed = try std.fmt.allocPrint(allocator, strings.SUFFIX_FORMAT, .{ candidate, strings.EXECUTABLE_SUFFIX });
        defer allocator.free(suffixed);
        return resolveExecutable(allocator, suffixed);
    }
    return resolveExecutable(allocator, candidate);
}

fn resolveExecutable(allocator: std.mem.Allocator, candidate: []const u8) !?[]const u8 {
    const canonical = (try canonicalFile(allocator, candidate)) orelse return null;
    errdefer allocator.free(canonical);
    if (builtin.os.tag == .windows) {
        if (try shimTarget(allocator, candidate)) |target| {
            allocator.free(canonical);
            return target;
        }
    } else {
        std.posix.access(canonical, std.posix.X_OK) catch |err| switch (err) {
            error.AccessDenied, error.PermissionDenied => {
                allocator.free(canonical);
                return null;
            },
            else => return err,
        };
    }
    return canonical;
}

fn unquote(value: []const u8) []const u8 {
    if (value.len >= strings.EMPTY_QUOTED.len and value[0] == '"' and value[value.len - 1] == '"')
        return value[1 .. value.len - 1];
    return value;
}

fn shimTarget(allocator: std.mem.Allocator, executable: []const u8) !?[]const u8 {
    const sidecar = try std.fmt.allocPrint(allocator, strings.SUFFIX_FORMAT, .{
        executable[0 .. executable.len - strings.EXECUTABLE_SUFFIX.len],
        strings.SHIM_SUFFIX,
    });
    defer allocator.free(sidecar);
    const contents = std.fs.cwd().readFileAlloc(allocator, sidecar, limits.MAX_TOOL_BYTES) catch |err| switch (err) {
        error.FileNotFound, error.NotDir => return null,
        else => return err,
    };
    defer allocator.free(contents);
    var target: ?[]const u8 = null;
    var lines = std.mem.tokenizeAny(u8, contents, strings.LINE_SEPARATORS);
    while (lines.next()) |line| {
        const separator = std.mem.indexOfScalar(u8, line, '=') orelse continue;
        const key = std.mem.trim(u8, line[0..separator], strings.WHITESPACE);
        const value = unquote(std.mem.trim(u8, line[separator + 1 ..], strings.WHITESPACE));
        if (std.mem.eql(u8, key, strings.SHIM_PATH_KEY)) {
            if (target != null or value.len == 0) return error.InvalidQemuShim;
            target = value;
        } else if (std.mem.eql(u8, key, strings.SHIM_ARGUMENTS_KEY) and value.len != 0) {
            return error.UnsupportedQemuShimArguments;
        }
    }
    const selected = target orelse return error.InvalidQemuShim;
    try safePath(selected);
    if (!std.ascii.endsWithIgnoreCase(selected, strings.EXECUTABLE_SUFFIX)) return error.InvalidQemuShim;
    const path = try std.fs.path.resolve(allocator, &.{ std.fs.path.dirname(sidecar) orelse strings.CURRENT_DIRECTORY, selected });
    defer allocator.free(path);
    return (try canonicalFile(allocator, path)) orelse return error.MissingQemuShimTarget;
}

fn findFirmware(allocator: std.mem.Allocator, qemu: []const u8) ![2][]const u8 {
    const code = try environment(allocator, strings.UEFI_CODE_ENV);
    defer if (code) |value| allocator.free(value);
    const variables = try environment(allocator, strings.UEFI_VARS_ENV);
    defer if (variables) |value| allocator.free(value);
    if (code != null or variables != null) {
        if (code == null or variables == null) {
            std.log.err(strings.UNPAIRED_FIRMWARE, .{});
            return error.UEFIOverridesMustBePaired;
        }
        const selected_code = (try canonicalFile(allocator, code.?)) orelse {
            std.log.err(strings.INVALID_FIRMWARE, .{strings.UEFI_CODE_ENV});
            return error.InvalidUEFICode;
        };
        errdefer allocator.free(selected_code);
        const selected_variables = (try canonicalFile(allocator, variables.?)) orelse {
            std.log.err(strings.INVALID_FIRMWARE, .{strings.UEFI_VARS_ENV});
            return error.InvalidUEFIVariables;
        };
        return .{ selected_code, selected_variables };
    }
    const directory = std.fs.path.dirname(qemu) orelse return error.MissingQemuDirectory;
    for (strings.FIRMWARE_RELATIVE_DIRECTORIES) |relative| {
        const candidate = try std.fs.path.resolve(allocator, &.{ directory, relative });
        defer allocator.free(candidate);
        if (try firmwarePair(allocator, candidate)) |pair| return pair;
    }
    std.log.err(strings.MISSING_FIRMWARE, .{});
    return error.MissingUEFIFirmware;
}

fn firmwarePair(allocator: std.mem.Allocator, directory: []const u8) !?[2][]const u8 {
    for (strings.FIRMWARE_PAIRS) |names| {
        const code = (try projectFile(allocator, directory, names[0])) orelse continue;
        errdefer allocator.free(code);
        const variables = (try projectFile(allocator, directory, names[1])) orelse {
            allocator.free(code);
            continue;
        };
        return .{ code, variables };
    }
    return null;
}
