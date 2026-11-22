//! Persona Build Declaration Messages

pub const INVALID_ORDER = "Persona declarations must be unique and follow dependency order";
pub const DUPLICATE_INSTALL = "Persona declarations must not share an installed destination";
pub const OUT_OF_MEMORY = "Build artifact declarations ran out of memory";
pub const DESCRIPTION = "Build and install the declared Persona binaries";
pub const INSTALL = "Install {s}";
pub const MANIFEST_LINE = "{s}\n";
pub const INVALID_PATH = "Installed artifacts require canonical relative locations";
pub const FORBIDDEN_PATH_BYTES = "\\:\x00\r\n";
