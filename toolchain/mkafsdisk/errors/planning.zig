//! AFS Construction Planning Errors

pub const PlanningError = error{
    DuplicateKey,
    InvalidCatalog,
    InvalidGeometry,
    InvalidIdentity,
    InvalidNode,
    InvalidSpan,
    OutOfSpace,
    Overflow,
    RecordTooLarge,
    UnsupportedSource,
};
