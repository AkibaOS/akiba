//! Hikari ELF Validation

const std = @import("std");

const common = @import("common");
const constants = @import("hikari").loader.constants;
const errors = @import("hikari").loader.errors;
const math = @import("utils").math;
const types = @import("hikari").loader.types;

const elf = constants.elf;
const layout = common.constants.memory.layout;
const sizes = common.constants.memory.sizes;

const Elf64Header = types.elf.Elf64Header;
const Elf64ProgramHeader = types.elf.Elf64ProgramHeader;
const ImageLayout = types.elf.ImageLayout;
const LoadError = errors.elf.LoadError;

pub fn validateImage(data: []const u8) LoadError!ImageLayout {
    const header = try validateHeader(data);
    const program_headers = try readProgramHeaders(data, header);

    var image = ImageLayout{
        .EntryPoint = header.Entry,
        .VirtualBase = std.math.maxInt(u64),
        .PhysicalBase = std.math.maxInt(u64),
        .Size = 0,
        .Segments = undefined,
        .SegmentCount = 0,
    };
    var physical_end: u64 = 0;
    var entry_found = false;

    for (program_headers) |*program_header| {
        if (program_header.SegmentType == elf.SEGMENT_DYNAMIC or
            program_header.SegmentType == elf.SEGMENT_INTERP)
        {
            return LoadError.UnsupportedElfType;
        }
        if (!program_header.isLoadable()) continue;

        try validateSegment(data.len, program_header);
        if (program_header.MemorySize == 0) continue;
        if (image.SegmentCount == elf.MAX_SEGMENTS) {
            return LoadError.TooManySegments;
        }

        const segment_end = program_header.PhysicalAddress + program_header.MemorySize;
        for (image.Segments[0..image.SegmentCount]) |previous| {
            const previous_end = previous.PhysicalAddress + previous.MemorySize;
            if (program_header.PhysicalAddress < previous_end and
                previous.PhysicalAddress < segment_end)
            {
                return LoadError.SegmentOverlap;
            }
        }

        image.PhysicalBase = @min(image.PhysicalBase, program_header.PhysicalAddress);
        image.VirtualBase = @min(image.VirtualBase, program_header.VirtualAddress);
        physical_end = @max(physical_end, segment_end);
        image.Segments[image.SegmentCount] = program_header.*;
        image.SegmentCount += 1;

        if (program_header.isExecutable() and header.Entry >= program_header.VirtualAddress and
            header.Entry - program_header.VirtualAddress < program_header.UnitSize)
        {
            entry_found = true;
        }
    }

    if (image.SegmentCount == 0) return LoadError.NoLoadableSegments;
    if (!entry_found) return LoadError.InvalidEntryPoint;

    image.PhysicalBase = math.integer.alignDown(image.PhysicalBase, sizes.PAGE_SIZE);
    image.VirtualBase = math.integer.alignDown(image.VirtualBase, sizes.PAGE_SIZE);

    for (image.Segments[0..image.SegmentCount]) |segment| {
        if (segment.VirtualAddress - image.VirtualBase != segment.PhysicalAddress - image.PhysicalBase) {
            return LoadError.UnsupportedImageLayout;
        }
    }

    const memory_size = physical_end - image.PhysicalBase;
    if (memory_size > std.math.maxInt(u64) - sizes.PAGE_MASK) {
        return LoadError.UnsupportedImageLayout;
    }
    image.Size = math.integer.alignUp(memory_size, sizes.PAGE_SIZE);
    if (image.Size > std.math.maxInt(u64) - image.PhysicalBase or
        image.Size > std.math.maxInt(u64) - image.VirtualBase)
    {
        return LoadError.UnsupportedImageLayout;
    }

    return image;
}

fn validateHeader(data: []const u8) LoadError!*const Elf64Header {
    if (data.len < elf.ELF64_HEADER_SIZE) return LoadError.InvalidElfHeader;

    const header: *const Elf64Header = @ptrCast(data.ptr);
    if (!header.isValid() or header.ElfVersion != elf.VERSION_CURRENT or
        header.HeaderSize != elf.ELF64_HEADER_SIZE)
    {
        return LoadError.InvalidElfHeader;
    }
    if (!header.isX8664()) return LoadError.UnsupportedArchitecture;
    if (!header.isExecutable()) return LoadError.UnsupportedElfType;

    return header;
}

fn readProgramHeaders(data: []const u8, header: *const Elf64Header) LoadError![]const Elf64ProgramHeader {
    if (header.ProgramHeaderCount == 0) return LoadError.NoLoadableSegments;
    if (header.ProgramHeaderCount == elf.PROGRAM_HEADER_COUNT_EXTENDED or
        header.ProgramHeaderEntrySize != elf.ELF64_PROGRAM_HEADER_SIZE or
        header.ProgramHeaderOffset < header.HeaderSize or
        header.ProgramHeaderOffset > data.len)
    {
        return LoadError.InvalidProgramHeaders;
    }

    const offset: usize = @intCast(header.ProgramHeaderOffset);
    const table_size = @as(usize, header.ProgramHeaderCount) * elf.ELF64_PROGRAM_HEADER_SIZE;
    if (table_size > data.len - offset) return LoadError.InvalidProgramHeaders;

    const table: [*]const Elf64ProgramHeader = @ptrCast(data.ptr + offset);
    return table[0..header.ProgramHeaderCount];
}

fn validateSegment(data_size: usize, segment: *const Elf64ProgramHeader) LoadError!void {
    if (segment.UnitSize > segment.MemorySize) return LoadError.InvalidSegment;
    if (segment.UnitSize != 0 and
        (segment.Offset > data_size or segment.UnitSize > data_size - segment.Offset))
    {
        return LoadError.InvalidSegment;
    }
    if (segment.MemorySize == 0) return;

    if (segment.MemorySize > std.math.maxInt(u64) - segment.PhysicalAddress or
        segment.MemorySize > std.math.maxInt(u64) - segment.VirtualAddress)
    {
        return LoadError.InvalidSegment;
    }
    if (segment.VirtualAddress < layout.KERNEL_BASE or
        (segment.VirtualAddress & sizes.PAGE_MASK) != (segment.PhysicalAddress & sizes.PAGE_MASK))
    {
        return LoadError.UnsupportedImageLayout;
    }
    if (segment.Alignment > 1) {
        const mask = segment.Alignment - 1;
        if ((segment.Alignment & mask) != 0 or
            (segment.VirtualAddress & mask) != (segment.Offset & mask))
        {
            return LoadError.InvalidSegment;
        }
    }
}
