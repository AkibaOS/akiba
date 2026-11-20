//! Unusable AHCI Candidates And Ambiguous Boot Identity

pub const DiscoverError = error{
    AmbiguousBootVolume,
    InvalidAhciBar,
    InvalidAhciFunction,
};
