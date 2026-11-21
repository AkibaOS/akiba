//! Native Boot Read Diagnostic Refusals

pub const WitnessError = error{
    AhciBootVolumeMissing,
    InvalidAhciMode,
    PulseProbeDidNotRun,
    UnexpectedBootUnit,
};
