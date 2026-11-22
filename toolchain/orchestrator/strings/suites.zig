//! Explicit Native Suite Roots

const paths = @import("paths.zig");

const Suite = @import("../types/suite.zig").Suite;

pub const FAST = [_]Suite{
    .{ .Name = "common", .Root = "tests/fast/common/run.zig" },
    .{ .Name = "foundation", .Root = "tests/fast/foundation/run.zig" },
    .{ .Name = "storage", .Root = "tests/fast/run/storage.zig" },
    .{ .Name = "render", .Root = "tests/fast/run/render.zig" },
    .{ .Name = "runner", .Root = "tests/fast/runner/run.zig" },
    .{ .Name = "image", .Root = "tests/fast/image/run.zig" },
    .{ .Name = "elf", .Root = "tests/fast/elf/run.zig" },
    .{ .Name = "weaver", .Root = paths.WEAVER_TEST_ROOT },
    .{ .Name = "pulse", .Root = "tests/fast/pulse/run.zig" },
    .{ .Name = "keyboard", .Root = "tests/fast/keyboard/run.zig" },
    .{ .Name = "display", .Root = "tests/fast/display/run.zig" },
};
pub const EXECUTABLE = "tests-{s}";
