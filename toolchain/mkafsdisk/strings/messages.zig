//! mkafsdisk Command Text

pub const USAGE = "Usage: {s} <source_location> <output_image> <size_mb> [--image-label <name>]\n";
pub const IMAGE_LABEL = "--image-label";
pub const PACKING = "Packing units: {s}";
pub const PROGRESS_STREAM = "--progress-stream";
pub const CLEAR_LINE = "\r\x1b[2K";
pub const LIVE_PACKING = CLEAR_LINE ++ "[{d}/{d}] Packing units: {s}\r";
pub const REPORT = "[{d}/{d}] Packed units: {s}\n" ++
    "Creating disk image: {s}\n" ++
    "  Source: {s}\n" ++
    "  Size: {d} MB\n" ++
    "  ESP: sectors {d}-{d}\n" ++
    "  AFS: sectors {d}-{d}\n" ++
    "  Creating FAT32 ESP...\n" ++
    "    Adding BOOTX64.EFI ({d} bytes, {d} clusters)\n" ++
    "    FAT32 ESP created ({d} clusters)\n" ++
    "  Creating AFS filesystem...\n" ++
    "    Total cells: {d}\n" ++
    "    Cell size: {d}\n" ++
    "    Units: {d}, Stacks: {d}\n" ++
    "    Free cells: {d}\n" ++
    "Disk image created successfully\n";
