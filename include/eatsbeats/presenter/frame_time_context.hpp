#ifndef EATS_FRAME_TIME_CONTEXT_HPP
#define EATS_FRAME_TIME_CONTEXT_HPP

#include <cstdint>

namespace eatsbeats {

/**
 * @brief Injectable virtual time context adhering to Architectural Rule 1.
 * Decouples views, presenters, and animation loops from OS steady_clock and GLFW time,
 * enabling both zero-CPU idle suspension and deterministic non-realtime offline export.
 */
struct FrameTimeContext {
    double songTimeSeconds{0.0};
    double deltaTime{0.016666666666666666};
    uint64_t frameIndex{0};
    bool isOfflineExport{false};

    [[nodiscard]] constexpr float dt() const noexcept {
        return static_cast<float>(deltaTime);
    }

    [[nodiscard]] constexpr double fps() const noexcept {
        return (deltaTime > 0.000001) ? (1.0 / deltaTime) : 60.0;
    }

    void advance(double stepDt) noexcept {
        deltaTime = stepDt;
        songTimeSeconds += stepDt;
        ++frameIndex;
    }

    void advanceFrames(uint64_t frames, double stepDt) noexcept {
        deltaTime = stepDt;
        songTimeSeconds += stepDt * static_cast<double>(frames);
        frameIndex += frames;
    }
};

} // namespace eatsbeats

namespace eatsbeats::presenter {
    using FrameTimeContext = eatsbeats::FrameTimeContext;
}

#endif // EATS_FRAME_TIME_CONTEXT_HPP
