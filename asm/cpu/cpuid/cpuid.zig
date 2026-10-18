//! CPUID Operations

const constants = @import("asm").cpu.constants.cpuid;
const strings = @import("asm").cpu.strings.cpuid;
const types = @import("asm").cpu.types.cpuid;

pub fn query(leaf: u32, subleaf: u32) types.Registers {
    var accumulator: u32 = undefined;
    var base: u32 = undefined;
    var count: u32 = undefined;
    var data: u32 = undefined;
    asm volatile (strings.QUERY
        : [eax] "={eax}" (accumulator),
          [ebx] "={ebx}" (base),
          [ecx] "={ecx}" (count),
          [edx] "={edx}" (data),
        : [leaf] "{eax}" (leaf),
          [subleaf] "{ecx}" (subleaf),
    );
    return .{ .EAX = accumulator, .EBX = base, .ECX = count, .EDX = data };
}

pub fn maximumExtendedLeaf() u32 {
    return query(constants.LEAF_EXTENDED_MAXIMUM, constants.SUBLEAF_DEFAULT).EAX;
}

pub fn physicalAddressBits() ?u8 {
    if (maximumExtendedLeaf() < constants.LEAF_ADDRESS_WIDTH) return null;
    const width: u8 = @intCast(query(constants.LEAF_ADDRESS_WIDTH, constants.SUBLEAF_DEFAULT).EAX & constants.PHYSICAL_ADDRESS_BITS_MASK);
    if (width < @bitSizeOf(u32) or width > @bitSizeOf(u64)) return null;
    return width;
}

pub fn supportsGigabytePages() bool {
    if (maximumExtendedLeaf() < constants.LEAF_EXTENDED_FEATURES) return false;
    return (query(constants.LEAF_EXTENDED_FEATURES, constants.SUBLEAF_DEFAULT).EDX & constants.FEATURE_GIGABYTE_PAGES) != 0;
}
