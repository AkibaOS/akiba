//! Native ELF Relocation Planning Errors

pub const RelocationError = error{
    OutOfMemory,
    InvalidRelocation,
    InvalidRelocationTarget,
    InvalidRelocationValue,
    MissingBinding,
    OverlappingRelocation,
    UnsupportedRelocation,
};
