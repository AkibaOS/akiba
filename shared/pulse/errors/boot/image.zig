//! Embedded Bootstrap Image Layout Refusals

pub const PayloadError = error{
    BootstrapImageMissing,
    InvalidBootstrapImage,
};
