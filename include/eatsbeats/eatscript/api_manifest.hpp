#ifndef EATS_API_MANIFEST_HPP
#define EATS_API_MANIFEST_HPP

#include <string>
#include <vector>
#include <algorithm>

namespace eatsbeats::eatscript {

/**
 * Metadata entry mapping a high-level Eatscript module/class import
 * to its underlying C++ header, type, and source files.
 */
struct ApiModuleEntry {
    std::string moduleKey;                 // e.g. "eats.dsp.TB303"
    std::string cppHeader;                 // e.g. "eatsbeats/audio/dsp/tb303_core.hpp"
    std::string cppType;                   // e.g. "eatsbeats::dsp::Tb303Core"
    std::vector<std::string> sources;      // e.g. {"src/audio/dsp/dx7_core.cpp"}
    std::vector<std::string> dependencies; // e.g. {"eats_core"}
    std::vector<std::string> aliases;      // e.g. {"TB303", "eat.dsp.TB303", "tb303"}
};

/**
 * Resolved dependency closure for an exported script patch.
 */
struct DependencySet {
    std::vector<std::string> headers;
    std::vector<std::string> sources;
    std::vector<std::string> definitions;
    std::vector<std::string> targetModules;

    void addHeader(const std::string& h) {
        if (!h.empty() && std::find(headers.begin(), headers.end(), h) == headers.end()) {
            headers.push_back(h);
        }
    }

    void addSource(const std::string& s) {
        if (!s.empty() && std::find(sources.begin(), sources.end(), s) == sources.end()) {
            sources.push_back(s);
        }
    }

    void addDefinition(const std::string& d) {
        if (!d.empty() && std::find(definitions.begin(), definitions.end(), d) == definitions.end()) {
            definitions.push_back(d);
        }
    }

