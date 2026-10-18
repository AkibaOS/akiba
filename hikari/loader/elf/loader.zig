//! Hikari ELF Loader

const std = @import("std");

const common = @import("common");
const efi = @import("hikari").efi;
const errors = @import("hikari").loader.errors;
const types = @import("hikari").loader.types;
const validation = @import("hikari").loader.elf.validation;

const sizes = common.constants.memory.sizes;

const LoadError = errors.elf.LoadError;
const LoadedImage = types.elf.LoadedImage;

pub const Loader = struct {
    BootServices: *efi.services.boot.BootServices,
    PhysicalLimit: u64,

    pub fn initialize(boot_services: *efi.services.boot.BootServices, physical_limit: u64) Loader {
        return Loader{
            .BootServices = boot_services,
            .PhysicalLimit = physical_limit,
        };
    }

    pub fn load(self: *Loader, unit_data: []const u8) LoadError!LoadedImage {
        const image_layout = try validation.validateImage(unit_data);
        if (self.PhysicalLimit == 0 or (self.PhysicalLimit & sizes.PAGE_MASK) != 0 or
            image_layout.Size > self.PhysicalLimit) return LoadError.UnsupportedImageLayout;
        const pages_needed: usize = @intCast(image_layout.Size / sizes.PAGE_SIZE);

        var physical_base: efi.types.base.PhysicalAddress = image_layout.PhysicalBase;
        const allocation_status = if (physical_base != 0 and physical_base <= self.PhysicalLimit - image_layout.Size)
            self.BootServices.AllocatePages(.Address, .LoaderData, pages_needed, &physical_base)
        else
            efi.constants.status.UNSUPPORTED;

        if (efi.types.base.isError(allocation_status)) {
            physical_base = self.PhysicalLimit - 1;
            const fallback_status = self.BootServices.AllocatePages(
                .MaxAddress,
                .LoaderData,
                pages_needed,
                &physical_base,
            );

            if (efi.types.base.isError(fallback_status)) {
                return LoadError.AllocationFailed;
            }
        }

        if (physical_base == 0 or (physical_base & sizes.PAGE_MASK) != 0 or
            physical_base > self.PhysicalLimit - image_layout.Size or
            image_layout.Size > std.math.maxInt(u64) - physical_base)
        {
            _ = self.BootServices.FreePages(physical_base, pages_needed);
            return LoadError.AllocationFailed;
        }

        const destination_base: [*]u8 = @ptrFromInt(physical_base);
        const allocation_size: usize = @intCast(image_layout.Size);
        @memset(destination_base[0..allocation_size], 0);

        var image = LoadedImage{
            .EntryPoint = image_layout.EntryPoint,
            .VirtualBase = image_layout.VirtualBase,
            .BaseAddress = physical_base,
            .EndAddress = physical_base + image_layout.Size,
            .Segments = undefined,
            .SegmentCount = 0,
        };

        for (image_layout.Segments[0..image_layout.SegmentCount]) |segment| {
            const memory_offset: usize = @intCast(segment.PhysicalAddress - image_layout.PhysicalBase);

            if (segment.UnitSize != 0) {
                const source_offset: usize = @intCast(segment.Offset);
                const source_size: usize = @intCast(segment.UnitSize);
                const source = unit_data[source_offset..][0..source_size];
                const destination = destination_base + memory_offset;
                @memcpy(destination[0..source_size], source);
            }

            image.Segments[image.SegmentCount] = types.elf.LoadedSegment{
                .VirtualAddress = segment.VirtualAddress,
                .PhysicalAddress = physical_base + memory_offset,
                .MemorySize = segment.MemorySize,
                .Flags = segment.Flags,
            };
            image.SegmentCount += 1;
        }

        return image;
    }
};

pub fn validateElf(data: []const u8) bool {
    _ = validation.validateImage(data) catch return false;
    return true;
}
