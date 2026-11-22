//! Owned Binary Type And Compatibility Facts

const std = @import("std");

const Kind = @import("shared").device.types.instance.Kind;

pub const BinaryType = enum { Cli, Gui, Service, Driver };
pub const Interface = enum { Keyboard, Display, Block };

pub const Descriptor = struct {
    Type: BinaryType,
    Provides: std.EnumArray(Interface, ?u64) = .initFill(null),
    Matches: std.EnumSet(Kind) = .initEmpty(),
};
