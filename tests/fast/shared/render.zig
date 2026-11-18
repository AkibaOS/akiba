//! Native Rendering Regression Test Root

const checks = @import("tests").fast.shared;

test "SFNT reader decodes endian values and reaches its exact end" {
    try checks.sfnt.reader.endianAndCursor();
}

test "SFNT failed reads and seeks preserve the cursor" {
    try checks.sfnt.reader.failedReadsPreservePosition();
}

test "SFNT slices reject crossing and overflowing bounds" {
    try checks.sfnt.reader.sliceBounds();
}

test "SFNT tables support lookup and reject out of bounds records" {
    try checks.sfnt.directory.tableLookupAndBounds();
}

test "SFNT directories distinguish signatures and truncated records" {
    try checks.sfnt.directory.signaturesAndTruncation();
}

test "SFNT directories grow beyond the retired cache and still reject truncated backing" {
    try checks.sfnt.directory.tableGrowth();
}

test "minimal font face loads signed and trailing horizontal metrics" {
    try checks.font.face.minimalFaceAndMetrics();
}

test "font metrics reject invalid glyphs and truncated storage" {
    try checks.font.face.metricErrors();
}

test "font face accepts large declared outlines without provisioning scratch" {
    try checks.font.face.largeDeclaredOutline();
}

test "font face enforces metric and glyph location table bounds" {
    try checks.font.face.mandatoryMetricsAndLocations();
}

test "font face loading requires complete mandatory tables" {
    try checks.font.face.requiredTableBounds();
}

test "malformed face rejects zero UnitsPerEm before rendering" {
    try checks.font.face.malformedFaceRejectsZeroUnitsPerEm();
}

test "embedded face integrates Latin and kana mapping metrics and outlines" {
    try checks.font.face.embeddedFaceIntegration();
}

test "cmap4 handles deltas range offsets missing glyphs and BMP limits" {
    try checks.font.charmap.segmentedMapping();
}

test "cmap12 handles group endpoints gaps and supplementary codepoints" {
    try checks.font.charmap.segmentedCoverage();
}

test "cmap lookup respects each subtable's own byte length" {
    try checks.font.charmap.declaredLengths();
}

test "cmap lookup refuses glyph IDs outside its representation" {
    try checks.font.charmap.glyphDomain();
}

test "character maps reject overlapping or reversed ranges and invalid complete glyph spans" {
    try checks.font.charmap.completeOrderingAndSpans();
}

test "cmap selection ranks supported encodings and reports malformed records" {
    try checks.font.charmap.selectionPreferenceAndErrors();
}

test "simple short outlines decode coordinates and empty glyphs reset output" {
    try checks.font.outline.simpleAndEmptyOutlines();
}

test "simple outlines decode repeated flags signed deltas and long loca" {
    try checks.font.outline.repeatedFlagsAndLongLocations();
}

test "composite outlines support signed byte offsets and scalar or axis scale" {
    try checks.font.outline.translatedAndScaledComponents();
}

test "composite outlines compose nested matrices and rebase contour endpoints" {
    try checks.font.outline.nestedMatrixAndMultipleComponents();
}

test "composite outline depth accepts its boundary and rejects deeper chains" {
    try checks.font.outline.componentDepthBoundary();
}

test "composite outlines enforce placement modes and bounded instruction spans" {
    try checks.font.outline.componentPlacementAndInstructions();
}

test "outline extraction rejects invalid locations and truncated geometry" {
    try checks.font.outline.malformedOutlineBoundsAndLimits();
}

test "simple outlines reject descending duplicate and truncated contour endpoints" {
    try checks.font.outline.malformedContourEndpoints();
}

test "outline transforms keep representable results despite wide products" {
    try checks.font.outline.wideTransformIntermediate();
}

test "simple outlines accept the full uint16 endpoint index and more than 128 contours" {
    try checks.font.outline.maximumSimpleOutline();
}

test "raster integer rectangles have full interior and zero boundary coverage" {
    try checks.raster.coverage.integerRectangleAndEmptyShape();
}

test "raster fractional rectangles have analytic quarter and half pixel coverage" {
    try checks.raster.coverage.fractionalAndNegativeRectangles();
}

test "raster diagonal area is one half independent of contour direction" {
    try checks.raster.coverage.diagonalCoverageAndOrientation();
}

test "raster nonzero winding preserves holes saturates overlaps and cancels opposites" {
    try checks.raster.coverage.nonzeroWindingAndCancellation();
}

test "raster writes exact wide coverage across scratch tiles" {
    try checks.raster.coverage.wideTiledRows();
}

