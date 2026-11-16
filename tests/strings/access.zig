//! Persona Hardware Access Probe Labels

pub const GROUP = "CHECK GROUP Hardware access faults\n";
pub const WRITE = "Persona write to owned read-only data faults with exact page-fault details";
pub const EXECUTE = "Persona instruction fetch from owned NX data faults with exact page-fault details";
pub const SUPERVISOR = "Persona read of mapped supervisor text faults without exposing kernel bytes";
