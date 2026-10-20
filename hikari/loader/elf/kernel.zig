//! Hikari Kernel ELF Layout Validation

const elf = @import("hikari").loader.constants.elf;
const errors = @import("hikari").loader.errors.elf;
const kernel = @import("hikari").loader.constants.kernel;
const layout = @import("common").constants.memory.layout;
const sizes = @import("common").constants.memory.sizes;
const types = @import("hikari").loader.types.elf;

pub fn validate(image: *const types.ImageLayout) errors.LoadError!void {
    if (image.SegmentCount != kernel.SEGMENT_COUNT or
        image.VirtualBase != layout.KERNEL_BASE + layout.KERNEL_PHYSICAL_BASE)
    {
        return error.UnsupportedImageLayout;
    }

    var memory_end = image.VirtualBase;
    for (image.Segments[0..image.SegmentCount], 0..) |segment, index| {
        const expected_flags = elf.SEGMENT_FLAG_READ | switch (index) {
            kernel.TEXT_INDEX => elf.SEGMENT_FLAG_EXECUTE,
            kernel.READ_ONLY_INDEX => @as(u32, 0),
            else => elf.SEGMENT_FLAG_WRITE,
        };
        if (segment.Flags != expected_flags or
            (segment.VirtualAddress & sizes.PAGE_MASK) != 0 or
            (segment.MemorySize & sizes.PAGE_MASK) != 0)
        {
            return error.InvalidSegment;
        }
        if (index < kernel.STORED_SEGMENT_COUNT) {
            if (segment.VirtualAddress != memory_end or segment.UnitSize == 0 or
                (index != kernel.DATA_INDEX and segment.UnitSize != segment.MemorySize))
            {
                return error.UnsupportedImageLayout;
            }
        } else {
            if (segment.VirtualAddress < memory_end or
                segment.VirtualAddress - memory_end != sizes.PAGE_SIZE or
                segment.MemorySize != layout.BOOT_INTERRUPT_STACK_SIZE or segment.UnitSize != 0)
            {
                return error.UnsupportedImageLayout;
            }
        }
        memory_end = segment.VirtualAddress + segment.MemorySize;
    }
    if (memory_end - image.VirtualBase != image.Size) return error.UnsupportedImageLayout;
}
