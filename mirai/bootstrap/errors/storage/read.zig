//! Boot Transport And Unit Acquisition Errors

pub const StorageError = error{
    AhciBootVolumeMismatch,
    BootDeviceChanged,
    BootUnitMissing,
    ImageTooLarge,
};
