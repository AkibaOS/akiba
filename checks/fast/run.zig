//! Fast Check Test Entry

const fast = @import("checks").fast;

test "bitmap byte counts round up non-byte-aligned lengths" {
    try fast.bits.bitmapByteCounts();
}

test "individual bitmap mutations preserve neighboring bits" {
    try fast.bits.individualMutations();
}

test "bits outside storage stay occupied and ignore mutations" {
    try fast.bits.outsideStorage();
}

test "bitmap range mutations preserve adjacent bits" {
    try fast.bits.rangeMutations();
}

test "first clear search excludes non-byte-aligned padding" {
    try fast.bits.boundedFirstClear();
}

test "contiguous clear search respects its bounds" {
    try fast.bits.boundedContiguousClear();
}

test "AFS spans fit entirely inside the volume" {
    try fast.afs.spanBounds();
}

test "AFS span checks reject overflowing ends" {
    try fast.afs.spanOverflow();
}

test "AFS cell LBAs honor inclusive endpoints" {
    try fast.afs.inclusiveEndpoints();
}

test "AFS cell LBAs reject invalid geometry" {
    try fast.afs.invalidGeometry();
}

test "AFS cell reads reject truncation" {
    try fast.afs.truncatedReads();
}

test "AFS cell LBAs guard large offsets" {
    try fast.afs.largeOffsets();
}

test "AFS headers validate signature and version" {
    try fast.afs.signatureAndVersion();
}

test "AFS header cell sizes respect supported boundaries" {
    try fast.afs.cellSizeBoundaries();
}
