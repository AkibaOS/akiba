//! Hikari ELF Validation Guest Regressions

const std = @import("std");

const elf = @import("shared").elf.types.format;
const errors = @import("hikari").loader.errors.elf;
const format = @import("shared").elf.constants.format;
const inputs = @import("tests").constants.hikari;
const labels = @import("tests").strings.hikari;
const types = @import("tests").types.hikari;
const validation = @import("hikari").loader.elf.validation;
const verify = @import("tests").guest.support.verify;

pub fn run() !void {
    const image = try validation.validateImage(&inputs.VALID_ELF);
    verify.require(image.EntryPoint == inputs.ELF_ENTRY and image.VirtualBase == inputs.ELF_VIRTUAL_BASE and
        image.PhysicalBase == inputs.ELF_PHYSICAL_BASE and image.Size == inputs.ELF_MEMORY_BYTES and
        image.SegmentCount == inputs.ELF_PROGRAM_COUNT and std.meta.eql(inputs.EXPECTED_SEGMENTS, image.Segments), labels.ELF_VALID);

    verify.require(rejects(&.{}, errors.LoadError.InvalidElfHeader) and
        rejects(inputs.VALID_ELF[0 .. inputs.ELF_HEADER_BYTES - 1], errors.LoadError.InvalidElfHeader), labels.ELF_HEADER_MISSING);
    var bytes = inputs.VALID_ELF;
    header(&bytes).Magic[0] ^= 1;
    verify.require(rejects(&bytes, errors.LoadError.InvalidElfHeader), labels.ELF_HEADER_MALFORMED);

    bytes = inputs.VALID_ELF;
    header(&bytes).ProgramHeaderCount = 0;
    verify.require(rejects(&bytes, errors.LoadError.NoLoadableSegments), labels.ELF_TABLE_MISSING);
    verify.require(rejects(inputs.VALID_ELF[0 .. inputs.ELF_TABLE_END - 1], errors.LoadError.InvalidProgramHeaders), labels.ELF_TABLE_TRUNCATED);
    bytes = inputs.VALID_ELF;
    header(&bytes).ProgramHeaderEntrySize -= 1;
    const entry_size_rejected = rejects(&bytes, errors.LoadError.InvalidProgramHeaders);
    bytes = inputs.VALID_ELF;
    header(&bytes).ProgramHeaderOffset = inputs.ELF_HEADER_BYTES - 1;
    verify.require(entry_size_rejected and rejects(&bytes, errors.LoadError.InvalidProgramHeaders), labels.ELF_TABLE_MALFORMED);

    bytes = inputs.VALID_ELF;
    program(&bytes, 6).SegmentType = 2;
    verify.require(rejects(&bytes, errors.LoadError.UnsupportedElfType), labels.ELF_DYNAMIC);
    bytes = inputs.VALID_ELF;
    program(&bytes, 6).SegmentType = 3;
    verify.require(rejects(&bytes, errors.LoadError.UnsupportedElfType), labels.ELF_INTERPRETER);
    bytes = inputs.VALID_ELF;
    header(&bytes).ProgramHeaderCount += 1;
    program(&bytes, inputs.ELF_PROGRAM_COUNT).SegmentType = format.SEGMENT_TLS;
    verify.require(rejects(&bytes, errors.LoadError.UnsupportedElfType), labels.ELF_TLS);
    bytes = inputs.VALID_ELF;
    program(&bytes, 0).Flags = 7;
    verify.require(rejects(&bytes, errors.LoadError.InvalidSegment), labels.ELF_WRITE_EXECUTE);

    bytes = inputs.VALID_ELF;
    program(&bytes, 1).VirtualAddress = inputs.ELF_VIRTUAL_BASE;
    program(&bytes, 1).PhysicalAddress = inputs.ELF_PHYSICAL_BASE;
    verify.require(rejects(&bytes, errors.LoadError.SegmentOverlap), labels.ELF_OVERLAP);
    bytes = inputs.VALID_ELF;
    header(&bytes).Entry = inputs.ELF_VIRTUAL_BASE + inputs.ELF_PAGE_BYTES;
    verify.require(rejects(&bytes, errors.LoadError.InvalidEntryPoint), labels.ELF_ENTRY);
    bytes = inputs.VALID_ELF;
    program(&bytes, 3).VirtualAddress += inputs.ELF_PAGE_BYTES;
    program(&bytes, 3).PhysicalAddress += inputs.ELF_PAGE_BYTES;
    verify.require(rejects(&bytes, errors.LoadError.UnsupportedImageLayout), labels.ELF_LAYOUT);

    bytes = inputs.VALID_ELF;
    program(&bytes, 2).Offset = inputs.ELF_BYTES;
    verify.require(rejects(&bytes, errors.LoadError.InvalidSegment), labels.ELF_FILE_BOUNDS);
    bytes = inputs.VALID_ELF;
    program(&bytes, 0).PhysicalAddress = std.math.maxInt(u64) - 7;
    const physical_rejected = rejects(&bytes, errors.LoadError.InvalidSegment);
    bytes = inputs.VALID_ELF;
    program(&bytes, 0).VirtualAddress = std.math.maxInt(u64) - 7;
    verify.require(physical_rejected and rejects(&bytes, errors.LoadError.InvalidSegment), labels.ELF_ADDRESS_BOUNDS);
}

fn rejects(data: []const u8, expected: errors.LoadError) bool {
    _ = validation.validateImage(data) catch |failure| return failure == expected;
    return false;
}

fn header(bytes: *types.ELFBytes) *elf.Elf64Header {
    return @ptrCast(bytes);
}

fn program(bytes: *types.ELFBytes, index: usize) *elf.Elf64ProgramHeader {
    return @ptrCast(bytes[inputs.ELF_TABLE_OFFSET + index * inputs.ELF_PROGRAM_BYTES ..].ptr);
}
