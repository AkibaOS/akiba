//! First Kata Bootstrap Refusals

pub const PulseError = error{
    BootDiskHandoffRefused,
    DesignationRefused,
    KernelOwnerMissing,
    NotFirstKata,
};
