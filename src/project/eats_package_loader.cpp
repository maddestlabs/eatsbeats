#include "eatsbeats/project/eats_package_loader.hpp"
#include "eatsbeats/eatscript/evaluator.hpp"

#include <algorithm>
#include <cctype>
#include <fstream>
#include <sstream>

namespace eatsbeats::project {

using eatsbeats::eatscript::MacroDefinition;
using eatsbeats::eatscript::MacroParamDef;
using eatsbeats::eatscript::MacroParamType;
using eatsbeats::eatscript::Value;

namespace {

std::string toLowerAscii(std::string s) {
    for (char& c : s) {
        c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    }
    return s;
}

std::string stemFromPath(const std::string& path) {
    size_t slash = path.find_last_of("/\\");
    std::string base = (slash == std::string::npos) ? path : path.substr(slash + 1);
    size_t dot = base.rfind('.');
    if (dot != std::string::npos) base = base.substr(0, dot);
    return base;
}

std::string sanitizeIdFromName(const std::string& name, const std::string& fallbackPath) {
    std::string id = toLowerAscii(name);
    for (char& c : id) {
        if (!std::isalnum(static_cast<unsigned char>(c))) {
            c = '_';
        }
    }
    if (id.empty()) {
        id = toLowerAscii(stemFromPath(fallbackPath));
    }
    return id;
}

std::string serializeSequenceEvents(const Value& eventsVal) {
    if (!eventsVal.isList()) return {};
    std::ostringstream ss;
    for (const auto& ev : eventsVal.listVal) {
        if (!ev.isDict()) continue;
        ss << "{ ";
        bool first = true;
        auto writeField = [&](const char* key, const std::string& formatted) {
            if (!first) ss << ", ";
            ss << key << " = " << formatted;
            first = false;
        };

        if (ev.hasKey("pitch")) {
            const Value& p = ev.get("pitch");
            if (p.isString()) {
                writeField("pitch", "\"" + p.asString() + "\"");
            } else if (p.isNumber()) {
                writeField("pitch", std::to_string(p.asInt(60)));
            }
        }
        if (ev.hasKey("step")) writeField("step", std::to_string(ev.get("step").asNumber(0.0)));
        if (ev.hasKey("dur")) writeField("dur", std::to_string(ev.get("dur").asNumber(1.0)));
        if (ev.hasKey("vel")) writeField("vel", std::to_string(ev.get("vel").asNumber(0.85)));
        if (ev.hasKey("lane")) writeField("lane", std::to_string(ev.get("lane").asInt(0)));
        if (ev.hasKey("slide") && ev.get("slide").asBoolean(false)) writeField("slide", "true");
        if (ev.hasKey("accent") && ev.get("accent").asBoolean(false)) writeField("accent", "true");
        ss << " }\n";
    }
    return ss.str();
}

} // namespace

bool EatsPackageLoader::loadFile(const std::string& filePath, EatsLoadResult& outResult) {
    std::ifstream ifs(filePath);
    if (!ifs.is_open()) {
        outResult = EatsLoadResult{};
        outResult.error = "Failed to open .eats file: " + filePath;
        return false;
    }
    std::ostringstream ss;
    ss << ifs.rdbuf();
    return loadSource(ss.str(), filePath, outResult);
}

bool EatsPackageLoader::loadSource(const std::string& source,
                                   const std::string& virtualPath,
                                   EatsLoadResult& outResult) {
    outResult = EatsLoadResult{};
    if (source.empty()) {
        outResult.error = "Empty .eats source";
        return false;
    }

    eatscript::Evaluator ev;
    ev.setVariable("eats", Value(std::map<std::string, Value>{}));

    auto registerPresetKind = [&](const std::string& defaultCategory) {
        return [&, defaultCategory](const std::vector<Value>& args,
                                  const std::map<std::string, Value>&) -> Value {
            if (args.empty() || !args[0].isDict()) return Value(false);
            const auto& d = args[0];

            PresetDefinition def{};
            def.rawScript = source;
            def.metadata.id = toLowerAscii(d.get("id").asString());
            def.metadata.name = d.get("name").asString();
            if (def.metadata.id.empty()) {
                def.metadata.id = sanitizeIdFromName(def.metadata.name, virtualPath);
            }
            if (def.metadata.name.empty()) {
                def.metadata.name = def.metadata.id;
            }

            def.metadata.category = d.get("category", Value(defaultCategory)).asString();
            if (def.metadata.category.empty()) {
                def.metadata.category = defaultCategory;
            }
            def.metadata.description = d.get("description").asString();
            def.metadata.engineId = d.get("engine").asString();

            // Parameters: accept either a dict or a callable returning a dict.
            if (d.hasKey("params")) {
                Value paramsVal = d.get("params");
                if (paramsVal.isFunction()) {
                    paramsVal = ev.invokeCallable(paramsVal);
                }
                if (paramsVal.isDict()) {
                    PresetLoader::parseParamsDict(paramsVal, def.params);
                }
            }

            // Hardware GUI: accept either a dict or a callable returning a dict.
            if (d.hasKey("gui")) {
                Value guiVal = d.get("gui");
                if (guiVal.isFunction()) {
                    guiVal = ev.invokeCallable(guiVal);
                }
                if (guiVal.isDict()) {
                    def.guiRoot = PresetLoader::convertValueToGuiNode(guiVal);
                    if (def.guiRoot.title.empty()) {
                        def.guiRoot.title = def.metadata.name;
                    }
                }
            }

            // Compact GUI (optional).
            if (d.hasKey("compact_gui")) {
                Value compactVal = d.get("compact_gui");
                if (compactVal.isFunction()) {
                    compactVal = ev.invokeCallable(compactVal);
                }
                if (compactVal.isDict()) {
                    def.compactGuiRoot = PresetLoader::convertValueToGuiNode(compactVal);
                }
            }

            // Note: `graph`, `process`, and `transform_notes` are intentionally not invoked
            // during catalog/preset discovery; they remain in `rawScript` for audio-graph
            // instantiation when the device is loaded onto a track.
            outResult.presets.push_back(std::move(def));
            return Value(true);
        };
    };

    ev.registerMemberFunction("eats", "define_instrument", registerPresetKind("instrument"));
    ev.registerMemberFunction("eats", "define_fx", registerPresetKind("audioFx"));
    ev.registerMemberFunction("eats", "define_midi_fx", registerPresetKind("midiFx"));
    ev.registerMemberFunction("eats", "define_utility", registerPresetKind("utility"));

    // eats.define_sequence({...})
    ev.registerMemberFunction("eats", "define_sequence",
        [&](const std::vector<Value>& args, const std::map<std::string, Value>&) -> Value {
            if (args.empty() || !args[0].isDict()) return Value(false);
            const auto& d = args[0];

            SequenceDefinition seq{};
            seq.id = toLowerAscii(d.get("id").asString());
            seq.name = d.get("name").asString();
            if (seq.id.empty()) {
                seq.id = sanitizeIdFromName(seq.name, virtualPath);
            }
            if (seq.name.empty()) {
                seq.name = seq.id;
            }
            seq.category = d.get("category", Value("MIDI_SEQ")).asString();
            seq.subCategory = d.get("sub_category").asString();
            seq.description = d.get("description").asString();

            if (d.hasKey("tags")) {
                const Value& t = d.get("tags");
                if (t.isString()) {
                    seq.tags = t.asString();
                } else if (t.isList()) {
                    std::ostringstream ts;
                    for (size_t i = 0; i < t.listVal.size(); ++i) {
                        if (i > 0) ts << ", ";
                        ts << t.listVal[i].asString();
                    }
                    seq.tags = ts.str();
                }
            }

            if (d.hasKey("color") && d.get("color").isList() && d.get("color").listVal.size() >= 3) {
                seq.colorR = d.get("color").listVal[0].asFloat(0.0f);
                seq.colorG = d.get("color").listVal[1].asFloat(0.90f);
                seq.colorB = d.get("color").listVal[2].asFloat(0.46f);
            }

            if (d.hasKey("events")) {
                seq.eatscriptCode = serializeSequenceEvents(d.get("events"));
            }

            outResult.sequences.push_back(std::move(seq));
            return Value(true);
        });

    // eats.define_macro({...})
    ev.registerMemberFunction("eats", "define_macro",
        [&](const std::vector<Value>& args, const std::map<std::string, Value>&) -> Value {
            if (args.empty() || !args[0].isDict()) return Value(false);
            const auto& d = args[0];

            MacroDefinition macro{};
            macro.id = toLowerAscii(d.get("id").asString());
            macro.name = d.get("name").asString();
            if (macro.id.empty()) {
                macro.id = sanitizeIdFromName(macro.name, virtualPath);
            }
            if (macro.name.empty()) {
                macro.name = macro.id;
            }
            macro.category = d.get("category", Value("projectAction")).asString();
            macro.description = d.get("description").asString();

            if (d.hasKey("run") && d.get("run").isString()) {
                macro.scriptCode = d.get("run").asString();
            } else {
                macro.scriptCode = source;
            }

            if (d.hasKey("params")) {
                Value paramsVal = d.get("params");
                if (paramsVal.isFunction()) {
                    paramsVal = ev.invokeCallable(paramsVal);
                }
                if (paramsVal.isDict()) {
                    for (const auto& [key, pVal] : paramsVal.dictVal) {
                        if (!pVal.isDict()) continue;
                        MacroParamDef mp{};
                        mp.key = key;
                        mp.label = pVal.get("name", Value(key)).asString();
                        mp.minVal = pVal.get("min", Value(0.0)).asFloat(0.0f);
                        mp.maxVal = pVal.get("max", Value(1.0)).asFloat(1.0f);
                        mp.defaultVal = pVal.get("default", Value(mp.minVal)).asFloat(mp.minVal);
                        mp.step = pVal.get("step", Value(0.01)).asFloat(0.01f);

                        if (pVal.hasKey("options") && pVal.get("options").isList()) {
                            mp.type = MacroParamType::Choice;
                            for (const auto& opt : pVal.get("options").listVal) {
                                mp.options.push_back(opt.asString());
                            }
                        } else if (mp.step >= 1.0f) {
                            mp.type = MacroParamType::IntStep;
                        } else {
                            mp.type = MacroParamType::Slider;
                        }
                        macro.params.push_back(std::move(mp));
                    }
                }
            }

            outResult.macros.push_back(std::move(macro));
            return Value(true);
        });

    ev.evaluateSource(source);
    if (!ev.getLastError().empty()) {
        outResult.ok = false;
        outResult.error = ev.getLastError();
        return false;
    }

    outResult.ok = outResult.hasAnyAsset();
    return outResult.ok;
}

} // namespace eatsbeats::project
