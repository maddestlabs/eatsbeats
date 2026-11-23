#ifndef EATS_AUDIO_NODE_HPP
#define EATS_AUDIO_NODE_HPP

#include <cstdint>
#include <cstddef>
#include "../../abi/eats_plugin_abi.h"

namespace eatsbeats::audio {

/**
 * Interface for all nodes inside the Eatsbeats audio graph.
 * Direct memory rendering, zero dynamic allocations during process().
 */
class IAudioNode {
public:
    virtual ~IAudioNode() = default;

    virtual void prepare(double sampleRate, uint32_t maxBlockSize) = 0;
    virtual void process(const EatsAudioBuffer& buffer) noexcept = 0;
    virtual void reset() noexcept = 0;
};

} // namespace eatsbeats::audio

#endif // EATS_AUDIO_NODE_HPP
