//! AHCI Entry Symbol And Stack Shim

pub const ENTRY = ".extern ahci_main\ncallq ahci_main\nud2";
pub const SECTION = ".text.ahci.entry";
