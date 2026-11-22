//! Foundation Native Test Entry

const checks = @import("tests").fast.foundation;

test "paging indices isolate address bit fields" {
    try checks.address.pagingIndices();
}

test "page conversions discard only page offsets" {
    try checks.address.pageConversionBoundaries();
}

test "page numbers and aligned addresses round trip" {
    try checks.address.pageRoundTrips();
}

test "physical map address arithmetic round trips without dereferencing" {
    try checks.address.physicalMapRoundTrips();
}

test "ASCII uppercase changes only lowercase Latin bytes" {
    try checks.ascii.uppercaseBoundaries();
}

test "ASCII case insensitive equality preserves lengths and other bytes" {
    try checks.ascii.caseInsensitiveEquality();
}

test "bounded ASCII copy leaves short source tails and guards untouched" {
    try checks.ascii.copyShortSource();
}

test "bounded ASCII copy handles exact spans truncation and embedded zeroes" {
    try checks.ascii.copyExactAndTruncated();
}

test "bounded ASCII copy leaves empty spans untouched" {
    try checks.ascii.copyEmptySpans();
}

test "ASCII widening leaves short source tails and guards untouched" {
    try checks.ascii.widenShortSource();
}

test "ASCII widening handles exact spans truncation and embedded zeroes" {
    try checks.ascii.widenExactAndTruncated();
}

test "ASCII widening leaves empty spans untouched" {
    try checks.ascii.widenEmptySpans();
}

test "bitmap byte counts round up non-byte-aligned lengths" {
    try checks.bits.bitmapByteCounts();
}

test "individual bitmap mutations preserve neighboring bits" {
    try checks.bits.individualMutations();
}

test "bits outside storage stay occupied and ignore mutations" {
    try checks.bits.outsideStorage();
}

test "bitmap range mutations preserve adjacent bits" {
    try checks.bits.rangeMutations();
}

test "first clear search excludes non-byte-aligned padding" {
    try checks.bits.boundedFirstClear();
}

test "contiguous clear search respects its bounds" {
    try checks.bits.boundedContiguousClear();
}

test "zero length contiguous searches return their inclusive start boundary" {
    try checks.bits.zeroLengthContiguousClear();
}

test "CRC32 matches empty and standard text vectors" {
    try checks.crc.knownTextVectors();
}

test "CRC32 matches binary vectors including zero bytes" {
    try checks.crc.knownBinaryVectors();
}

test "CRC32 reads only the supplied slice" {
    try checks.crc.boundedSlices();
}

test "ceiling division handles zero exact and partial quotients" {
    try checks.math.ceilingDivisionBoundaries();
}

test "ceiling division avoids numerator addition overflow" {
    try checks.math.ceilingDivisionLimits();
}

test "power of two alignment handles adjacent page boundaries" {
    try checks.math.alignmentBoundaries();
}

test "power of two alignment handles large valid unsigned values" {
    try checks.math.alignmentLimits();
}

test "power of two alignment preserves generic unsigned widths" {
    try checks.math.alignmentWidths();
}

test "integer square root floors square neighbors through the u64 limit" {
    try checks.math.squareRootBoundaries();
}

test "path iteration exhausts empty and separator only locations" {
    try checks.path.emptyPaths();
}

test "path iteration skips repeated mixed separators" {
    try checks.path.mixedSeparators();
}

test "path iteration preserves lexical dots prefixes spaces and case" {
    try checks.path.lexicalComponents();
}

test "path iterators retain independent positions and borrowed slices" {
    try checks.path.independentIterators();
}

test "empty UTF-8 decoding returns the replacement sentinel" {
    try checks.utf8.emptyInput();
}

test "UTF-8 decodes scalar boundaries and reports encoded lengths" {
    try checks.utf8.validScalars();
}

test "UTF-8 rejects invalid leading bytes with one byte recovery" {
    try checks.utf8.invalidLeads();
}

test "UTF-8 rejects truncated sequences with one byte recovery" {
    try checks.utf8.truncatedSequences();
}

test "UTF-8 rejects invalid continuations at each sequence position" {
    try checks.utf8.invalidContinuations();
}

test "UTF-8 rejects complete overlong sequences at their encoded lengths" {
    try checks.utf8.overlongSequences();
}

test "UTF-8 rejects surrogate scalar endpoints at their encoded lengths" {
    try checks.utf8.surrogateScalars();
}

test "UTF-8 rejects scalars above the Unicode maximum" {
    try checks.utf8.outOfRangeScalars();
}

test "UTF-8 recovery lengths preserve subsequent text" {
    try checks.utf8.recoveryProgress();
}
