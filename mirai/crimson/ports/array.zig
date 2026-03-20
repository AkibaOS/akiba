//! Port Array (Per Exception Type)

const types = @import("../types/types.zig");
const constants = @import("../constants/constants.zig");
const Port = types.Port;
const ExceptionType = constants.ExceptionType;

pub const exception_type_count = 10;

pub const PortArray = struct {
    ports: [exception_type_count]Port,
    pub fn init() PortArray { var a = PortArray{ .ports = undefined }; for (&a.ports) |*p| p.clear(); return a; }
    pub fn get(self: *PortArray, t: ExceptionType) *Port { return &self.ports[@intFromEnum(t)]; }
    pub fn get_const(self: *const PortArray, t: ExceptionType) *const Port { return &self.ports[@intFromEnum(t)]; }
    pub fn set(self: *PortArray, t: ExceptionType, port: Port) void { self.ports[@intFromEnum(t)] = port; }
    pub fn clear_all(self: *PortArray) void { for (&self.ports) |*p| p.clear(); }
    pub fn has_port(self: *const PortArray, t: ExceptionType) bool { return self.get_const(t).is_valid(); }
};
