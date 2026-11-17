//! Allocator Owned Executable Image Planning

const std = @import("std");

const format = @import("shared").elf.constants.format;
const pages = @import("shared").elf.validate.pages;
const ranges = @import("shared").elf.validate.ranges;
const read = @import("shared").elf.read;
const sizes = @import("common").constants.memory.sizes;
const types = @import("shared").elf.types;

const ImageError = @import("shared").elf.errors.image.ImageError;
const Plan = types.image.Plan;
const Policy = types.image.Policy;
const Program = types.format.Elf64ProgramHeader;

pub fn parse(allocator: std.mem.Allocator, data: []const u8, policy: Policy) ImageError!Plan {
    if (policy.MinimumAddress < sizes.PAGE_SIZE or (policy.MinimumAddress & sizes.PAGE_MASK) != 0 or
        policy.MaximumAddress < policy.MinimumAddress or policy.MaximumAddress > std.math.maxInt(u64) - sizes.PAGE_MASK or
        (policy.MaximumAddress & sizes.PAGE_MASK) != sizes.PAGE_MASK or policy.MaximumPages == 0) return ImageError.InvalidPolicy;
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
        try validateSegment(data.len, segment, policy);
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
    std.mem.sort(Program, segments, {}, earlier);
    for (segments[1..], segments[0 .. segments.len - 1]) |segment, previous| {
        if (segment.VirtualAddress < previous.VirtualAddress + previous.MemorySize) return ImageError.SegmentOverlap;
    }
    const planned = try ranges.prepare(allocator, segments, policy.MaximumPages);
    var count_pages: u64 = 0;
    for (planned) |range| count_pages += (range.End - range.Start) / sizes.PAGE_SIZE;
    return .{ .Allocator = allocator, .Entry = header.Entry, .Segments = segments, .Ranges = planned, .Pages = count_pages };
}

fn earlier(_: void, left: Program, right: Program) bool {
    return left.VirtualAddress < right.VirtualAddress;
}

fn validateSegment(data_size: usize, segment: Program, policy: Policy) ImageError!void {
    const permitted = format.SEGMENT_FLAG_READ | format.SEGMENT_FLAG_WRITE | format.SEGMENT_FLAG_EXECUTE;
    if (segment.MemorySize == 0 or segment.UnitSize > segment.MemorySize or !segment.isReadable() or
        (segment.Flags & ~permitted) != 0 or (segment.isWritable() and segment.isExecutable())) return ImageError.InvalidSegment;
    if (segment.UnitSize != 0 and (segment.Offset > data_size or segment.UnitSize > data_size - segment.Offset))
        return ImageError.InvalidSegment;
    if (segment.VirtualAddress < policy.MinimumAddress or segment.VirtualAddress > policy.MaximumAddress or
        segment.MemorySize > policy.MaximumAddress - segment.VirtualAddress + 1) return ImageError.InvalidSegment;
    if ((segment.VirtualAddress & sizes.PAGE_MASK) != (segment.Offset & sizes.PAGE_MASK)) return ImageError.InvalidSegment;
    if (segment.Alignment > 1) {
        const mask = segment.Alignment - 1;
        if ((segment.Alignment & mask) != 0 or (segment.VirtualAddress & mask) != (segment.Offset & mask))
            return ImageError.InvalidSegment;
    }
    if ((pages.end(segment) - pages.start(segment)) / sizes.PAGE_SIZE > policy.MaximumPages) return ImageError.ImageTooLarge;
}
