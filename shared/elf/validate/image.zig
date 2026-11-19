//! Allocator Owned Executable Image Planning

const std = @import("std");

const format = @import("shared").elf.constants.format;
const load = @import("shared").elf.validate.load;
const read = @import("shared").elf.read;
const types = @import("shared").elf.types;

const ImageError = @import("shared").elf.errors.image.ImageError;
const Plan = types.image.Plan;
const Policy = types.image.Policy;
const Program = types.format.Elf64ProgramHeader;

pub fn parse(allocator: std.mem.Allocator, data: []const u8, policy: Policy) ImageError!Plan {
    try load.validatePolicy(policy);
    const header = try read.header.read(data);
    if (!header.isX8664()) return ImageError.UnsupportedArchitecture;
    if (!header.isExecutable()) return ImageError.UnsupportedImage;
    const programs = try read.programs.read(data, header);
    var count: usize = 0;
    var entry_found = false;
    for (programs) |segment| {
        switch (segment.SegmentType) {
            format.SEGMENT_NULL, format.SEGMENT_NOTE, format.SEGMENT_PHDR => continue,
            format.SEGMENT_STACK => {
                if (segment.isExecutable()) return ImageError.UnsupportedSegment;
                continue;
            },
            format.SEGMENT_LOAD => {},
            else => return ImageError.UnsupportedSegment,
        }
        try load.validateSegment(data.len, segment, policy);
        count += 1;
        if (segment.isExecutable() and header.Entry >= segment.VirtualAddress and
            header.Entry - segment.VirtualAddress < segment.UnitSize) entry_found = true;
    }
    if (count == 0) return ImageError.NoLoadableSegments;
    if (!entry_found) return ImageError.InvalidEntryPoint;
    const segments = try allocator.alloc(Program, count);
    errdefer allocator.free(segments);
    var index: usize = 0;
    for (programs) |segment| {
        if (segment.SegmentType != format.SEGMENT_LOAD) continue;
        segments[index] = segment;
        index += 1;
    }
    return load.plan(allocator, segments, header.Entry, policy.MaximumPages);
}
