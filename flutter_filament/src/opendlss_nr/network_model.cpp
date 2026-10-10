/*
 * Copyright 2026 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

// Compiles the vendored OpenDLSS-NR source third_party/opendlss_nr/upstream/src/nr_model.cpp on the platforms the pass
// runs on (see opendlss_nr_config.h); the file itself stays as vendored.
#include "opendlss_nr/opendlss_nr_config.h"

#if FLUTTER_FILAMENT_OPENDLSS_NR_ENABLED
#include "../../third_party/opendlss_nr/upstream/src/nr_model.cpp"
#endif
