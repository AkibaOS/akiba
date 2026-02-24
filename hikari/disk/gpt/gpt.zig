//! Hikari GPT (GUID Partition Table)

pub const constants = @import("constants.zig");
pub const types = @import("types.zig");
pub const parser = @import("parser.zig");

pub const Header = types.Header;
pub const PartitionEntry = types.PartitionEntry;
pub const PartitionAttributes = types.PartitionAttributes;
pub const ProtectiveMbr = types.ProtectiveMbr;
pub const MbrPartitionRecord = types.MbrPartitionRecord;

pub const Parser = parser.Parser;
pub const ParseError = parser.ParseError;
pub const calculate_crc32 = parser.calculate_crc32;
