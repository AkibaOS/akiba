//! Fast Check Test Entry

const fast = @import("tests").fast;

test "bitmap byte counts round up non-byte-aligned lengths" {
    try fast.utils.bits.bitmapByteCounts();
}

test "individual bitmap mutations preserve neighboring bits" {
    try fast.utils.bits.individualMutations();
}

test "bits outside storage stay occupied and ignore mutations" {
    try fast.utils.bits.outsideStorage();
}

test "bitmap range mutations preserve adjacent bits" {
    try fast.utils.bits.rangeMutations();
}

test "first clear search excludes non-byte-aligned padding" {
    try fast.utils.bits.boundedFirstClear();
}

test "contiguous clear search respects its bounds" {
    try fast.utils.bits.boundedContiguousClear();
}

test "AFS spans fit entirely inside the volume" {
    try fast.shared.afs.bounds.spanBounds();
}

test "AFS span checks reject overflowing ends" {
    try fast.shared.afs.bounds.spanOverflow();
}

test "AFS cell LBAs honor inclusive endpoints" {
    try fast.shared.afs.bounds.inclusiveEndpoints();
}

test "AFS cell LBAs reject invalid geometry" {
    try fast.shared.afs.bounds.invalidGeometry();
}

test "AFS cell reads reject truncation" {
    try fast.shared.afs.bounds.truncatedReads();
}

test "AFS cell LBAs guard large offsets" {
    try fast.shared.afs.bounds.largeOffsets();
}

test "AFS headers validate signature and version" {
    try fast.shared.afs.bounds.signatureAndVersion();
}

test "AFS header cell sizes respect supported boundaries" {
    try fast.shared.afs.bounds.cellSizeBoundaries();
}
