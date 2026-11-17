//! Validated Segment Page Unions

const sizes = @import("common").constants.memory.sizes;
const Plan = @import("shared").elf.types.image.Plan;
const Program = @import("shared").elf.types.format.Elf64ProgramHeader;

pub fn start(segment: Program) u64 {
    return segment.VirtualAddress & ~sizes.PAGE_MASK;
}

pub fn end(segment: Program) u64 {
    return (segment.VirtualAddress + segment.MemorySize + sizes.PAGE_MASK) & ~sizes.PAGE_MASK;
}

pub fn isFirst(plan: *const Plan, index: usize, address: u64) bool {
    for (plan.Segments[0..index]) |previous| {
        if (address >= start(previous) and address < end(previous)) return false;
    }
    return true;
}

pub fn flags(plan: *const Plan, address: u64) u32 {
    var result: u32 = 0;
    for (plan.Segments[0..plan.Count]) |segment| {
        if (address >= start(segment) and address < end(segment)) result |= segment.Flags;
    }
    return result;
}
