#ifndef ANIME_VOICE_H
#define ANIME_VOICE_H
#include <stdint.h>
#include <stdbool.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct {
float pitch_shift;
float brightness;
float reverb_level;
float volume_boost;
bool enable_soft_clip;
} AnimeVoiceParams;
typedef struct AnimeVoiceState AnimeVoiceState;
AnimeVoiceState* anime_voice_create(int sample_rate);
uint32_t anime_voice_process(AnimeVoiceState* state,
const float *input,
uint32_t input_frames,
float *output,
uint32_t output_capacity,
const AnimeVoiceParams *params);
void anime_voice_destroy(AnimeVoiceState* state);
const char *anime_voice_version(void);
#ifdef __cplusplus
}
#endif
#endif