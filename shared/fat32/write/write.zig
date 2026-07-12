//! FAT32 Write Operations

pub const boot = @import("boot.zig");
pub const entry = @import("entry.zig");

pub const CreateParams = boot.CreateParams;
pub const calculate_fat_size = boot.calculate_fat_size;
pub const create_boot_sector = boot.create_boot_sector;
pub const create_fsinfo = boot.create_fsinfo;
pub const init_fat_table = boot.init_fat_table;
pub const allocate_cluster = boot.allocate_cluster;
pub const link_clusters = boot.link_clusters;

pub const create_entry = entry.create_entry;
pub const create_stack_entry = entry.create_stack_entry;
pub const create_dot_entry = entry.create_dot_entry;
pub const create_dotdot_entry = entry.create_dotdot_entry;
pub const create_unit_entry = entry.create_unit_entry;
pub const parse_identity = entry.parse_identity;
