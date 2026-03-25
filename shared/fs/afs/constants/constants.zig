//! AFS Constants

pub const magic = @import("magic.zig");
pub const sizes = @import("sizes.zig");
pub const nodes = @import("nodes.zig");
pub const records = @import("records.zig");
pub const btree = @import("btree.zig");
pub const flags = @import("flags.zig");

// Re-export commonly used constants
pub const signature = magic.signature;
pub const version = magic.version;
pub const journal_signature = magic.journal_signature;
pub const partition_type_guid = magic.partition_type_guid;

pub const default_cell_size = sizes.default_cell_size;
pub const minimum_cell_size = sizes.minimum_cell_size;
pub const maximum_cell_size = sizes.maximum_cell_size;
pub const max_identity_length = sizes.max_identity_length;
pub const span_inline_count = sizes.span_inline_count;

pub const first_user_node_id = nodes.first_user;
