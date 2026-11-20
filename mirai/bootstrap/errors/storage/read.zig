//! Boot Transport And Unit Acquisition Errors

pub const StorageError = error{
    AhciBootVolumeMismatch,
    AhciEngineDidNotStop,
    AhciPortBusy,
    AhciShortTransfer,
    AhciTransferFailed,
    AhciTransferTimeout,
    BootDeviceChanged,
    BootUnitMissing,
    ImageTooLarge,
    InvalidSectorBuffer,
    UnsupportedAhciController,
    UnsupportedAhciPort,
};
