//! Writer Produced Library Test Locations

pub const SYSTEM = "source/system/libraries";
pub const INSTALLED = "source/libraries";
pub const LIBRARY_PATH = SYSTEM ++ "/linked.lib";
pub const SHADOW_PATH = INSTALLED ++ "/linked.lib";
pub const INSTALLED_ONLY = "author.lib";
pub const INSTALLED_ONLY_PATH = INSTALLED ++ "/" ++ INSTALLED_ONLY;
pub const DECOY = "not an ELF system library";
