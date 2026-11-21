//! Select The Exact Embedded Weaver Bytes From The Pulse ELF

const elf = @import("shared").elf;
const layout = @import("shared").pulse.constants.boot.layout;
const sizes = @import("common").constants.memory.sizes;

const ImageError = elf.errors.image.ImageError;
const PayloadError = @import("shared").pulse.errors.boot.image.PayloadError;
const Program = elf.types.format.Elf64ProgramHeader;

pub fn weaver(pulse: []const u8) (ImageError || PayloadError)![]const u8 {
    const header = try elf.read.header.read(pulse);
    const programs = try elf.read.programs.read(pulse, header);
    var found: ?usize = null;
    for (programs, 0..) |segment, index| {
        if (!segment.isLoadable() or segment.VirtualAddress != layout.WEAVER_ADDRESS) continue;
        if (found != null or segment.Flags != elf.constants.format.SEGMENT_FLAG_READ or segment.UnitSize == 0 or
            segment.UnitSize != segment.MemorySize or segment.Offset > pulse.len or segment.UnitSize > pulse.len - segment.Offset)
            return error.InvalidBootstrapImage;
        found = index;
    }
    const index = found orelse return error.BootstrapImageMissing;
    try requirePrivatePages(programs, index);
    const segment = programs[index];
    return pulse[@intCast(segment.Offset)..][0..@intCast(segment.UnitSize)];
}

fn requirePrivatePages(programs: []const Program, payload: usize) PayloadError!void {
    const first = elf.validate.pages.start(programs[payload]);
    const last = try lastPage(programs[payload]);
    for (programs, 0..) |segment, index| {
        if (index == payload or !segment.isLoadable() or segment.MemorySize == 0) continue;
        if (elf.validate.pages.start(segment) <= last and try lastPage(segment) >= first)
            return error.InvalidBootstrapImage;
    }
}

fn lastPage(segment: Program) PayloadError!u64 {
    const address, const overflow = @addWithOverflow(segment.VirtualAddress, segment.MemorySize - 1);
    if (overflow != 0) return error.InvalidBootstrapImage;
    return address & ~sizes.PAGE_MASK;
}
