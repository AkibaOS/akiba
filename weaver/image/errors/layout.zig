//! Weaver Whole Image Layout Errors

const DynamicError = @import("shared").elf.errors.dynamic.DynamicError;

pub const LayoutError = DynamicError || error{
    AddressOverlap,
    InvalidPlacement,
    InvalidReservation,
};
