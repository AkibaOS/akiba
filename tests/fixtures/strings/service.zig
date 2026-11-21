//! Native Supervisor Service World And Identities

const weaver = @import("tests").fixtures.strings.weaver;

pub const IDENTITY = weaver.INSTALLED_IDENTITY;
pub const WORLD_UNIT = "pulse.world";
pub const WORLD_PATH = "system/world/" ++ WORLD_UNIT;
pub const WORLD =
    \\service "provider" binary="requestprobe" restart=1 { parameters "provider"; }
    \\service "consumer" binary="requestprobe" { after "provider"; parameters "consumer"; }
    \\service "early" binary="requestprobe" restart=1 required=false { parameters "fail"; }
    \\service "missing" binary="missingprobe" required=false
    \\service "silent" binary="requestprobe" required=false timeout=20 { parameters "silent"; }
    \\service "control" binary="requestprobe" control=true { parameters "controller"; }
;
pub const FAILURE = "fail";
pub const SILENT = "silent";
pub const CONTROLLER = "controller";
