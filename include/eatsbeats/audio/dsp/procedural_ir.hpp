#pragma once

#include "eatsbeats/audio/procedural_ir_generator.hpp"

namespace eatsbeats::audio::dsp {

// Backward compatibility aliases importing procedural IR types into eatsbeats::audio::dsp
using AcousticMaterialType = eatsbeats::audio::AcousticMaterialType;
using AcousticMaterial = eatsbeats::audio::AcousticMaterial;
using AcousticSpaceParams = eatsbeats::audio::AcousticSpaceParams;
using StereoIRBuffer = eatsbeats::audio::StereoIRBuffer;
using ProceduralIRGenerator = eatsbeats::audio::ProceduralIRGenerator;

} // namespace eatsbeats::audio::dsp
