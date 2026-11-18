//! Raster Errors

pub const CoordinateError = error{
    CoordinateOutOfRange,
};

pub const RasterError = CoordinateError || error{
    InvalidContour,
    ShapeTooWide,
    TooManyEdges,
};
