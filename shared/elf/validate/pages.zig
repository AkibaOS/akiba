//! Validated Segment And Planned Page Range Queries

const sizes = @import("common").constants.memory.sizes;
const Plan = @import("shared").elf.types.image.Plan;
const Program = @import("shared").elf.types.format.Elf64ProgramHeader;

pub fn start(segment: Program) u64 {
    return segment.VirtualAddress & ~sizes.PAGE_MASK;
}

pub fn end(segment: Program) u64 {
    return (segment.VirtualAddress + segment.MemorySize + sizes.PAGE_MASK) & ~sizes.PAGE_MASK;
}

pub fn flags(plan: *const Plan, address: u64) u32 {
    var lower: usize = 0;
    var upper = plan.Ranges.len;
    while (lower < upper) {
        const middle = lower + (upper - lower) / 2;
        const range = plan.Ranges[middle];
        if (address < range.Start) upper = middle else if (address >= range.End) lower = middle + 1 else return range.Flags;
    }
    return 0;
}
