//! Hikari Kernel ELF Layout Types

const constants = @import("hikari").loader.constants.kernel;
const format = @import("shared").elf.types.format;

pub const ImageLayout = struct {
    EntryPoint: u64,
    VirtualBase: u64,
    PhysicalBase: u64,
    Size: u64,
    Segments: [constants.SEGMENT_COUNT]format.Elf64ProgramHeader,
    SegmentCount: usize,
};

pub const LoadedSegment = struct {
    VirtualAddress: u64,
    PhysicalAddress: u64,
    MemorySize: u64,
    Flags: u32,
};

pub const LoadedImage = struct {
    EntryPoint: u64,
    VirtualBase: u64,
    BaseAddress: u64,
    EndAddress: u64,
    Segments: [constants.SEGMENT_COUNT]LoadedSegment,
    SegmentCount: usize,

    pub fn totalSize(self: *const LoadedImage) u64 {
        return self.EndAddress - self.BaseAddress;
    }
};
