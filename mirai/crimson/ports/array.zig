//! Port Array (Per Exception Type)

const constants = @import("mirai").crimson.constants;
const types = @import("mirai").crimson.types;

const limits = constants.limits;

const ExceptionType = types.kind.ExceptionType;
const Port = types.port.Port;

pub const PortArray = struct {
    Ports: [limits.EXCEPTION_TYPE_COUNT]Port,

    pub fn init() PortArray {
        var array = PortArray{ .Ports = undefined };
        for (&array.Ports) |*port| port.clear();
        return array;
    }

    pub fn get(self: *PortArray, exception_type: ExceptionType) *Port {
        return &self.Ports[@intFromEnum(exception_type)];
    }

    pub fn getConst(self: *const PortArray, exception_type: ExceptionType) *const Port {
        return &self.Ports[@intFromEnum(exception_type)];
    }

    pub fn set(self: *PortArray, exception_type: ExceptionType, port: Port) void {
        self.Ports[@intFromEnum(exception_type)] = port;
    }

    pub fn clearAll(self: *PortArray) void {
        for (&self.Ports) |*port| port.clear();
    }

    pub fn hasPort(self: *const PortArray, exception_type: ExceptionType) bool {
        return self.getConst(exception_type).isValid();
    }
};
