//! Owned Root Bootstrap Errors

const common = @import("common");

pub const BootError = common.errors.memory.allocation.AllocationError || common.errors.memory.mapping.MappingError || error{
    InvalidBootInfo,
    InvalidImage,
    InvalidCPUState,
    UnsupportedCPU,
    BootstrapBusy,
    TableLedgerExhausted,
    StackLedgerExhausted,
};
