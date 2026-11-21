//! Pointer Free Boot Transport Fact

const std = @import("std");

pub const Transport = enum(u32) {
    Unknown = 0,
    Sata = 1,
    Other = 2,

    pub fn fromWire(value: u32) ?Transport {
        return std.enums.fromInt(Transport, value);
    }
};
