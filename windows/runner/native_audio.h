#ifndef EATSBITS_NATIVE_AUDIO_H
#define EATSBITS_NATIVE_AUDIO_H

#ifdef __cplusplus
extern "C" {
#endif

__declspec(dllexport) void EatsAudio_Init();
__declspec(dllexport) void EatsAudio_Shutdown();
__declspec(dllexport) void EatsAudio_SetMasterVolume(float volume);
__declspec(dllexport) void EatsAudio_PlayBuffer(const float* samples, int count, float volume, float pan, const char* trackId, int isMonophonic);
__declspec(dllexport) void EatsAudio_StopTrackNotes(const char* trackId);

#ifdef __cplusplus
}
#endif

#endif // EATSBITS_NATIVE_AUDIO_H
