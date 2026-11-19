//! mkafsdisk Command Text

pub const USAGE = "Usage: {s} <source_location> <output_image> <size_mb>\n";
pub const PACKING = "Packing units: {s}";
pub const PROGRESS_STREAM = "--progress-stream";
pub const CLEAR_LINE = "\r\x1b[2K";
pub const LIVE_PACKING = CLEAR_LINE ++ "[{d}/{d}] Packing units: {s}\r";
pub const REPORT = "Created {s} ({d} {s}) - {d} MiB\n" ++
    "  ESP: sectors {d}-{d}; FAT32: {d} clusters; BOOTX64.EFI: {d} bytes ({d} clusters)\n" ++
    "  AFS: sectors {d}-{d}; Stacks: {d}; Cell size: {d} bytes; Free cells: {d}/{d}\n";
pub const UNIT = "unit";
pub const UNITS = "units";
