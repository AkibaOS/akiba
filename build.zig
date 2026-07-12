const std = @import("std");
const builder = @import("toolchain/build/build.zig");

pub fn build(b: *std.Build) void {
    builder.build(b);
}
