//! Native ELF Dynamic Metadata Errors

const ImageError = @import("shared").elf.errors.image.ImageError;

pub const DynamicError = ImageError || error{
    MissingDynamic,
    InvalidDynamic,
    InvalidDynamicAddress,
    InvalidDynamicString,
    InvalidRelro,
    UnsupportedDynamic,
};
