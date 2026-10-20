//! Hikari ELF Loader

const std = @import("std");

const common = @import("common");
const efi = @import("hikari").efi;
const errors = @import("hikari").loader.errors.elf;
const types = @import("hikari").loader.types.elf;
const validation = @import("hikari").loader.elf.validation;

const layout = common.constants.memory.layout;
const sizes = common.constants.memory.sizes;

pub fn load(boot_services: *efi.services.boot.BootServices, physical_limit: u64, unit_data: []const u8) errors.LoadError!types.LoadedImage {
    const image_layout = try validation.validateImage(unit_data);
    if (physical_limit == 0 or (physical_limit & sizes.PAGE_MASK) != 0 or
        image_layout.Size > physical_limit)
    {
        return error.UnsupportedImageLayout;
    }
    const pages_needed: usize = @intCast(image_layout.Size / sizes.PAGE_SIZE);
    var physical_base: efi.types.base.PhysicalAddress = layout.KERNEL_PHYSICAL_BASE;
    const allocation_status = if (physical_base <= physical_limit - image_layout.Size)
        boot_services.AllocatePages(.Address, .LoaderData, pages_needed, &physical_base)
    else
        efi.constants.status.UNSUPPORTED;
    if (efi.types.base.isError(allocation_status)) {
        physical_base = physical_limit - 1;
        const fallback_status = boot_services.AllocatePages(.MaxAddress, .LoaderData, pages_needed, &physical_base);
        if (efi.types.base.isError(fallback_status)) return error.AllocationFailed;
    }
    if (physical_base == 0 or (physical_base & sizes.PAGE_MASK) != 0 or
        physical_base > physical_limit - image_layout.Size or
        image_layout.Size > std.math.maxInt(u64) - physical_base)
    {
        _ = boot_services.FreePages(physical_base, pages_needed);
        return error.AllocationFailed;
    }

    const destination_base: [*]u8 = @ptrFromInt(physical_base);
    const allocation_size: usize = @intCast(image_layout.Size);
    @memset(destination_base[0..allocation_size], 0);
    var image: types.LoadedImage = .{
        .EntryPoint = image_layout.EntryPoint,
        .VirtualBase = image_layout.VirtualBase,
        .BaseAddress = physical_base,
        .EndAddress = physical_base + image_layout.Size,
        .Segments = undefined,
        .SegmentCount = image_layout.SegmentCount,
    };
    for (image_layout.Segments[0..image_layout.SegmentCount], 0..) |segment, index| {
        const memory_offset: usize = @intCast(segment.PhysicalAddress - image_layout.PhysicalBase);
        if (segment.UnitSize != 0) {
            const source_offset: usize = @intCast(segment.Offset);
            const source_size: usize = @intCast(segment.UnitSize);
            @memcpy((destination_base + memory_offset)[0..source_size], unit_data[source_offset..][0..source_size]);
        }
        image.Segments[index] = .{
            .VirtualAddress = segment.VirtualAddress,
            .PhysicalAddress = physical_base + memory_offset,
            .MemorySize = segment.MemorySize,
            .Flags = segment.Flags,
        };
    }
    return image;
}
