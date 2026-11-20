//! Native AHCI Diagnostic Refusals

pub const ProbeError = error{
    AhciBootVolumeMismatch,
    AhciBootVolumeMissing,
    AhciControllerMissing,
    AhciDiskMissing,
    AhciEngineDidNotStop,
    AhciPortBusy,
    AhciShortTransfer,
    AhciTransferFailed,
    AhciTransferTimeout,
    InvalidAhciBar,
    InvalidAhciMode,
    UnsupportedAhciController,
    UnsupportedAhciPort,
};
