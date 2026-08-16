#pragma warning(disable: 4244)
#pragma warning(disable: 4577)
#pragma warning(disable: 4456)
#pragma warning(disable: 4324)

#define MINIAUDIO_IMPLEMENTATION
#include "miniaudio.h"
#include "native_audio.h"

#include <vector>
#include <mutex>
#include <string>
#include <algorithm>
#include <cstring>
#include <iostream>

struct NativeVoice {
    std::vector<float> samples;
    float volume;
    float pan;
    std::string trackId;
    bool isMonophonic;
    size_t cursor = 0;
};

static ma_device g_audioDevice;
static bool g_deviceInitialized = false;
static std::vector<NativeVoice> g_voices;
static std::mutex g_audioMutex;
static float g_masterVolume = 1.0f;

static void data_callback(ma_device* pDevice, void* pOutput, const void* pInput, ma_uint32 frameCount) {
    float* pOut = (float*)pOutput;
    if (!pOut) return;

    std::lock_guard<std::mutex> lock(g_audioMutex);

    for (ma_uint32 i = 0; i < frameCount; ++i) {
        float leftSum = 0.0f;
        float rightSum = 0.0f;

        for (int v = (int)g_voices.size() - 1; v >= 0; --v) {
            auto& voice = g_voices[v];
            if (voice.cursor < voice.samples.size()) {
                float s = voice.samples[voice.cursor++];
                float panVal = voice.pan < -1.0f ? -1.0f : (voice.pan > 1.0f ? 1.0f : voice.pan);
                float leftPan = panVal <= 0.0f ? 1.0f : (1.0f - panVal);
                float rightPan = panVal >= 0.0f ? 1.0f : (1.0f + panVal);

                leftSum += s * leftPan * voice.volume;
                rightSum += s * rightPan * voice.volume;
            } else {
                g_voices.erase(g_voices.begin() + v);
            }
        }

        float lClamped = leftSum * g_masterVolume;
        float rClamped = rightSum * g_masterVolume;

        if (lClamped > 1.0f) lClamped = 1.0f;
        if (lClamped < -1.0f) lClamped = -1.0f;
        if (rClamped > 1.0f) rClamped = 1.0f;
        if (rClamped < -1.0f) rClamped = -1.0f;

        pOut[i * 2]     = lClamped;
        pOut[i * 2 + 1] = rClamped;
    }
}

void EatsAudio_Init() {
    if (g_deviceInitialized) return;

    ma_device_config deviceConfig = ma_device_config_init(ma_device_type_playback);
    deviceConfig.playback.format   = ma_format_f32;
    deviceConfig.playback.channels = 2;
    deviceConfig.sampleRate        = 44100;
    deviceConfig.dataCallback      = data_callback;
    deviceConfig.periodSizeInFrames = 256; // 5.8ms WASAPI buffer size!

    if (ma_device_init(NULL, &deviceConfig, &g_audioDevice) == MA_SUCCESS) {
        ma_device_start(&g_audioDevice);
        g_deviceInitialized = true;
        std::cout << "EatsAudio: WASAPI low-latency audio device initialized successfully (5.8ms buffer size)." << std::endl;
    }
}

void EatsAudio_Shutdown() {
    if (g_deviceInitialized) {
        ma_device_uninit(&g_audioDevice);
        g_deviceInitialized = false;
    }
}

void EatsAudio_SetMasterVolume(float volume) {
    g_masterVolume = volume < 0.0f ? 0.0f : (volume > 1.5f ? 1.5f : volume);
}

void EatsAudio_PlayBuffer(const float* samples, int count, float volume, float pan, const char* trackId, int isMonophonic) {
    if (!samples || count <= 0) return;
    if (!g_deviceInitialized) EatsAudio_Init();

    std::lock_guard<std::mutex> lock(g_audioMutex);

    std::string tId = trackId ? trackId : "";
    if (isMonophonic && !tId.empty()) {
        g_voices.erase(
            std::remove_if(g_voices.begin(), g_voices.end(),
                [&tId](const NativeVoice& v) { return v.trackId == tId; }),
            g_voices.end());
    }

    NativeVoice voice;
    voice.samples.assign(samples, samples + count);
    voice.volume = volume;
    voice.pan = pan;
    voice.trackId = tId;
    voice.isMonophonic = (isMonophonic != 0);
    voice.cursor = 0;

    g_voices.push_back(std::move(voice));
}

void EatsAudio_StopTrackNotes(const char* trackId) {
    if (!trackId) return;
    std::lock_guard<std::mutex> lock(g_audioMutex);
    std::string tId = trackId;
    g_voices.erase(
        std::remove_if(g_voices.begin(), g_voices.end(),
            [&tId](const NativeVoice& v) { return v.trackId == tId; }),
        g_voices.end());
}
