//! Loopback QMP Peer Fixtures

pub const ADDRESS = "127.0.0.1";
pub const GREETING = "{\"QMP\":{}}\n";
pub const INVALID_GREETING = "{}\n";
pub const CAPABILITIES = "\"execute\":\"qmp_capabilities\"";
pub const REPLY = "{\"id\":1,\"return\":{}}\n";
pub const ERROR = "{\"id\":1,\"error\":{\"class\":\"GenericError\",\"desc\":\"fixture\"}}\n";
pub const EVENT = "{\"event\":\"RESET\"}\n";
pub const WRONG_ID = "{\"id\":99,\"return\":{}}\n";
pub const EMPTY = "";
pub const EXPECTED_NAME = "expected-owned-guest";
pub const QUERY_NAME = "\"execute\":\"query-name\"";
pub const WRONG_NAME = "{\"id\":2,\"return\":{\"name\":\"different-guest\"}}\n";
pub const SLOW_BEGIN = "{";
pub const SLOW_BYTE = " ";
