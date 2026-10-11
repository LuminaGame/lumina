/*
 * Copyright 2024 flutter_filament authors.
 * Licensed under the Apache License, Version 2.0.
 */

// Android only: Filament's abseil build (third_party/abseil/tnt) leaves out
// absl/random/internal/pool_urbg.cc, yet code in the combined libabseil.a still
// references absl::random_internal::GetEntropyFromRandenPool. On desktop the
// linker never pulls that member in; on Android the archives are linked whole,
// and the unresolved symbol makes dlopen of libflutter_filament.so fail on the
// device. The NDK's arc4random_buf supplies the entropy instead.
#if defined(__ANDROID__)
#include <cstddef>
#include <cstdlib>

namespace absl {
namespace random_internal {
void GetEntropyFromRandenPool(void* dest, size_t bytes) {
    if (dest && bytes > 0) arc4random_buf(dest, bytes);
}
}  // namespace random_internal
}  // namespace absl
#endif  // __ANDROID__
