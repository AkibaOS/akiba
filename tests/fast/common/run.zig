//! Common Native Test Entry

const fixed = @import("tests").fast.common.fixed;

test "fixed 26.6 construction preserves raw values and integer limits" {
    try fixed.fixed26Construction();
}

test "fixed 26.6 signed fractions and half ties round consistently" {
    try fixed.fixed26SignedRounding();
}

test "fixed 26.6 truncation handles positive fractions and signed integers" {
    try fixed.fixed26Truncation();
}

test "fixed 26.6 addition and subtraction preserve fractional carries" {
    try fixed.fixed26AdditionAndSubtraction();
}

test "fixed 26.6 multiplication uses wide signed products" {
    try fixed.fixed26Multiplication();
}

test "fixed 26.6 division truncates signed quotients" {
    try fixed.fixed26Division();
}

test "fixed 26.6 zero divisors return zero" {
    try fixed.fixed26ZeroDivision();
}

test "fixed 26.6 ordering compares signed raw values" {
    try fixed.fixed26Ordering();
}

test "fixed 16.16 ratios round signed numerators and wide intermediates" {
    try fixed.fixed16SignedRatios();
}

test "fixed 16.16 negative denominators preserve sign and rounding" {
    try fixed.fixed16NegativeDenominators();
}

test "fixed 16.16 zero denominators return zero" {
    try fixed.fixed16ZeroDenominator();
}

test "fixed 16.16 multiplication preserves scale and signed quantization" {
    try fixed.fixed16Multiplication();
}

test "fixed 16.16 unit scaling rounds signed half units" {
    try fixed.fixed16UnitScaling();
}
