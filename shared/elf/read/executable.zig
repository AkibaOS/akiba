//! Verify The Executable Header And File Backed Entry

const format = @import("shared").elf.constants.format;
const read = @import("shared").elf.read;

const ImageError = @import("shared").elf.errors.image.ImageError;

pub fn check(data: []const u8) ImageError!void {
    const header = try read.header.read(data);
    if (!header.isX8664()) return error.UnsupportedArchitecture;
    if (!header.isExecutable() and header.ElfType != format.TYPE_DYNAMIC) return error.UnsupportedImage;
    const segments = try read.programs.read(data, header);
    var entry = false;
    for (segments) |segment| {
        if (!segment.isLoadable()) continue;
        if (segment.UnitSize > segment.MemorySize or segment.Offset > data.len or
            segment.UnitSize > data.len - segment.Offset) return error.InvalidSegment;
        if (segment.isExecutable() and header.Entry >= segment.VirtualAddress and
            header.Entry - segment.VirtualAddress < segment.UnitSize) entry = true;
    }
    if (!entry) return error.InvalidEntryPoint;
}
