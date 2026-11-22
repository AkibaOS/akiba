//! Portable Bundle Identity Bounds

const paths = @import("shared").location.strings.installed.paths;

pub const MAX_BYTES: usize = 128;
pub const MAX_PATH_BYTES: usize = MAX_BYTES + @max(paths.SYSTEM_BINARIES.len, paths.SYSTEM_DRIVERS.len, paths.BINARIES.len) +
    @max(paths.BUNDLE_SUFFIX.len, paths.DRIVER_SUFFIX.len) + @max(paths.MANIFEST_UNIT.len, paths.BINARY_UNIT.len) + 2;
