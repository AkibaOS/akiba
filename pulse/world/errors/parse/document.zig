//! World Configuration Refusals

pub const WorldError = error{ OutOfMemory, InvalidWorld, DuplicateService, MissingDependency, DependencyCycle };
