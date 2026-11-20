//! Native AHCI Diagnostic Refusals

pub const ProbeError = error{
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
