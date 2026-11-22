//! Explicit Host Storage Regression Entry

const std = @import("std");

const afs = @import("tests").fast.afs;
const ahci = @import("tests").fast.ahci.discover;
const boot = @import("tests").fast.boot;
const fat32 = @import("tests").fast.fat32;
const gpt = @import("tests").fast.gpt.inspect;
const ports = @import("tests").fast.ahci.port;
const sectors = @import("tests").fast.gpt.source;
const shared = @import("shared");

test "installed bundle and init paths use exact distinct namespaces" {
    try boot.installation.names();
}

test "installed logical identities cannot alias deployed filenames or paths" {
    try boot.installation.rejectsAliases();
}

test "AHCI builds a single read DMA descriptor without a write flag" {
    var page: [4096]u8 = undefined;
    try shared.ahci.command.encode.prepare(&page, 0x100000, .{ .Read = 0x123456789abc });
    try std.testing.expectEqual(@as(u32, 0x00010005), std.mem.readInt(u32, page[0..4], .little));
    try std.testing.expectEqual(@as(u32, 0x100500), std.mem.readInt(u32, page[8..12], .little));
    try std.testing.expectEqualSlices(u8, &.{ 0x27, 0x80, 0x25, 0, 0xbc, 0x9a, 0x78, 0x40, 0x56, 0x34, 0x12, 0, 1, 0 }, page[0x500..0x50e]);
    try std.testing.expectEqual(@as(u32, 0x100800), std.mem.readInt(u32, page[0x580..0x584], .little));
    try std.testing.expectEqual(@as(u32, 511), std.mem.readInt(u32, page[0x58c..0x590], .little));
    try std.testing.expectError(error.InvalidDmaPage, shared.ahci.command.encode.prepare(&page, 0x100001, .Identify));
    try std.testing.expectError(error.InvalidDmaPage, shared.ahci.command.encode.prepare(&page, 0x100000000, .Identify));
    try std.testing.expectError(error.InvalidSector, shared.ahci.command.encode.prepare(&page, 0x100000, .{ .Read = 0x1000000000000 }));
}

test "AHCI accepts only an identified 512 byte LBA48 disk" {
    var identity: [512]u8 = @splat(0);
    try std.testing.expectError(error.UnsupportedDisk, shared.ahci.command.identify.capacity(&identity));
    std.mem.writeInt(u16, identity[166..168], 0x4400, .little);
    std.mem.writeInt(u64, identity[200..208], 0x20000, .little);
    try std.testing.expectEqual(@as(u64, 0x20000), try shared.ahci.command.identify.capacity(&identity));
    std.mem.writeInt(u16, identity[212..214], 0x5000, .little);
    try std.testing.expectError(error.UnsupportedSectorSize, shared.ahci.command.identify.capacity(&identity));
}

test "AHCI discovery follows PCI class across buses and valid multifunction slots" {
    try ahci.discoversFunctions();
}

test "AHCI discovery refuses unconfigured and unsupported PCI apertures" {
    try ahci.refusesResources();
}

test "AHCI distinguishes a ready ATA disk from a known packet device" {
    try ports.knownKinds();
}

test "AHCI needs initial FIS reception only for an active linked port with the reset signature" {
    try ports.initialSignature();
}

test "AHCI keeps present but unready or unknown ports unverifiable" {
    try ports.unverifiable();
}

test "AHCI selection refuses a duplicate or a later unverifiable candidate" {
    try ahci.selectsUniquely();
}

test "AHCI reopen rechecks the selected function without falling through to another" {
    try ahci.reinspectsExactly();
}

test "AFS sector-backed cells read exactly the selected partition window" {
    try afs.sectors.exactWindow();
}

test "AFS sector-backed cells reject invalid geometry and partial cells" {
    try afs.sectors.rejectsInvalidGeometry();
}

test "AFS sector-backed cells propagate a failed late sector" {
    try afs.sectors.lateReadFailure();
}

test "GPT verifies the handed-off AFS identity beyond table padding" {
    try gpt.exactVolume();
}

test "GPT does not match a different disk, partition type, or span" {
    try gpt.unrelatedVolume();
}

test "GPT refuses corrupt checksums and truncated partition bytes" {
    try gpt.corruptedData();
}

test "GPT bounds the header and partition read window before use" {
    try gpt.invalidLayout();
}

test "GPT refuses duplicate nonempty partition identities" {
    try gpt.ambiguousIdentity();
}

