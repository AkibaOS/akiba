//! Set 1 Prefix And Modifier State

pub const State = struct {
    Extended: bool = false,
    PauseIndex: usize = 0,
    LeftShift: bool = false,
    RightShift: bool = false,
    LeftControl: bool = false,
    RightControl: bool = false,
    LeftAlt: bool = false,
    RightAlt: bool = false,
    CapsLock: bool = false,
    CapsHeld: bool = false,
};
