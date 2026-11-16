//! Loopback QMP Peer Fixtures

pub const ADDRESS = "127.0.0.1";
pub const GREETING = "{\"QMP\":{}}\n";
pub const INVALID_GREETING = "{}\n";
pub const CAPABILITIES = "\"execute\":\"qmp_capabilities\"";
pub const REPLY = "{\"id\":1,\"return\":{}}\n";
pub const ERROR = "{\"id\":1,\"error\":{\"class\":\"GenericError\",\"desc\":\"fixture\"}}\n";
pub const EVENT = "{\"event\":\"RESET\"}\n";
pub const WRONG_ID = "{\"id\":99,\"return\":{}}\n";
pub const SLOW_BEGIN = "{";
pub const SLOW_BYTE = " ";