    void addModule(const std::string& m) {
        if (!m.empty() && std::find(targetModules.begin(), targetModules.end(), m) == targetModules.end()) {
            targetModules.push_back(m);
        }
    }
};

/**
 * Declarative registry of all Eatsbeats DSP & FX modules available for
 * AOT tree-shaking and micro-runtime export.
 */
class ApiManifest {
public:
    static const std::vector<ApiModuleEntry>& getAllModules() noexcept {
        static const std::vector<ApiModuleEntry> s_modules = {
            {
                "eats.dsp.DiodeLadder",
                "eatsbeats/audio/dsp/tb303_core.hpp",
                "eatsbeats::dsp::DiodeLadderFilter",
                {},
                {"eats_core"},
                {"DiodeLadder", "eat.dsp.DiodeLadder", "diode_ladder"}
            },
            {
                "eats.dsp.TB303",
                "eatsbeats/audio/dsp/tb303_core.hpp",
                "eatsbeats::dsp::Tb303Core",
                {},
                {"eats_core"},
                {"TB303", "eat.dsp.TB303", "tb303", "eats_303", "RolandTB303"}
            },
            {
                "eats.dsp.PolySynth",
                "eatsbeats/audio/dsp/poly_synth.hpp",
                "eatsbeats::dsp::PolySynth",
                {},
                {"eats_core"},
                {"PolySynth", "eat.dsp.PolySynth", "polysynth", "polyblep"}
            },
            {
                "eats.dsp.DX7",
                "eatsbeats/audio/dsp/dx7_core.hpp",
                "eatsbeats::dsp::Dx7Core",
                {"src/audio/dsp/dx7_core.cpp"},
                {"eats_core"},
                {"DX7", "eat.dsp.DX7", "dx7", "dx7_epiano", "YamahaDX7"}
            },
            {
                "eats.dsp.YM2612",
                "eatsbeats/audio/dsp/ym2612_core.hpp",
                "eatsbeats::dsp::Ym2612Core",
                {},
                {"eats_core"},
                {"YM2612", "eat.dsp.YM2612", "ym2612", "genesis_ym2612", "GenesisFM"}
            },
            {
                "eats.dsp.SID",
                "eatsbeats/audio/dsp/sid_core.hpp",
                "eatsbeats::dsp::SidCore",
                {},
                {"eats_core"},
                {"SID", "eat.dsp.SID", "sid", "c64_sid_synth", "MOS6581", "MOS8580"}
            },
            {
                "eats.dsp.SNES",
                "eatsbeats/audio/dsp/snes_dsp_core.hpp",
                "eatsbeats::dsp::SnesDspCore",
                {},
                {"eats_core"},
                {"SNES", "eat.dsp.SNES", "snes", "snes_dsp", "SPC700"}
            },
            {
                "eats.dsp.Biquad",
                "eatsbeats/audio/dsp/biquad.hpp",
                "eatsbeats::dsp::Biquad",
                {},
                {"eats_core"},
                {"Biquad", "eat.dsp.Biquad", "biquad", "BiquadFilter"}
            },
            {
                "eats.dsp.ADSR",
                "eatsbeats/audio/dsp/adsr.hpp",
                "eatsbeats::dsp::Adsr",
                {},
                {},
                {"ADSR", "eat.dsp.ADSR", "adsr", "AdsrEnvelope"}
            },
            {
                "eats.dsp.Oscillator",
                "eatsbeats/audio/graph/nodes/oscillator_node.hpp",
                "eatsbeats::audio::OscillatorNode",
                {"src/audio/graph/nodes/oscillator_node.cpp"},
                {"eats_audio", "eats_daisysp"},
                {"Oscillator", "osc", "eat.dsp.Oscillator", "oscillator", "DaisyOscillator", "daisy_oscillator", "daisy_osc", "eats.dsp.DaisyOscillator", "eats.dsp.daisy_osc"}
            },
            {
                "eats.dsp.MoogFilter",
                "eatsbeats/audio/graph/nodes/moog_filter_node.hpp",
                "eatsbeats::audio::MoogFilterNode",
                {"src/audio/graph/nodes/moog_filter_node.cpp"},
                {"eats_audio", "eats_daisysp"},
                {"MoogFilter", "moog", "moog_ladder", "Filter", "daisy_filter", "DaisyFilter", "daisy_svf", "eats.dsp.DaisyFilter", "eats.dsp.moog_ladder"}
            },
            {
                "eats.fx.ChorusFlanger",
                "eatsbeats/audio/dsp/chorus_flanger.hpp",
                "eatsbeats::dsp::ChorusFlanger",
                {},
                {"eats_core"},
                {"ChorusFlanger", "eat.fx.ChorusFlanger", "chorus_flanger"}
            },
            {
                "eats.fx.DynamicsProcessor",
                "eatsbeats/audio/dsp/dynamics_processor.hpp",
                "eatsbeats::dsp::DynamicsProcessor",
                {},
                {"eats_core"},
                {"DynamicsProcessor", "eat.fx.DynamicsProcessor", "limiter"}
            },
            {
                "eats.fx.Convolver",
                "eatsbeats/audio/dsp/convolver_core.hpp",
                "eatsbeats::dsp::ConvolverCore",
                {},
                {"eats_core"},
                {"Convolver", "eat.fx.Convolver", "convolver", "reverb_ir"}
            },
            {
                "eats.fx.ParametricEQ",
                "eatsbeats/audio/dsp/parametric_eq.hpp",
                "eatsbeats::dsp::ParametricEQ",
                {},
                {"eats_core"},
                {"ParametricEQ", "eat.fx.ParametricEQ", "eq", "Equalizer"}
            },
            {
                "eats.fx.Reverb",
                "eatsbeats/audio/graph/nodes/reverb_node.hpp",
                "eatsbeats::audio::ReverbNode",
                {"src/audio/graph/nodes/reverb_node.cpp"},
                {"eats_audio", "eats_daisysp"},
                {"Reverb", "reverb", "reverb_sc", "reverbsc", "daisy_reverb", "DaisyReverb", "eats.fx.DaisyReverb", "eats.fx.reverb_sc"}
            },
            {
                "eats.fx.Delay",
                "eatsbeats/audio/graph/nodes/delay_node.hpp",
                "eatsbeats::audio::DelayNode",
                {"src/audio/graph/nodes/delay_node.cpp"},
                {"eats_audio", "eats_daisysp"},
                {"Delay", "delay", "daisy_delay", "daisy_echo", "DaisyDelay", "eats.fx.DaisyDelay"}
            },
            {
                "eats.fx.Chorus",
                "eatsbeats/audio/graph/nodes/chorus_node.hpp",
                "eatsbeats::audio::ChorusNode",
                {"src/audio/graph/nodes/chorus_node.cpp"},
                {"eats_audio", "eats_daisysp"},
                {"Chorus", "chorus", "flanger", "daisy_chorus", "daisy_flanger", "daisy_overdrive", "DaisyModulation", "eats.fx.DaisyModulation"}
            },
            {
                "eats.fx.Compressor",
                "eatsbeats/audio/graph/nodes/compressor_node.hpp",
                "eatsbeats::audio::CompressorNode",
                {"src/audio/graph/nodes/compressor_node.cpp"},
                {"eats_audio", "eats_daisysp"},
                {"Compressor", "compressor", "daisy_compressor", "daisy_comp", "DaisyCompressor", "eats.fx.DaisyCompressor"}
            },
            {
                "eats.dsp.DaisyOscillator",
                "eatsbeats/audio/graph/nodes/oscillator_node.hpp",
                "eatsbeats::audio::OscillatorNode",
                {"src/audio/graph/nodes/oscillator_node.cpp"},
                {"eats_audio", "eats_daisysp"},
                {"DaisyOscillator", "daisy_oscillator"}
            },
            {
                "eats.dsp.DaisyFilter",
                "eatsbeats/audio/graph/nodes/moog_filter_node.hpp",
                "eatsbeats::audio::MoogFilterNode",
                {"src/audio/graph/nodes/moog_filter_node.cpp"},
                {"eats_audio", "eats_daisysp"},
                {"DaisyFilter"}
            },
            {
                "eats.fx.DaisyReverb",
                "eatsbeats/audio/graph/nodes/reverb_node.hpp",
                "eatsbeats::audio::ReverbNode",
                {"src/audio/graph/nodes/reverb_node.cpp"},
                {"eats_audio", "eats_daisysp"},
                {"DaisyReverb"}
            },
            {
                "eats.fx.DaisyDelay",
                "eatsbeats/audio/graph/nodes/delay_node.hpp",
                "eatsbeats::audio::DelayNode",
                {"src/audio/graph/nodes/delay_node.cpp"},
                {"eats_audio", "eats_daisysp"},
                {"DaisyDelay"}
            },
            {
                "eats.fx.DaisyModulation",
                "eatsbeats/audio/graph/nodes/chorus_node.hpp",
                "eatsbeats::audio::ChorusNode",
                {"src/audio/graph/nodes/chorus_node.cpp"},
                {"eats_audio", "eats_daisysp"},
                {"DaisyModulation"}
            },
            {
                "eats.fx.DaisyCompressor",
                "eatsbeats/audio/graph/nodes/compressor_node.hpp",
                "eatsbeats::audio::CompressorNode",
                {"src/audio/graph/nodes/compressor_node.cpp"},
                {"eats_audio", "eats_daisysp"},
                {"DaisyCompressor"}
            }
        };
        return s_modules;
    }

    [[nodiscard]] static const ApiModuleEntry* findModule(const std::string& keyOrAlias) noexcept {
        const auto& modules = getAllModules();
        for (const auto& mod : modules) {
            if (mod.moduleKey == keyOrAlias) return &mod;
            for (const auto& alias : mod.aliases) {
                if (alias == keyOrAlias) return &mod;
            }
        }
        return nullptr;
    }

    [[nodiscard]] static bool hasModule(const std::string& keyOrAlias) noexcept {
        return findModule(keyOrAlias) != nullptr;
    }
};

} // namespace eatsbeats::eatscript

#endif // EATS_API_MANIFEST_HPP
