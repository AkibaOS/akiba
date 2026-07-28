//! Per-Core TSS

const constants = @import("mirai").boot.constants;
const structure = @import("mirai").boot.types.tss.structure;

const limits = constants.tss.limits;

const TSS = structure.TSS;

pub const ISTStack = struct {
    Base: u64,
    Top: u64,
    Size: u64,
};

pub const CoreTSS = struct {
    TSS: TSS,
    CoreId: u16,
    KernelStackBase: u64,
    KernelStackTop: u64,
    ISTStacks: [limits.IST_COUNT]ISTStack,

    pub fn init(core_id: u16) CoreTSS {
        return CoreTSS{
            .TSS = TSS{},
            .CoreId = core_id,
            .KernelStackBase = 0,
            .KernelStackTop = 0,
            .ISTStacks = [_]ISTStack{.{ .Base = 0, .Top = 0, .Size = 0 }} ** limits.IST_COUNT,
        };
    }

    pub fn setKernelStack(self: *CoreTSS, base: u64, size: u64) void {
        self.KernelStackBase = base;
        self.KernelStackTop = base + size;
        self.TSS.setRSP0(self.KernelStackTop);
    }

    pub fn setISTStack(self: *CoreTSS, index: u8, base: u64, size: u64) void {
        if (index < 1 or index > limits.IST_COUNT) return;
        const ist_index = index - 1;
        self.ISTStacks[ist_index] = .{
            .Base = base,
            .Top = base + size,
            .Size = size,
        };
        self.TSS.setIST(index, base + size);
    }

    pub fn getTSS(self: *CoreTSS) *TSS {
        return &self.TSS;
    }

    pub fn getTSSAddress(self: *const CoreTSS) u64 {
        return @intFromPtr(&self.TSS);
    }
};
