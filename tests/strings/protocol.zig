//! Loopback QMP Peer Fixtures

pub const ADDRESS = "127.0.0.1";
pub const GREETING = "{\"QMP\":{}}\n";
pub const INVALID_GREETING = "{}\n";
pub const CAPABILITIES = "\"execute\":\"qmp_capabilities\"";
pub const REPLY = "{\"id\":1,\"return\":{}}\n";
pub const ERROR = "{\"id\":1,\"error\":{\"class\":\"GenericError\",\"desc\":\"fixture\"}}\n";
pub const EVENT = "{\"event\":\"RESUME\"}\n";
pub const TERMINAL_EVENT = "{\"event\":\"RESET\"}\n";
pub const WRONG_ID = "{\"id\":99,\"return\":{}}\n";
pub const EMPTY = "";
pub const EXPECTED_NAME = "expected-owned-guest";
pub const QUERY_NAME = "\"execute\":\"query-name\"";
pub const WRONG_NAME = "{\"id\":2,\"return\":{\"name\":\"different-guest\"}}\n";
pub const SLOW_BEGIN = "{";
pub const SLOW_BYTE = " ";
pub const QUIT = "\"execute\":\"quit\"";
pub const QUIT_REFUSED = "{\"id\":2,\"error\":{\"class\":\"GenericError\",\"desc\":\"fixture\"}}\n";
pub const QUERY_JOBS = "query-jobs";
pub const JOB_REPLY_START = "{\"id\":2,";
pub const JOB_REPLY_END = "\"return\":[]}\n";
pub const QUERY_DISPLAY = "query-display-options";
pub const HEADLESS_REPLY = "{\"id\":2,\"return\":{\"type\":\"none\"}}\n";
pub const OPERATOR_CLOSED = "{\"event\":\"SHUTDOWN\",\"data\":{\"guest\":false,\"reason\":\"host-ui\"}}\n";
pub const OPERATOR_QUIT = "{\"event\":\"SHUTDOWN\",\"data\":{\"guest\":false,\"reason\":\"host-qmp-quit\"}}\n";
pub const RESET_TO_SHUTDOWN = "{\"event\":\"SHUTDOWN\",\"data\":{\"guest\":true,\"reason\":\"guest-reset\"}}\n";
