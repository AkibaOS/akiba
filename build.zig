//! Build Entry

const std = @import("std");

const orchestrator = @import("toolchain/orchestrator/orchestrator.zig");

pub fn build(builder: *std.Build) void {
    orchestrator.build(builder);
}
