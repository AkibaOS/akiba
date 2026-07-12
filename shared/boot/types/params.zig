//! Boot Parameters

const acpi = @import("acpi.zig");
const framebuffer = @import("framebuffer.zig");
const kernel = @import("kernel.zig");
const memory = @import("memory.zig");

const constants = @import("../constants/constants.zig");

pub const BootParams = extern struct {
    Magic: u64,
    Version: u32,
    Size: u32,

    Framebuffer: framebuffer.FramebufferInfo,
    MemoryMap: memory.MemoryMapInfo,
    Kernel: kernel.KernelInfo,
    ACPI: acpi.ACPIInfo,
    BootTime: u64,

    Reserved: [constants.params.RESERVED_SIZE]u8,

    pub fn initialize() BootParams {
        var params: BootParams = undefined;
        params.Magic = constants.params.MAGIC;
        params.Version = constants.params.VERSION;
        params.Size = @sizeOf(BootParams);
        params.Reserved = [_]u8{0} ** constants.params.RESERVED_SIZE;
        return params;
    }

    pub fn isValid(self: *const BootParams) bool {
        return self.Magic == constants.params.MAGIC and
            self.Version == constants.params.VERSION and
            self.Size == @sizeOf(BootParams);
    }
};
