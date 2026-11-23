#include "eatsbeats/text/embedded_fonts.hpp"
#include <ft2build.h>
#include FT_FREETYPE_H
#include <hb.h>
#include <hb-ft.h>

namespace eatsbeats::text {

// Anchor translation unit for eats_text static library
const unsigned char* getEmbeddedMonospaceFontData(size_t* outSize) {
    if (outSize) {
        *outSize = kShareTechMonoTtfSize;
    }
    return kShareTechMonoTtf;
}

} // namespace eatsbeats::text
