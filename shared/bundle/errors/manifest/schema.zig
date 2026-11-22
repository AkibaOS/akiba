//! Manifest Schema Refusals

pub const ManifestError = error{ OutOfMemory, TooLarge, InvalidManifest, UnsupportedVersion, UnsupportedABI, UnsupportedType };