test "GPT discovers one complete AFS partition and refuses ambiguity or a bad table" {
    try sectors.discoversVolume();
}

test "GPT gathers a selected partition entry across sector boundaries" {
    try sectors.splitEntry();
}

test "GPT does not read the array after rejected geometry or header identity" {
    try sectors.headerRefusal();
}

test "GPT waits for every sector and the full CRC before accepting a candidate" {
    try sectors.lateRefusal();
}

test "GPT recognizes duplicate identities when the second entry straddles sectors" {
    try sectors.duplicateEntry();
}

test "AFS spans fit entirely inside the volume" {
    try afs.bounds.spanBounds();
}

test "AFS span checks reject overflowing ends" {
    try afs.bounds.spanOverflow();
}

test "AFS cell LBAs honor inclusive endpoints" {
    try afs.bounds.inclusiveEndpoints();
}

test "AFS cell LBAs reject invalid geometry" {
    try afs.bounds.invalidGeometry();
}

test "AFS cell reads reject truncation" {
    try afs.bounds.truncatedReads();
}

test "AFS cell LBAs guard large offsets" {
    try afs.bounds.largeOffsets();
}

test "AFS headers validate signature and version" {
    try afs.bounds.signatureAndVersion();
}

test "AFS header cell sizes respect supported boundaries" {
    try afs.bounds.cellSizeBoundaries();
}

test "AFS single cell callbacks receive exactly one cell" {
    try afs.block.singleCellCallbacks();
}

test "AFS multiple cell callbacks preserve order and bytes" {
    try afs.block.multiCellCallbacks();
}

test "AFS block requests reject invalid ranges before callbacks" {
    try afs.block.rejectedRequests();
}

test "AFS empty block requests honor the volume endpoint" {
    try afs.block.emptyRequests();
}

test "AFS block reads propagate one callback failure and stop" {
    try afs.block.readFailureStopsTransfers();
}

test "AFS block writes retain only transfers preceding a failure" {
    try afs.block.writeFailureStopsTransfers();
}

test "AFS span reads bound exact and partial destination copies" {
    try afs.read.exactAndPartialSpans();
}

test "AFS span reads validate scratch space and span arithmetic" {
    try afs.read.rejectedSpanReads();
}

test "AFS fragmented unit reads follow data spans and logical size" {
    try afs.read.fragmentedUnitReads();
}

test "AFS ranged reads cross fragmented spans and stop at the logical Unit end" {
    try afs.read.fragmentedRanges();
}

test "AFS inline reads return partial data but complete units reject gaps" {
    try afs.read.incompleteInlineChannels();
}

test "AFS channel reads reject inconsistent sizes and spans" {
    try afs.read.rejectedChannelReads();
}

test "AFS inline spans account for previously consumed cells" {
    try afs.read.cumulativeSpanAccounting();
}

test "AFS empty unit reads perform no block transfers" {
    try afs.read.emptyUnitReads();
}

test "AFS span reads translate callback failures without later copies" {
    try afs.read.readFailureTranslation();
}

test "AFS span writes truncate source data at the span boundary" {
    try afs.write.exactAndTruncatedWrites();
}

test "AFS partial writes zero only the final written cell padding" {
    try afs.write.partialCellPadding();
}

test "AFS fragmented span writes match independent bytes and roundtrip" {
    try afs.write.fragmentedWriteRoundtrip();
}

test "AFS empty span writes preserve disk and scratch bytes" {
    try afs.write.emptyWrites();
}

test "AFS span writes translate callback failures after committed cells" {
    try afs.write.writeFailureTranslation();
}

test "AFS spans and channel constructors preserve physical accounting" {
    try afs.catalog.spanAndChannelConstruction();
}

test "AFS cell counts round up exact and partial cells" {
    try afs.catalog.roundedCellCounts();
}

test "AFS stack constructors initialize catalog metadata" {
    try afs.catalog.stackConstruction();
}

test "AFS unit constructors preserve channels and initialize metadata" {
    try afs.catalog.unitConstruction();
}

test "AFS catalog keys widen input bytes within the supported identity bound" {
    try afs.catalog.indexKeyConstruction();
}

test "AFS tree nodes locate cells and independently encoded record offsets" {
    try afs.tree.nodeGeometryAndRecords();
}

test "AFS tree descriptors distinguish each existing node kind" {
    try afs.tree.nodeKinds();
}

test "AFS catalog validation accepts independently encoded nodes" {
    try afs.tree.independentlyEncodedNodes();
}

