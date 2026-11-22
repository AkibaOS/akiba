//! Hikari Resource Locations

const installed = @import("shared").location.strings.installed.paths;

pub const KERNEL_LOCATION = "/" ++ installed.MIRAI_PATH;
pub const DIAGNOSTIC_KERNEL_LOCATION = "/" ++ installed.DIAGNOSTIC_MIRAI_PATH;
