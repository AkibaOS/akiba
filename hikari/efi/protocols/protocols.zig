//! Hikari EFI Protocols

pub const simple_text_input = @import("input.zig");
pub const simple_text_output = @import("output.zig");
pub const graphics_output = @import("graphics.zig");
pub const unit = @import("unit.zig");
pub const simple_unit_system = @import("filesystem.zig");
pub const block_io = @import("block.zig");
pub const disk_io = @import("disk.zig");
pub const loaded_image = @import("image.zig");
pub const device_location = @import("path.zig");

pub const SimpleTextInputProtocol = simple_text_input.SimpleTextInputProtocol;
pub const SimpleTextOutputProtocol = simple_text_output.SimpleTextOutputProtocol;
pub const GraphicsOutputProtocol = graphics_output.GraphicsOutputProtocol;
pub const UnitProtocol = unit.UnitProtocol;
pub const SimpleUnitSystemProtocol = simple_unit_system.SimpleUnitSystemProtocol;
pub const BlockIoProtocol = block_io.BlockIoProtocol;
pub const DiskIoProtocol = disk_io.DiskIoProtocol;
pub const LoadedImageProtocol = loaded_image.LoadedImageProtocol;
pub const DeviceLocationProtocol = device_location.DeviceLocationProtocol;
