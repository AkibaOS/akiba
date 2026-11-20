//! Hikari ELF Loader

const common = @import("common");
const efi = @import("hikari").efi;
const errors = @import("hikari").loader.errors.elf.load;
const types = @import("hikari").loader.types.elf.image;
const validation = @import("hikari").loader.elf.validation;

const layout = common.constants.memory.layout;
const sizes = common.constants.memory.sizes;

pub fn load(boot_services: *efi.types.services.boot.BootServices, physical_limit: u64, unit_data: []const u8, owner: *efi.types.pages.claims.Claim) errors.LoadError!types.LoadedImage {
    if (owner.Untrusted) return error.AllocationFailed;
    const image_layout = try validation.validateImage(unit_data);
    if (physical_limit == 0 or (physical_limit & sizes.PAGE_MASK) != 0 or
        image_layout.Size > physical_limit)
    {
        return error.UnsupportedImageLayout;
    }
    const pages_needed: usize = @intCast(image_layout.Size / sizes.PAGE_SIZE);
    const preferred = efi.pages.acquire(boot_services, layout.KERNEL_PHYSICAL_BASE, physical_limit, pages_needed, &owner.Backing);
    const acquired = if (preferred == .Unavailable)
        efi.pages.acquire(boot_services, null, physical_limit, pages_needed, &owner.Backing)
    else
        preferred;
    owner.Untrusted = acquired == .Untrusted;
    if (acquired != .Acquired) return error.AllocationFailed;
    const physical_base = owner.Backing.?.Physical;
    if (physical_base == 0) return error.AllocationFailed;

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
