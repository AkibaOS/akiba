//! Ordinary Pulse Activation Refusals

pub const PulseBootError = error{
    AfsDriverNotReady,
    AhciDriverNotReady,
    BootVolumeMissing,
    PulseDidNotEnterPersona,
    ServiceStartupFailed,
    WeaverNotReady,
};
