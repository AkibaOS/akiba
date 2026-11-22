//! Installed Bundle Locations And Members

pub const Kind = enum { Binary, Driver };
pub const Scope = enum { SystemBinary, UserBinary, SystemDriver };
pub const Member = enum { Manifest, Binary };
