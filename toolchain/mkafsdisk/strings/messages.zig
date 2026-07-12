//! mkafsdisk Log Messages

pub const USAGE = "Usage: {s} <source_location> <output_image> <size_mb>\n";
pub const CREATING = "Creating disk image: {s}\n";
pub const SOURCE = "  Source: {s}\n";
pub const SIZE = "  Size: {d} MB\n";
pub const DONE = "Disk image created successfully\n";

pub const ESP_RANGE = "  ESP: sectors {d}-{d}\n";
pub const AFS_RANGE = "  AFS: sectors {d}-{d}\n";

pub const ESP_CREATING = "  Creating FAT32 ESP...\n";
pub const ESP_TOO_SMALL = "    ESP too small for FAT32: {d} clusters (minimum {d})\n";
pub const ESP_CREATED = "    FAT32 ESP created ({d} clusters)\n";
pub const BOOTLOADER_MISSING = "    Warning: Cannot open bootloader: {}\n";
pub const BOOTLOADER_ADDING = "    Adding BOOTX64.EFI ({d} bytes, {d} clusters)\n";

pub const AFS_CREATING = "  Creating AFS filesystem...\n";
pub const AFS_TOTAL_CELLS = "    Total cells: {d}\n";
pub const AFS_CELL_SIZE = "    Cell size: {d}\n";
pub const AFS_COUNTS = "    Units: {d}, Stacks: {d}\n";
pub const AFS_FREE_CELLS = "    Free cells: {d}\n";
pub const AFS_OPEN_WARNING = "    Warning: Cannot open {s}: {}\n";
pub const AFS_ADDED_STACK = "    Added stack: {s}/\n";
pub const AFS_ADDED_UNIT = "    Added unit: {s}\n";
