//! Hikari ELF Loader

const std = @import("std");

const common = @import("common");
const constants = @import("hikari").loader.constants;
const efi = @import("hikari").efi;
const errors = @import("hikari").loader.errors;
const types = @import("hikari").loader.types;

const LoadError = errors.elf.LoadError;
const sizes = common.constants.memory.sizes;

pub const Loader = struct {
    BootServices: *efi.services.boot.BootServices,

    pub fn initialize(boot_services: *efi.services.boot.BootServices) Loader {
        return Loader{
            .BootServices = boot_services,
        };
    }

    pub fn load(self: *Loader, unit_data: [*]const u8, unit_size: u64) LoadError!types.elf.LoadedImage {
        if (unit_size < constants.elf.ELF64_HEADER_SIZE) {
            return LoadError.InvalidElfHeader;
        }

        const header: *const types.elf.Elf64Header = @ptrCast(@alignCast(unit_data));

        if (!header.isValid()) {
            return LoadError.InvalidElfHeader;
        }

        if (!header.isX8664()) {
            return LoadError.UnsupportedArchitecture;
        }

        if (!header.isExecutable()) {
            return LoadError.UnsupportedElfType;
        }

        const program_headers = header.getProgramHeaders(unit_data);

        var load_base: u64 = std.math.maxInt(u64);
        var load_end: u64 = 0;
        var loadable_count: usize = 0;

        for (program_headers) |*program_header| {
            if (!program_header.isLoadable()) {
                continue;
            }

            loadable_count += 1;

            if (program_header.VirtualAddress < load_base) {
                load_base = program_header.VirtualAddress;
            }

            const segment_end = program_header.VirtualAddress + program_header.MemorySize;
            if (segment_end > load_end) {
                load_end = segment_end;
            }
        }

        if (loadable_count == 0) {
            return LoadError.NoLoadableSegments;
        }

        if (loadable_count > constants.elf.MAX_SEGMENTS) {
            return LoadError.TooManySegments;
        }

        const total_size = load_end - load_base;
        const pages_needed = (total_size + sizes.PAGE_SIZE - 1) / sizes.PAGE_SIZE;

        var physical_base: efi.types.base.PhysicalAddress = load_base;
        const allocation_status = self.BootServices.AllocatePages(
            .Address,
            .LoaderData,
            pages_needed,
            &physical_base,
        );

        if (efi.types.base.isError(allocation_status)) {
            physical_base = 0;
            const fallback_status = self.BootServices.AllocatePages(
                .AnyPages,
                .LoaderData,
                pages_needed,
                &physical_base,
            );

            if (efi.types.base.isError(fallback_status)) {
                return LoadError.AllocationFailed;
            }
        }

        const destination_base: [*]u8 = @ptrFromInt(physical_base);
        @memset(destination_base[0..total_size], 0);

        var image = types.elf.LoadedImage{
            .EntryPoint = header.Entry,
            .BaseAddress = physical_base,
            .EndAddress = physical_base + total_size,
            .Segments = undefined,
            .SegmentCount = 0,
        };

        for (program_headers) |*program_header| {
            if (!program_header.isLoadable()) {
                continue;
            }

            const segment_offset = program_header.VirtualAddress - load_base;
            const destination = destination_base + segment_offset;
            const source = unit_data + program_header.Offset;

            @memcpy(destination[0..program_header.UnitSize], source[0..program_header.UnitSize]);

            image.Segments[image.SegmentCount] = types.elf.LoadedSegment{
                .VirtualAddress = program_header.VirtualAddress,
                .PhysicalAddress = physical_base + segment_offset,
                .MemorySize = program_header.MemorySize,
                .Flags = program_header.Flags,
            };
            image.SegmentCount += 1;
        }

        if (physical_base != load_base) {
            image.EntryPoint = (header.Entry - load_base) + physical_base;
        }

        return image;
    }

    pub fn getMemoryRequirements(unit_data: [*]const u8) LoadError!struct { Base: u64, Size: u64 } {
        const header: *const types.elf.Elf64Header = @ptrCast(@alignCast(unit_data));

        if (!header.isValid()) {
            return LoadError.InvalidElfHeader;
        }

        const program_headers = header.getProgramHeaders(unit_data);

        var load_base: u64 = std.math.maxInt(u64);
        var load_end: u64 = 0;

        for (program_headers) |*program_header| {
            if (!program_header.isLoadable()) {
                continue;
            }

            if (program_header.VirtualAddress < load_base) {
                load_base = program_header.VirtualAddress;
            }

            const segment_end = program_header.VirtualAddress + program_header.MemorySize;
            if (segment_end > load_end) {
                load_end = segment_end;
            }
        }

        if (load_base == std.math.maxInt(u64)) {
            return LoadError.NoLoadableSegments;
        }

        return .{
            .Base = load_base,
            .Size = load_end - load_base,
        };
    }

    pub fn getEntryPoint(unit_data: [*]const u8) LoadError!u64 {
        const header: *const types.elf.Elf64Header = @ptrCast(@alignCast(unit_data));

        if (!header.isValid()) {
            return LoadError.InvalidElfHeader;
        }

        return header.Entry;
    }
};

pub fn validateElf(data: [*]const u8, size: u64) bool {
    if (size < constants.elf.ELF64_HEADER_SIZE) {
        return false;
    }

    const header: *const types.elf.Elf64Header = @ptrCast(@alignCast(data));
    return header.isValid() and header.isX8664();
}
