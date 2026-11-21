//! AFS Entry Symbol And Stack Shim

pub const ENTRY = ".extern afs_main\ncallq afs_main\nud2";
pub const SECTION = ".text.afs.entry";
