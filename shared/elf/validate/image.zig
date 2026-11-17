//! Bounded Executable Image Planning

const std = @import("std");

const format = @import("shared").elf.constants.format;
const limits = @import("shared").elf.constants.limits;
const pages = @import("shared").elf.validate.pages;
const read = @import("shared").elf.read;
const sizes = @import("common").constants.memory.sizes;
const types = @import("shared").elf.types;

const ImageError = @import("shared").elf.errors.image.ImageError;
const Plan = types.image.Plan;
const Policy = types.image.Policy;
const Program = types.format.Elf64ProgramHeader;

pub fn parse(data: []const u8, policy: Policy) ImageError!Plan {
    if (policy.MinimumAddress < sizes.PAGE_SIZE or (policy.MinimumAddress & sizes.PAGE_MASK) != 0 or
        policy.MaximumAddress < policy.MinimumAddress or policy.MaximumAddress > std.math.maxInt(u64) - sizes.PAGE_MASK or
        (policy.MaximumAddress & sizes.PAGE_MASK) != sizes.PAGE_MASK or policy.MaximumPages == 0) return ImageError.InvalidPolicy;
    const header = try read.header.read(data);
    if (!header.isX8664()) return ImageError.UnsupportedArchitecture;
    if (!header.isExecutable()) return ImageError.UnsupportedImage;
    if (header.ProgramHeaderCount > limits.MAX_PROGRAMS) return ImageError.InvalidProgramHeaders;
    const programs = try read.programs.read(data, header);
    var plan: Plan = .{ .Entry = header.Entry, .Segments = undefined, .Count = 0, .Pages = 0 };
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
        if (plan.Count == limits.MAX_SEGMENTS) return ImageError.ImageTooLarge;
        for (plan.Segments[0..plan.Count]) |previous| {
            if (segment.VirtualAddress < previous.VirtualAddress + previous.MemorySize and
                previous.VirtualAddress < segment.VirtualAddress + segment.MemorySize) return ImageError.SegmentOverlap;
        }
        plan.Segments[plan.Count] = segment;
        plan.Count += 1;
        if (segment.isExecutable() and header.Entry >= segment.VirtualAddress and
            header.Entry - segment.VirtualAddress < segment.UnitSize) entry_found = true;
    }
    if (plan.Count == 0) return ImageError.NoLoadableSegments;
    if (!entry_found) return ImageError.InvalidEntryPoint;
    for (plan.Segments[0..plan.Count], 0..) |segment, index| {
        var address = pages.start(segment);
        while (address < pages.end(segment)) : (address += sizes.PAGE_SIZE) {
            if (!pages.isFirst(&plan, index, address)) continue;
            const permissions = pages.flags(&plan, address);
            if ((permissions & format.SEGMENT_FLAG_WRITE) != 0 and
                (permissions & format.SEGMENT_FLAG_EXECUTE) != 0) return ImageError.PermissionConflict;
            if (plan.Pages == policy.MaximumPages) return ImageError.ImageTooLarge;
            plan.Pages += 1;
        }
    }
    return plan;
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
