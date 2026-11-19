//! Independently Linked EFI Applications For The Test Image

const std = @import("std");

pub const Applications = struct {
    Diagnostic: *std.Build.Step.Compile,
    Firmware: *std.Build.Step.Compile,
    Menu: *std.Build.Step.Compile,
    Ordinary: *std.Build.Step.Compile,
};
