//! Service Supervision And Private Pulse Control Letters

const wire = @import("sdk").persona.constants.postman;

pub const REPORT: u64 = 0x50554c530001;
pub const SNAPSHOT: u64 = 0x50554c530002;
pub const SHUTDOWN: u64 = 0x50554c530003;
pub const SERVICE_QUERY = wire.SERVICE_QUERY;
pub const SERVICE_READY = wire.SERVICE_READY;
pub const SERVICE_STOP = wire.SERVICE_STOP;
pub const SERVICE_STOPPED = wire.SERVICE_STOPPED;
pub const REFUSED = wire.REFUSED;
