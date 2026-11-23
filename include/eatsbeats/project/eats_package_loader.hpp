#ifndef EATSBEATS_PROJECT_EATS_PACKAGE_LOADER_HPP
#define EATSBEATS_PROJECT_EATS_PACKAGE_LOADER_HPP

#include "eatsbeats/eatscript/macro_runtime.hpp"
#include "eatsbeats/project/preset_loader.hpp"
#include "eatsbeats/project/sequence_catalog.hpp"

#include <string>
#include <vector>

namespace eatsbeats::project {

/**
 * Aggregated assets registered by a single `.eats` package evaluation.
 * A single `.eats` file may define one or multiple instruments, FX, MIDI FX,
 * utilities, sequences, and/or macros via `eats.define_*` API calls.
 */
struct EatsLoadResult {
    bool ok{false};
    std::string error;

    std::vector<PresetDefinition> presets;
    std::vector<SequenceDefinition> sequences;
    std::vector<eatscript::MacroDefinition> macros;

    [[nodiscard]] bool hasAnyAsset() const noexcept {
        return !presets.empty() || !sequences.empty() || !macros.empty();
    }
};

/**
 * Unified declarative `.eats` package loader for Eatsbeats.
 * Evaluates Eatscript files exposing the `eats.define_*` registration API:
 *   - `eats.define_instrument({...})`
 *   - `eats.define_fx({...})`
 *   - `eats.define_midi_fx({...})`
 *   - `eats.define_utility({...})`
 *   - `eats.define_sequence({...})`
 *   - `eats.define_macro({...})`
 */
class EatsPackageLoader {
public:
    static bool loadFile(const std::string& filePath, EatsLoadResult& outResult);

    static bool loadSource(const std::string& source,
                           const std::string& virtualPath,
                           EatsLoadResult& outResult);
};

} // namespace eatsbeats::project

#endif // EATSBEATS_PROJECT_EATS_PACKAGE_LOADER_HPP
