//! Native Display Scanout Witness Strings

pub const PRESENTED = "CHECK DISPLAY DRIVER PRESENTED";
pub const PRESENTED_LINE = PRESENTED ++ "\n";
pub const VERIFIED = "  PASS  Display driver scanout pixels\n";
pub const SCREENDUMP = "screendump";
pub const FILE = "display-proof.ppm";
pub const MAGIC = "P6";
