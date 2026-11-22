//! Exact Malformed Bundle Shapes For Writer Produced AFS

pub const WRONG_SCOPE_ID = "driver-in-binaries";
pub const WRONG_SCOPE = "source/system/binaries/driver-in-binaries.akiba";
pub const WRONG_SCOPE_MANIFEST = WRONG_SCOPE ++ "/bundle.world";
pub const WRONG_SCOPE_BINARY = WRONG_SCOPE ++ "/binary";
pub const MANIFEST_STACK_ID = "manifest-stack";
pub const MANIFEST_STACK = "source/system/binaries/manifest-stack.akiba";
pub const MANIFEST_STACK_MEMBER = MANIFEST_STACK ++ "/bundle.world";
pub const MANIFEST_STACK_BINARY = MANIFEST_STACK ++ "/binary";
pub const BINARY_STACK_ID = "binary-stack";
pub const BINARY_STACK = "source/system/binaries/binary-stack.akiba";
pub const BINARY_STACK_MEMBER = BINARY_STACK ++ "/binary";
pub const BINARY_STACK_MANIFEST = BINARY_STACK ++ "/bundle.world";
pub const OVERSIZED_ID = "large-manifest";
pub const OVERSIZED = "source/system/binaries/large-manifest.akiba";
pub const OVERSIZED_MANIFEST = OVERSIZED ++ "/bundle.world";
pub const OVERSIZED_BYTES = [_]u8{' '} ** 4097;
pub const RESERVED_DIRECTORY = "source/binaries";
pub const EMPTY_UNIT = "entry-{d}";
pub const NONCANONICAL = "Schema-check";
pub const ALIASED = "schema-check.akiba";
