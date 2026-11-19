//! Checked Native Dynamic Load Placement

const std = @import("std");

const format = @import("shared").elf.constants.format;
const load = @import("shared").elf.validate.load;
const read = @import("shared").elf.read;
const sizes = @import("common").constants.memory.sizes;
const types = @import("shared").elf.types;

const DynamicError = @import("shared").elf.errors.dynamic.DynamicError;
const Layout = types.dynamic.Layout;
const Policy = types.image.Policy;
const Program = types.format.Elf64ProgramHeader;
const Relro = types.dynamic.Relro;
const Role = types.dynamic.Role;

pub fn parse(allocator: std.mem.Allocator, data: []const u8, bias: u64, role: Role, policy: Policy) DynamicError!Layout {
    try load.validatePolicy(policy);
    if (bias & sizes.PAGE_MASK != 0 or bias > policy.MaximumAddress) return error.InvalidPolicy;
    const metadata = try read.dynamic.read(data);
    const header = try read.header.read(data);
    const programs = try read.programs.read(data, header);
    const entry = if (role == .Executable) address: {
        if (header.Entry == 0) return error.InvalidEntryPoint;
        break :address std.math.add(u64, header.Entry, bias) catch return error.InvalidEntryPoint;
    } else 0;
    var count: usize = 0;
    var entry_found = role == .Library;
    var relro: ?Program = null;
    for (programs) |segment| {
        switch (segment.SegmentType) {
            format.SEGMENT_NULL, format.SEGMENT_NOTE, format.SEGMENT_PHDR, format.SEGMENT_DYNAMIC => {},
            format.SEGMENT_STACK => if (segment.isExecutable()) return error.UnsupportedSegment,
            format.SEGMENT_RELRO => {
                if (relro != null) return error.InvalidRelro;
                relro = segment;
            },
            format.SEGMENT_LOAD => {
                const mapped = try rebase(segment, bias);
                try load.validateSegment(data.len, mapped, policy);
                count += 1;
                if (mapped.isExecutable() and entry >= mapped.VirtualAddress and
                    entry - mapped.VirtualAddress < mapped.UnitSize) entry_found = true;
            },
            else => return error.UnsupportedSegment,
        }
    }
    if (count == 0) return error.NoLoadableSegments;
    if (!entry_found) return error.InvalidEntryPoint;
    const segments = try allocator.alloc(Program, count);
    errdefer allocator.free(segments);
    var index: usize = 0;
    for (programs) |segment| {
        if (segment.SegmentType != format.SEGMENT_LOAD) continue;
        segments[index] = try rebase(segment, bias);
        index += 1;
    }
    const seal = if (relro) |region| try sealRange(region, bias, segments) else null;
    return .{
        .Image = try load.plan(allocator, segments, entry, policy.MaximumPages),
        .Metadata = metadata,
        .Bias = bias,
        .Relro = seal,
    };
}

fn rebase(segment: Program, bias: u64) DynamicError!Program {
    var mapped = segment;
    mapped.VirtualAddress = std.math.add(u64, segment.VirtualAddress, bias) catch return error.InvalidSegment;
    return mapped;
}

fn sealRange(region: Program, bias: u64, segments: []const Program) DynamicError!Relro {
    if (region.Flags != format.SEGMENT_FLAG_READ or region.MemorySize == 0 or region.UnitSize > region.MemorySize)
        return error.InvalidRelro;
    const start = std.math.add(u64, region.VirtualAddress, bias) catch return error.InvalidRelro;
    const end = std.math.add(u64, start, region.MemorySize) catch return error.InvalidRelro;
    if (end & sizes.PAGE_MASK != 0) return error.InvalidRelro;
    const page_start = start & ~sizes.PAGE_MASK;
    var contained = false;
    for (segments) |segment| {
        if (!segment.isWritable()) continue;
        const segment_end = segment.VirtualAddress + segment.MemorySize;
        if (page_start < start and segment.VirtualAddress < start and page_start < segment_end) return error.InvalidRelro;
        if (start < segment.VirtualAddress or end > segment_end) continue;
        if (region.UnitSize != 0) {
            const displacement = start - segment.VirtualAddress;
            if (displacement > segment.UnitSize or region.UnitSize > segment.UnitSize - displacement or
                region.Offset != segment.Offset + displacement) return error.InvalidRelro;
        }
        contained = true;
    }
    if (!contained) return error.InvalidRelro;
    return .{ .Start = page_start, .End = end };
}
