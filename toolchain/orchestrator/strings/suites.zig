//! Explicit Native Suite Roots

const Suite = @import("../types/suite.zig").Suite;

pub const FAST = [_]Suite{
    .{ .Name = "common", .Root = "tests/fast/common/run.zig" },
    .{ .Name = "utils", .Root = "tests/fast/utils/run.zig" },
    .{ .Name = "storage", .Root = "tests/fast/shared/storage.zig" },
    .{ .Name = "render", .Root = "tests/fast/shared/render.zig" },
    .{ .Name = "runner", .Root = "tests/fast/runner/run.zig" },
    .{ .Name = "image", .Root = "tests/fast/toolchain/run.zig" },
};
pub const EXECUTABLE = "tests-{s}";
