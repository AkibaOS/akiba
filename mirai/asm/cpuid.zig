//! CPUID Operations

pub const CpuidResult = struct {
    eax: u32,
    ebx: u32,
    ecx: u32,
    edx: u32,
};

/// Execute CPUID instruction with given leaf
pub inline fn cpuid(leaf: u32) CpuidResult {
    var eax: u32 = undefined;
    var ebx: u32 = undefined;
    var ecx: u32 = undefined;
    var edx: u32 = undefined;

    asm volatile ("cpuid"
        : [eax] "={eax}" (eax),
          [ebx] "={ebx}" (ebx),
          [ecx] "={ecx}" (ecx),
          [edx] "={edx}" (edx),
        : [leaf] "{eax}" (leaf),
    );

    return CpuidResult{
        .eax = eax,
        .ebx = ebx,
        .ecx = ecx,
        .edx = edx,
    };
}

/// Get maximum extended CPUID leaf
pub inline fn get_max_extended() u32 {
    return cpuid(0x80000000).eax;
}

/// Check if extended brand string is supported
pub inline fn has_brand_string() bool {
    return get_max_extended() >= 0x80000004;
}

/// Get CPU brand string (48 bytes)
pub fn get_brand_string(buffer: *[48]u8) void {
    var pos: usize = 0;

    inline for ([_]u32{ 0x80000002, 0x80000003, 0x80000004 }) |leaf| {
        const result = cpuid(leaf);

        inline for ([_]u32{ result.eax, result.ebx, result.ecx, result.edx }) |reg| {
            buffer[pos] = @truncate(reg);
            buffer[pos + 1] = @truncate(reg >> 8);
            buffer[pos + 2] = @truncate(reg >> 16);
            buffer[pos + 3] = @truncate(reg >> 24);
            pos += 4;
        }
    }
}
