//! Ordinary Pulse Activation Refusals

pub const PulseBootError = error{
    BootVolumeMissing,
    PulseDidNotEnterPersona,
};
