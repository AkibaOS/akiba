//! Firmware Kernel Image Geometry And Growth Regressions

const std = @import("std");

const elf = @import("shared").elf.types.format;
const efi = @import("hikari").efi;
const fixtures = @import("tests").constants.hikari;
const inputs = @import("tests").constants.loading;
const labels = @import("tests").strings.loading;
const loader = @import("hikari").loader.elf.loader;
const output = @import("tests").firmware.run;
const validation = @import("hikari").loader.elf.validation;

pub fn run(real: *efi.types.services.boot.BootServices) !void {
    try unit(real);
    try span(real);
}

fn unit(real: *efi.types.services.boot.BootServices) !void {
    var storage: [*]align(8) u8 = undefined;
    if (efi.status.isError(real.AllocatePool(.LoaderData, inputs.LARGE_UNIT_BYTES, &storage))) return error.AllocationFailed;
    defer if (efi.status.isError(real.FreePool(storage))) output.fail(labels.CLEANUP_FAILED);
    const bytes = storage[0..inputs.LARGE_UNIT_BYTES];
    @memset(bytes, 0);
    @memcpy(bytes[0..fixtures.VALID_ELF.len], &fixtures.VALID_ELF);
    const image = try validation.validateImage(bytes);
    output.require(image.Size == inputs.IMAGE_BYTES and image.SegmentCount == fixtures.ELF_PROGRAM_COUNT, labels.LARGE_UNIT);
}

fn span(real: *efi.types.services.boot.BootServices) !void {
    var bytes = fixtures.VALID_ELF;
    program(&bytes, inputs.DATA_SEGMENT_INDEX).MemorySize += inputs.LARGE_BSS_BYTES;
    for (inputs.FIRST_STACK_INDEX..fixtures.ELF_PROGRAM_COUNT) |index| {
        program(&bytes, index).VirtualAddress += inputs.LARGE_BSS_BYTES;
        program(&bytes, index).PhysicalAddress += inputs.LARGE_BSS_BYTES;
    }
    const planned = try validation.validateImage(&bytes);
    output.require(planned.Size == inputs.IMAGE_BYTES + inputs.LARGE_BSS_BYTES, labels.LARGE_PLAN);
    var backing: efi.types.pages.Claim = .{};
    defer if (!efi.pages.release(real, &backing.Backing)) output.fail(labels.CLEANUP_FAILED);
    const refused = if (loader.load(real, inputs.LARGE_BSS_BYTES, &bytes, &backing)) |_| false else |failure| failure == error.UnsupportedImageLayout;
    output.require(refused and backing.Backing == null and !backing.Untrusted, labels.LARGE_GEOMETRY);
    const image = try loader.load(real, inputs.PHYSICAL_LIMIT, &bytes, &backing);
    const payload: [*]const u8 = @ptrFromInt(image.BaseAddress);
    output.require(image.totalSize() == planned.Size and payload[0] == inputs.TEXT_BYTE and
        payload[inputs.TEXT_END] == inputs.READ_ONLY_BYTE and payload[inputs.READ_ONLY_END] == inputs.DATA_BYTE and
        payload[inputs.DATA_END] == 0 and payload[inputs.DATA_MEMORY_END + inputs.LARGE_BSS_BYTES - 1] == 0 and
        payload[@intCast(image.totalSize() - 1)] == 0, labels.LARGE_LOAD);

    bytes = fixtures.VALID_ELF;
    program(&bytes, inputs.DATA_SEGMENT_INDEX).MemorySize = std.math.maxInt(u64);
    const overflow = if (validation.validateImage(&bytes)) |_| false else |failure| failure == error.InvalidSegment;
    output.require(overflow, labels.LARGE_OVERFLOW);
}

fn program(bytes: *[fixtures.ELF_BYTES]u8, index: usize) *align(1) elf.Elf64ProgramHeader {
    return @ptrCast(bytes[fixtures.ELF_TABLE_OFFSET + index * fixtures.ELF_PROGRAM_BYTES ..].ptr);
}
