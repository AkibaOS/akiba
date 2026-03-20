//! Crimson Constants

pub const types = @import("types.zig");
pub const codes = @import("codes.zig");
pub const vectors = @import("vectors.zig");
pub const behaviors = @import("behaviors.zig");
pub const flavors = @import("flavors.zig");

pub const ExceptionType = types.ExceptionType;
pub const Behavior = behaviors.Behavior;
pub const Action = behaviors.Action;
pub const Flavor = flavors.Flavor;
pub const Vector = vectors.Vector;

pub const BreachCode = codes.BreachCode;
pub const ForbiddenCode = codes.ForbiddenCode;
pub const OverflowCode = codes.OverflowCode;
pub const ShatterCode = codes.ShatterCode;
pub const MissingCode = codes.MissingCode;
pub const CriticalCode = codes.CriticalCode;
pub const SoftwareCode = codes.SoftwareCode;
pub const ResourceCode = codes.ResourceCode;
pub const GuardCode = codes.GuardCode;
pub const CollapseCode = codes.CollapseCode;
