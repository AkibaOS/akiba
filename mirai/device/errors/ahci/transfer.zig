//! AHCI Transfer Refusals

pub const TransferError = error{
    AhciEngineDidNotStop,
    AhciPortBusy,
    AhciShortTransfer,
    AhciTransferFailed,
    AhciTransferTimeout,
    InvalidSectorBuffer,
};
