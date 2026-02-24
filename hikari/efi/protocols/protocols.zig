//! Hikari EFI Protocols

pub const simple_text_input = @import("simple_text_input.zig");
pub const simple_text_output = @import("simple_text_output.zig");
pub const graphics_output = @import("graphics_output.zig");
pub const file = @import("file.zig");
pub const simple_file_system = @import("simple_file_system.zig");
pub const block_io = @import("block_io.zig");
pub const disk_io = @import("disk_io.zig");
pub const loaded_image = @import("loaded_image.zig");
pub const device_path = @import("device_path.zig");

pub const SimpleTextInputProtocol = simple_text_input.SimpleTextInputProtocol;
pub const SimpleTextOutputProtocol = simple_text_output.SimpleTextOutputProtocol;
pub const GraphicsOutputProtocol = graphics_output.GraphicsOutputProtocol;
pub const FileProtocol = file.FileProtocol;
pub const SimpleFileSystemProtocol = simple_file_system.SimpleFileSystemProtocol;
pub const BlockIoProtocol = block_io.BlockIoProtocol;
pub const DiskIoProtocol = disk_io.DiskIoProtocol;
pub const LoadedImageProtocol = loaded_image.LoadedImageProtocol;
pub const DevicePathProtocol = device_path.DevicePathProtocol;
