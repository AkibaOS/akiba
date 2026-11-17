//! Allocator Owned ELF Image Plans

const std = @import("std");

const Program = @import("shared").elf.types.format.Elf64ProgramHeader;
const Range = @import("shared").elf.types.range.Range;

pub const Policy = struct {
    MinimumAddress: u64,
    MaximumAddress: u64,
    MaximumPages: u64,
};

pub const Plan = struct {
    Allocator: std.mem.Allocator,
    Entry: u64,
    Segments: []Program,
    Ranges: []Range,
    Pages: u64,

    pub fn deinit(self: *Plan) void {
        self.Allocator.free(self.Segments);
        self.Allocator.free(self.Ranges);
        self.Segments = &.{};
        self.Ranges = &.{};
        self.Pages = 0;
    }
};
