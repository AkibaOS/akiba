//! Native AHCI Diagnostic Refusals

pub const ProbeError = error{
    AhciBootVolumeMismatch,
    AhciBootVolumeMissing,
    AhciEngineDidNotStop,
    AhciPortBusy,
    AhciShortTransfer,
    AhciTransferFailed,
    AhciTransferTimeout,
    InvalidAhciMode,
    UnsupportedAhciController,
    UnsupportedAhciPort,
};
