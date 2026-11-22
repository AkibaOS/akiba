//! Interpret The Bundle Type And Compatibility Vocabulary

const std = @import("std");

const schema = @import("shared").bundle.strings.schema;

const BinaryType = @import("shared").bundle.types.manifest.descriptor.BinaryType;
const Interface = @import("shared").bundle.types.manifest.descriptor.Interface;
const Kind = @import("shared").device.types.instance.Kind;

pub fn bundleType(text: []const u8) ?BinaryType {
    if (std.mem.eql(u8, text, schema.CLI)) return .Cli;
    if (std.mem.eql(u8, text, schema.GUI)) return .Gui;
    if (std.mem.eql(u8, text, schema.SERVICE)) return .Service;
    if (std.mem.eql(u8, text, schema.DRIVER)) return .Driver;
    return null;
}

pub fn interface(text: []const u8) ?Interface {
    if (std.mem.eql(u8, text, schema.KEYBOARD)) return .Keyboard;
    if (std.mem.eql(u8, text, schema.DISPLAY)) return .Display;
    if (std.mem.eql(u8, text, schema.BLOCK)) return .Block;
    return null;
}

pub fn hardware(text: []const u8) ?Kind {
    if (std.mem.eql(u8, text, schema.PS2_KEYBOARD)) return .Keyboard;
    if (std.mem.eql(u8, text, schema.FIRMWARE_FRAMEBUFFER)) return .Framebuffer;
    if (std.mem.eql(u8, text, schema.PCI_AHCI)) return .Ahci;
    return null;
}