test "raster preserves a sloped contour and hole across shifted tile seams" {
    try checks.raster.coverage.slopedTiledCrop();
}

test "raster clips full-range edges without losing winding" {
    try checks.raster.coverage.longClippedEdges();
}

test "flattening places scaled flipped outlines and resets reused shapes" {
    try checks.raster.flatten.placementAndReset();
}

test "flattening implied points and off curve closure match explicit geometry" {
    try checks.raster.flatten.impliedPointsAndClosure();
}

test "quadratic flattening preserves representable geometry after large translation" {
    try checks.raster.flatten.translatedCurves();
}

test "growable flattened edges exceed the old ceiling while fixed scratch reports exhaustion" {
    try checks.raster.flatten.edgeGrowthAndFixedScratch();
}

test "UTF8 cursor positions use codepoints and fixed point tracking" {
    try checks.typeset.measure.unicodeCursorAndTracking();
}

test "text measurement rounds after accumulation and tracks only inter glyph gaps" {
    try checks.typeset.measure.measurementRoundingAndGaps();
}

test "invalid UTF8 consumes bounded input and advances replacement glyphs" {
    try checks.typeset.measure.invalidUTF8MakesBoundedProgress();
}

test "typesetting propagates mapping and metric errors" {
    try checks.typeset.measure.fontErrorsPropagate();
}

test "graphics pixels pack channels independently of reserved high bits" {
    try checks.graphics.color.packingAndChannels();
}

test "graphics color blending preserves endpoints and both channel directions" {
    try checks.graphics.color.blendEndpointsAndDirections();
}

test "graphics rectangles pixels and clear respect clipping and stride guards" {
    try checks.graphics.draw.clippedRectanglesAndClear();
}

test "graphics striped quads respect clipped scanline boundaries" {
    try checks.graphics.draw.clippedStripedQuad();
}

test "graphics copies preserve snapshot semantics for overlapping rectangles" {
    try checks.graphics.draw.overlappingCopies();
}

test "text coverage blends against stored pixels or an explicit background" {
    try checks.graphics.text.coverageBlending();
}

test "text glyph clipping preserves guards and reports font errors" {
    try checks.graphics.text.clippedGlyphAndFontError();
}

test "embedded face renders antialiased Latin and kana into a guarded surface" {
    try checks.graphics.text.embeddedTextIntegration();
}

test "console geometry controls replacement and wrapping preserve cells" {
    try checks.graphics.console.geometryControlsAndWrap();
}

test "console scrolling and clearing preserve strided framebuffer bounds" {
    try checks.graphics.console.scrollAndClearing();
}

test "splash trail state preserves bounded FIFO messages and saturating progress" {
    try checks.splash.state.boundedTrailAndProgress();
}

test "splash progress widths handle zero totals and clamp oversized steps" {
    try checks.splash.progress.boundedTargetWidths();
}

test "splash progress repaints stale fill and uses failure colors without spill" {
    try checks.splash.progress.repaintAndFailurePalette();
}

test "splash canvas covers its viewport and centres measured text" {
    try checks.splash.progress.canvasCoverAndCentredText();
}

test "splash trail replaces activity markers and renders completion status" {
    try checks.splash.trail.activeToCompleteRepaint();
}

test "failed splash rows render FAIL rather than OK" {
    try checks.splash.trail.failedRowsRenderFailNotOK();
}

test "malformed font errors do not commit partial splash trail frames" {
    try checks.splash.trail.malformedFontDoesNotCommitPartialTrail();
}

test "splash trail clips its buffered commit and ignores offscreen bands" {
    try checks.splash.trail.clippedTrailPreservesOutsidePixels();
}

test "diagnostic progress advances only after named checks end" {
    try checks.screen.model.lifecycle();
}

test "diagnostic viewport scrolls without limiting completed checks" {
    try checks.screen.model.scrolling();
}

test "diagnostic screen repaints only the log and progress while retaining stride guards" {
    try checks.screen.render.fixedChrome();
}

test "failed diagnostic composition leaves the previous frame intact" {
    try checks.screen.render.failedComposition();
}

test "diagnostic assertion evidence does not advance group progress" {
    try checks.screen.model.evidence();
}

test "diagnostic build date uses the cached image timestamp in UTC" {
    try checks.screen.model.metadata();
}

test "the diagnostic fallback date fits at the minimum screen width" {
    try checks.screen.render.fallbackTitle();
}

test "a terminal assertion replaces the running row with its actual failed check" {
    try checks.screen.model.failure();
}
