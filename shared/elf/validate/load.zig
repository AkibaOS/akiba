//! ELF Load Bounds And Page Planning

const std = @import("std");

const format = @import("shared").elf.constants.format;
const pages = @import("shared").elf.validate.pages;
const ranges = @import("shared").elf.validate.ranges;
const sizes = @import("common").constants.memory.sizes;
const types = @import("shared").elf.types;

const ImageError = @import("shared").elf.errors.image.ImageError;
const Plan = types.image.Plan;
const Policy = types.image.Policy;
const Program = types.format.Elf64ProgramHeader;

pub fn validatePolicy(policy: Policy) ImageError!void {
    if (policy.MinimumAddress < sizes.PAGE_SIZE or (policy.MinimumAddress & sizes.PAGE_MASK) != 0 or
        policy.MaximumAddress < policy.MinimumAddress or policy.MaximumAddress > std.math.maxInt(u64) - sizes.PAGE_MASK or
        (policy.MaximumAddress & sizes.PAGE_MASK) != sizes.PAGE_MASK or policy.MaximumPages == 0) return ImageError.InvalidPolicy;
}

pub fn validateSegment(data_size: usize, segment: Program, policy: Policy) ImageError!void {
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

pub fn plan(allocator: std.mem.Allocator, segments: []Program, entry: u64, maximum: u64) ImageError!Plan {
    if (segments.len == 0) return ImageError.NoLoadableSegments;
    std.mem.sort(Program, segments, {}, earlier);
    for (segments[1..], segments[0 .. segments.len - 1]) |segment, previous| {
        if (segment.VirtualAddress < previous.VirtualAddress + previous.MemorySize) return ImageError.SegmentOverlap;
    }
    const planned = try ranges.prepare(allocator, segments, maximum);
    var count: u64 = 0;
    for (planned) |range| count += (range.End - range.Start) / sizes.PAGE_SIZE;
    return .{ .Allocator = allocator, .Entry = entry, .Segments = segments, .Ranges = planned, .Pages = count };
}

fn earlier(_: void, left: Program, right: Program) bool {
    return left.VirtualAddress < right.VirtualAddress;
}
