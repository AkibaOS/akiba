//! Typed Native Device Operations

pub const Operation = enum(u64) { Lease, StreamProbe, StreamNext, SurfaceDescribe, SurfaceRow };
