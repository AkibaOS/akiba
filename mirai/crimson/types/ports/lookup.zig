//! Exception Port Lookup Result

const Port = @import("mirai").crimson.types.port.Port;

pub const LookupResult = struct {
    Port: *const Port,
    Found: bool,
};
