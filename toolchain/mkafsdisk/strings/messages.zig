//! mkafsdisk Log Messages

pub const usage = "Usage: {s} <source_location> <output_image> <size_mb>\n";
pub const creating = "Creating disk image: {s}\n";
pub const source = "  Source: {s}\n";
pub const size = "  Size: {d} MB\n";
pub const done = "Disk image created successfully\n";

pub const esp_range = "  ESP: sectors {d}-{d}\n";
pub const afs_range = "  AFS: sectors {d}-{d}\n";

pub const esp_creating = "  Creating FAT32 ESP...\n";
pub const esp_too_small = "    ESP too small for FAT32: {d} clusters (minimum {d})\n";
pub const esp_created = "    FAT32 ESP created ({d} clusters)\n";
pub const bootloader_missing = "    Warning: Cannot open bootloader: {}\n";
pub const bootloader_adding = "    Adding BOOTX64.EFI ({d} bytes, {d} clusters)\n";

pub const afs_creating = "  Creating AFS filesystem...\n";
pub const afs_total_cells = "    Total cells: {d}\n";
pub const afs_cell_size = "    Cell size: {d}\n";
pub const afs_counts = "    Units: {d}, Stacks: {d}\n";
pub const afs_free_cells = "    Free cells: {d}\n";
pub const afs_open_warning = "    Warning: Cannot open {s}: {}\n";
pub const afs_added_stack = "    Added stack: {s}/\n";
pub const afs_added_unit = "    Added unit: {s}\n";
