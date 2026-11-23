#pragma once

#include "eatsbeats/tui/cell_surface.hpp"
#include "eatsbeats/tui/input_parser.hpp"
#include "eatsbeats/tui/clay_tui_bridge.hpp"
#include "eatsbeats/audio/audio_engine.hpp"
#include "eatsbeats/presenter/parameter_presenter.hpp"
#include "eatsbeats/presenter/value_edit_presenter.hpp"
#include <string>
#include <vector>
#include <memory>

namespace eatsbeats::ui::clay {
class ClayContext;
}

namespace eatsbeats::tui {

class ParamRackView {
public:
    ParamRackView();
    ~ParamRackView();

    void render(CellSurface& surface, const Rect& area, audio::AudioEngine& engine, bool isFocused);

    void moveSelection(int delta);
    void adjustValue(int steps, audio::AudioEngine& engine);

    [[nodiscard]] bool isEditing() const noexcept { return isEditing_; }
    void startEdit(audio::AudioEngine& engine);
    void cancelEdit();
    void commitEdit(audio::AudioEngine& engine);
    bool handleKey(const KeyEvent& key, audio::AudioEngine& engine);

    [[nodiscard]] size_t getSelectedIndex() const noexcept { return selectedIndex_; }
    [[nodiscard]] size_t getParamCount() const noexcept { return params_.size(); }
    [[nodiscard]] const presenter::ParameterPresenter* getSelectedParam() const noexcept {
        return (selectedIndex_ < params_.size()) ? &params_[selectedIndex_] : nullptr;
    }
    [[nodiscard]] const std::string& getEditBuffer() const noexcept { return editBuffer_; }

private:
    std::vector<presenter::ParameterPresenter> params_;
    size_t selectedIndex_{0};

    bool isEditing_{false};
    std::string editBuffer_{""};
    presenter::ValueEditPresenter editPresenter_{};

    std::unique_ptr<ui::clay::ClayContext> clayContext_;
    ClayTuiBridge clayBridge_;

    void applyParam(size_t index, audio::AudioEngine& engine);
};

} // namespace eatsbeats::tui
