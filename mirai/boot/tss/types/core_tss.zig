//! Per-Core TSS

const Tss = @import("tss.zig").Tss;
const constants = @import("../constants/constants.zig");

pub const CoreTss = struct {
    tss: Tss,
    core_id: u16,
    kernel_stack_base: u64,
    kernel_stack_top: u64,
    ist_stacks: [7]IstStack,

    pub const IstStack = struct {
        base: u64,
        top: u64,
        size: u64,
    };

    pub fn init(core_id: u16) CoreTss {
        return CoreTss{
            .tss = Tss{},
            .core_id = core_id,
            .kernel_stack_base = 0,
            .kernel_stack_top = 0,
            .ist_stacks = [_]IstStack{.{ .base = 0, .top = 0, .size = 0 }} ** 7,
        };
    }

    pub fn set_kernel_stack(self: *CoreTss, base: u64, size: u64) void {
        self.kernel_stack_base = base;
        self.kernel_stack_top = base + size;
        self.tss.set_rsp0(self.kernel_stack_top);
    }

    pub fn set_ist_stack(self: *CoreTss, index: u8, base: u64, size: u64) void {
        if (index < 1 or index > 7) return;
        const ist_index = index - 1;
        self.ist_stacks[ist_index] = .{
            .base = base,
            .top = base + size,
            .size = size,
        };
        self.tss.set_ist(index, base + size);
    }

    pub fn get_tss(self: *CoreTss) *Tss {
        return &self.tss;
    }

    pub fn get_tss_address(self: *const CoreTss) u64 {
        return @intFromPtr(&self.tss);
    }
};
