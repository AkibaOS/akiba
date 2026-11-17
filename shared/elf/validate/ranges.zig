//! Executable Page Permission Interval Planning

const std = @import("std");

const format = @import("shared").elf.constants.format;
const pages = @import("shared").elf.validate.pages;
const sizes = @import("common").constants.memory.sizes;
const types = @import("shared").elf.types;

const ImageError = @import("shared").elf.errors.image.ImageError;
const Program = types.format.Elf64ProgramHeader;
const Range = types.range.Range;

pub fn prepare(allocator: std.mem.Allocator, segments: []const Program, maximum: u64) ImageError![]Range {
    var ranges: std.ArrayList(Range) = .empty;
    errdefer ranges.deinit(allocator);
    for (segments) |segment| {
        const start = pages.start(segment);
        const end = pages.end(segment);
        if (ranges.items.len == 0 or start >= ranges.items[ranges.items.len - 1].End) {
            try append(allocator, &ranges, .{ .Start = start, .End = end, .Flags = segment.Flags });
            continue;
        }
        const index = ranges.items.len - 1;
        const previous = ranges.items[index];
        if (start < previous.Start or previous.End - start != sizes.PAGE_SIZE or end < previous.End)
            return ImageError.InvalidSegment;
        const flags = previous.Flags | segment.Flags;
        if ((flags & format.SEGMENT_FLAG_WRITE) != 0 and (flags & format.SEGMENT_FLAG_EXECUTE) != 0)
            return ImageError.PermissionConflict;
        if (start > previous.Start) {
            ranges.items[index].End = start;
            try append(allocator, &ranges, .{ .Start = start, .End = previous.End, .Flags = flags });
        } else {
            ranges.items[index].Flags = flags;
        }
        if (end > previous.End)
            try append(allocator, &ranges, .{ .Start = previous.End, .End = end, .Flags = segment.Flags });
    }
    var count: u64 = 0;
    for (ranges.items) |range| {
        const pages_count = (range.End - range.Start) / sizes.PAGE_SIZE;
        if (pages_count > maximum - count) return ImageError.ImageTooLarge;
        count += pages_count;
    }
    return ranges.toOwnedSlice(allocator);
}

fn append(allocator: std.mem.Allocator, ranges: *std.ArrayList(Range), range: Range) ImageError!void {
    if (ranges.items.len != 0) {
        const previous = &ranges.items[ranges.items.len - 1];
        if (previous.End == range.Start and previous.Flags == range.Flags) {
            previous.End = range.End;
            return;
        }
    }
    try ranges.append(allocator, range);
}
