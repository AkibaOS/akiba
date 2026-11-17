//! Bounded ELF Image Plans

const limits = @import("shared").elf.constants.limits;
const Program = @import("shared").elf.types.format.Elf64ProgramHeader;

pub const Policy = struct {
    MinimumAddress: u64,
    MaximumAddress: u64,
    MaximumPages: u64,
};

pub const Plan = struct {
    Entry: u64,
    Segments: [limits.MAX_SEGMENTS]Program,
    Count: usize,
    Pages: u64,
};
