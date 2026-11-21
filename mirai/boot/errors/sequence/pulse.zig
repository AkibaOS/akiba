//! Ordinary Pulse Activation Refusals

pub const PulseBootError = error{
    AhciDriverNotReady,
    BootVolumeMissing,
    PulseDidNotEnterPersona,
    WeaverNotReady,
};
