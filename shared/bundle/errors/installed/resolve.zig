//! Installed Bundle Resolution Refusals

const ManifestError = @import("shared").bundle.errors.manifest.schema.ManifestError;
const ReadError = @import("shared").bundle.errors.installed.reader.ReadError;

pub const ResolveError = ManifestError || ReadError || error{
    InvalidIdentity,
    MissingManifest,
    MissingBinary,
    TypeMismatch,
    WrongBundleKind,
    InvalidExecutable,
};

pub const CatalogError = ResolveError || error{ InvalidCatalog, CatalogTooLarge };
