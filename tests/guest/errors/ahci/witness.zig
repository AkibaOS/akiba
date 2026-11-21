//! Native Boot Read Diagnostic Refusals

pub const WitnessError = error{
    AhciBootVolumeMissing,
    InvalidAhciMode,
    PulseProbeDidNotRun,
    ServiceWorldMissing,
    ServiceStartupDeadline,
    ServiceStartupFailed,
    InvalidSupervisorReply,
    InvalidServiceReadiness,
    InvalidServiceFailure,
    InvalidServiceRecovery,
    InvalidServiceShutdown,
    SupervisorObserverNotBlocked,
    PulseExchangeDeadline,
    InstalledLaunchDeadline,
    SupervisorExerciseDeadline,
    UnexpectedBootUnit,
};
