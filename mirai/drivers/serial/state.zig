//! Serial Availability State

const ports = @import("common").constants.serial.ports;

var current_port: u16 = ports.DEFAULT_PORT;
var available: bool = false;

pub fn getPort() u16 {
    return current_port;
}

pub fn selectPort(port: u16) void {
    if (current_port != port) available = false;
    current_port = port;
}

pub fn isAvailable() bool {
    return available;
}

pub fn setAvailable(value: bool) void {
    available = value;
}
