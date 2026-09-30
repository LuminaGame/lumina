/// How the MCP tools describe a rotation, in one set of words so an agent
/// never reads two orders for the same numbers.
library;

/// A level actor's, a multi-selection's or a Blueprint component's rotation
/// (the Details panel, `LuminaAxes.rotation`), a Blueprint rotator pin and
/// the play-testing reads all use this triple.
const String kMcpRotationConvention =
    '[pitch, roll, yaw] in degrees about X, Y, Z, as the Details panel shows it: yaw 0 faces +Y, positive yaw '
    'turns right (yaw 90 faces +X), positive pitch looks up, positive roll dips the left side';

/// A skeletal-mesh socket's rotation is in its bone's own frame instead.
const String kMcpBoneRotationConvention =
    '[x, y, z] in degrees about the bone\'s own X, Y, Z axes (applied X, then Y, then Z); bone space, not the '
    'level\'s [pitch, roll, yaw]';
