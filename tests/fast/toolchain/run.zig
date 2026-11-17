//! Native Toolchain Image Integration Test Root

const image = @import("tests").fast.toolchain.image;

test "mkafsdisk creates reciprocal GPT FAT boot files and readable AFS units in one temporary image" {
    try image.integration.createAndReadback();
}

test "AFS volume bitmap planning covers the former four cell boundary" {
    try image.planning.bitmapCoverageBoundary();
}

test "AFS volume planning reserves metadata before accepting payload" {
    try image.planning.metadataAndPayloadMustFit();
}

test "AFS planned payload spans preserve metadata empty files and frozen capacity" {
    try image.planning.spansAreAssignedInsideTheFrozenPayloadPlan();
}

test "AFS volume planning rejects unrepresentable fields without wrapping" {
    try image.planning.unrepresentablePlansAreRejected();
}

test "AFS disk planning preserves wide GPT geometry and saturates protective MBR counts" {
    try image.planning.wideDiskGeometryAndProtectiveSaturation();
}

test "AFS disk planning places reciprocal GPT headers and complete cell boundaries" {
    try image.planning.reciprocalGptLocations();
}

test "AFS disk planning rejects too small and unrepresentable images" {
    try image.planning.unsupportedDiskGeometryIsRejected();
}

test "AFS manifest preserves the origin for an empty source" {
    try image.manifest.emptySourceRetainsOrigin();
}

test "AFS manifest IDs and catalog entries do not depend on host creation order" {
    try image.manifest.creationOrderDoesNotDetermineObjectIds();
}

test "AFS manifest collection rejects a missing source instead of silently succeeding" {
    try image.manifest.missingSourceFailsInsteadOfProducingOriginOnly();
}

test "AFS manifest identity and count exhaustion preserve existing counters" {
    try image.manifest.identityAndCountExhaustionPreserveCounters();
}

test "AFS node packing checks complete record and backwards offset table space" {
    try image.catalog.recordPackingRejectsOffsetCollisions();
}

test "AFS node packing accepts an exact fill and splits the following record" {
    try image.catalog.exactNodeFillSplitsOnlyTheNextRecord();
}

test "AFS bulk nodes encode maximum keys header counts and padding in current wire layout" {
    try image.catalog.maximumKeyAndHeaderUseIndependentWireBytes();
}

test "AFS bulk catalog sorts parent case and prefix keys without cross parent lookup" {
    try image.catalog.globalOrderingAndParentIsolation();
}

test "AFS bulk catalog rejects duplicate keys invalid names and excessive sizes" {
    try image.catalog.duplicateAndInvalidCatalogEntriesAreRejected();
}

test "AFS bulk catalog traverses three levels using production maximum key search" {
    try image.catalog.multiLevelMaximumKeyRoutingAndLinks();
}

test "AFS bulk catalog redistributes a final unary internal group" {
    try image.catalog.finalInternalGroupDoesNotRemainUnary();
}

test "AFS bulk catalog preserves byte widened rather than Unicode decoded identities" {
    try image.catalog.identityBytesAreWidenedWithoutUnicodeDecoding();
}

test "AFS allocation map rejects backing that cannot represent its volume" {
    try image.checked.bitmapBackingMustCoverEveryCell();
}

test "AFS allocation map rejects invalid initial cursors without touching backing" {
    try image.checked.invalidInitialCursorDoesNotTouchBacking();
}

test "AFS allocation reservation refuses whole invalid ranges before mutating bits" {
    try image.checked.invalidReservationIsRejectedBeforeAnyBitChanges();
}

test "AFS allocation refuses corrupt cursors and wrapped demand without mutation" {
    try image.checked.allocationRejectsCorruptCursorAndWrappedDemand();
}

test "AFS bump allocation refuses an occupied cursor without searching or changing ownership" {
    try image.checked.occupiedBumpCursorDoesNotAliasAnAllocation();
}

test "AFS bump allocation refuses an occupied interior before claiming a free prefix" {
    try image.checked.occupiedInteriorDoesNotPartiallyClaimAFreePrefix();
}

test "AFS allocation backing reaches the final cell beyond the old bitmap boundary" {
    try image.checked.formerBitmapBoundarySupportsTheLastValidBit();
}

test "AFS key size construction rejects unrepresentable names before arithmetic" {
    try image.checked.keySizeRejectsUnrepresentableNamesBeforeArithmetic();
}

test "AFS key construction rejects unaddressable and oversized identities" {
    try image.checked.keyConstructorRejectsNamesInsteadOfTruncating();
}

test "AFS cell count construction rejects zero geometry and narrowing overflow" {
    try image.checked.cellCountsRejectZeroGeometryAndNarrowingOverflow();
}

test "AFS channel construction rejects impossible sizes and span overflow" {
    try image.checked.channelsRejectImpossibleSizesAndSpanOverflow();
}

test "AFS checked constructors preserve representable endpoints and byte identities" {
    try image.checked.representableConstructorEndpointsRemainSupported();
}

test "AFS active writer emits multiple leaves consumed by production shared search" {
    try image.emission.moderateCatalogIsReadThroughProductionSearch();
}

test "AFS active writer emits complete allocation coverage beyond the former bitmap threshold" {
    try image.emission.emittedBitmapCoversCellsPastTheFormerThreshold();
}

test "AFS failed construction preserves the existing final image bytes" {
    try image.publication.insufficientSpacePreservesExistingFinalBytes();
}

test "AFS failed construction never publishes a previously absent final image" {
    try image.publication.insufficientSpaceDoesNotPublishAnAbsentFinal();
}

test "AFS missing source fails without replacing an existing final image" {
    try image.publication.missingSourceIsFailureWithoutReplacingFinalBytes();
}

test "AFS missing bootloader fails without replacing an existing final image" {
    try image.publication.missingBootloaderIsFailureWithoutReplacingFinalBytes();
}

test "AFS successful replacement supports native spaced and wide host paths" {
    try image.emission.nativeSpacedAndWideHostPathsRemainSupported();
}
