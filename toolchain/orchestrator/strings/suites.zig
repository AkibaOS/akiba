//! Explicit Native Suite Roots

const Suite = @import("../types/suite.zig").Suite;

pub const FAST = [_]Suite{
    .{ .Name = "common", .Root = "tests/fast/common/run.zig" },
    .{ .Name = "utils", .Root = "tests/fast/utils/run.zig" },
    .{ .Name = "afs", .Root = "tests/fast/run.zig" },
};
pub const EXECUTABLE = "tests-{s}";