test "AFS catalog validation rejects malformed descriptors" {
    try afs.tree.malformedDescriptors();
}

test "AFS catalog validation rejects overlapping and outside record offsets" {
    try afs.tree.malformedOffsets();
}

test "AFS catalog validation rejects malformed keys and missing index children" {
    try afs.tree.malformedKeys();
}

test "AFS catalog validation rejects truncated and unknown record payloads" {
    try afs.tree.malformedPayloads();
}

test "AFS catalog key ordering compares parents then case sensitive code units" {
    try afs.tree.keyOrdering();
}

test "AFS leaf lookup distinguishes stacks units and both thread types" {
    try afs.tree.leafLookup();
}

test "AFS index lookup uses the existing ceiling and last child semantics" {
    try afs.tree.indexLookup();
}

test "AFS allocation bitmap sizing includes partial bytes" {
    try afs.allocation.bitmapByteCounts();
}

test "AFS bitmap accounting excludes padding and bounds mutations" {
    try afs.allocation.boundedBitmapMutations();
}

test "AFS bump allocation advances monotonically and accounts for exhaustion" {
    try afs.allocation.bumpAllocatorAccounting();
}

test "FAT32 cluster helpers preserve masking and existing marker semantics" {
    try fat32.cluster.classificationAndParsing();
}

test "FAT32 cluster positions and addresses cross sector boundaries" {
    try fat32.cluster.positionsAndAddresses();
}

test "FAT32 boot construction produces independent metadata bytes" {
    try fat32.boot.bootConstruction();
}

test "FAT32 boot geometry and FAT sizing honor existing rounding" {
    try fat32.boot.geometryAndFatSizing();
}

test "FAT32 boot validation enforces only its existing header conditions" {
    try fat32.boot.bootValidation();
}

test "FAT32 FSInfo construction encodes hints and validates every signature" {
    try fat32.boot.fsInfoConstructionAndValidation();
}

test "FAT32 entry construction uppercases truncates and packs cluster words" {
    try fat32.entry.entryConstructionBytes();
}

test "FAT32 entries expose markers attributes and complete cluster words" {
    try fat32.entry.markersAttributesAndClusters();
}

test "FAT32 specialized constructors create stacks dots and units" {
    try fat32.entry.specializedEntries();
}

test "FAT32 short identities preserve existing trimming and lead byte semantics" {
    try fat32.identity.shortIdentityExtraction();
}

test "FAT32 short identity matching is case insensitive and length exact" {
    try fat32.identity.shortIdentityMatching();
}

test "FAT32 identity parsing separates the last dot without normalization" {
    try fat32.identity.lastDotParsing();
}

test "FAT32 LFN extraction preserves all thirteen little endian code units" {
    try fat32.identity.longIdentityCodeUnits();
}

test "FAT32 table initialization writes reserved entries and clears the rest" {
    try fat32.table.initializedTableBytes();
}

test "FAT32 table links preserve exact values and bounded neighboring bytes" {
    try fat32.table.allocationAndLinks();
}

test "BootParams copies the GPT identity and geometry as a fixed record" {
    try boot.volume.copiedRecord();
}

test "The boot volume record refuses invalid identity and geometry" {
    try boot.volume.invalidIdentityAndGeometry();
}

test "Pulse installs as one extensionless Unit under the system Akiba Stack" {
    try boot.pulse.standalone();
}

test "Pulse carries the exact raw Weaver bytes in one read-only load segment" {
    try boot.embedded.exactPayload();
}

test "Pulse refuses missing, ambiguous, writable, zero-filled and truncated bootstrap payloads" {
    try boot.embedded.rejectedPayloads();
}

test "Pulse requires every Weaver payload page to be exclusive to its load segment" {
    try boot.embedded.exclusivePages();
}

test "Boot transport recognizes only the complete terminal SATA path" {
    try boot.transport.completePaths();
}

test "Boot transport refuses malformed and incomplete firmware paths" {
    try boot.transport.malformedPaths();
}

test "BootParams retain the transport tag independently of an optional volume identity" {
    try boot.transport.wireTag();
}

test "BootParams initialization stamps the header and zeroes the handoff" {
    try boot.params.initializedHandoff();
}

test "BootParams validation rejects corrupted magic and versions" {
    try boot.params.corruptedMagicAndVersion();
}

test "BootParams validation rejects zero and mismatched structure sizes" {
    try boot.params.corruptedSize();
}
