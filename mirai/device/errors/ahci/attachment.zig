//! AHCI Attachment Refusals

pub const AttachmentError = error{
    AhciPortBusy,
    BootDeviceChanged,
    UnsupportedAhciController,
    UnsupportedAhciPort,
};
