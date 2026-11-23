#include "anime_voice.h"
#include <stdlib.h>
#include <math.h>
#if defined(GNUC)
#define EXPORT attribute((visibility("default")))
#else
#define EXPORT
#endif
// Kích thước bộ đệm reverb (~92ms ở 44.1kHz)
#define DELAY_BUFFER_SIZE 4096
struct AnimeVoiceState {
int sample_rate;
float prev_sample;
float delay_buffer[DELAY_BUFFER_SIZE];
int delay_index;
};
EXPORT AnimeVoiceState* anime_voice_create(int sample_rate) {
AnimeVoiceState* state = (AnimeVoiceState*)malloc(sizeof(AnimeVoiceState));
if (!state) return NULL;
state->sample_rate = sample_rate > 0 ? sample_rate : 44100;
state->prev_sample = 0.0f;
state->delay_index = 0;
for(int i = 0; i < DELAY_BUFFER_SIZE; i++) {
state->delay_buffer[i] = 0.0f;
}
return state;
}
EXPORT void anime_voice_destroy(AnimeVoiceState* state) {
if (state) free(state);
}
EXPORT const char *anime_voice_version(void) {
return "AnimeVoice Pro v2.0 - Optimized DSP";
}
// Soft clipper (thuật toán Tanh approximation)
static inline float soft_clip(float x) {
if (x < -3.0f) return -1.0f;
if (x > 3.0f) return 1.0f;
return x * (27.0f + x * x) / (27.0f + 9.0f * x * x);
}
EXPORT uint32_t anime_voice_process(AnimeVoiceState* state,
const float *input,
uint32_t input_frames,
float output,
uint32_t output_capacity,
const AnimeVoiceParams params) {
if (!state || !input || !output || input_frames < 2 || output_capacity == 0 || !params) return 0;
// 1. Safety clamps
float pitch = params->pitch_shift;
if (pitch < 0.5f) pitch = 0.5f;
if (pitch > 2.0f) pitch = 2.0f;
float brightness = params->brightness;
if (brightness < 0.0f) brightness = 0.0f;
if (brightness > 1.0f) brightness = 1.0f;
float reverb = params->reverb_level;
if (reverb < 0.0f) reverb = 0.0f;
if (reverb > 1.0f) reverb = 1.0f;
float vol = params->volume_boost;
if (vol < 0.0f) vol = 0.0f;
uint32_t produced = (uint32_t)((float)(input_frames - 1) / pitch);
if (produced > output_capacity) produced = output_capacity;
// 2. DSP Loop
for (uint32_t i = 0; i < produced; ++i) {
float position = (float)i * pitch;
uint32_t index = (uint32_t)position;
float fraction = position - (float)index;
if (index + 1 >= input_frames) break;
// Linear Interpolation
float sample = input[index] + (input[index + 1] - input[index]) * fraction;
// Brightness EQ
float emphasized = sample + brightness * (sample - state->prev_sample);
state->prev_sample = sample;
// Reverb Effect
float delayed_sample = state->delay_buffer[state->delay_index];
float reverb_out = emphasized + (delayed_sample * 0.5f);
state->delay_buffer[state->delay_index] = emphasized + (delayed_sample * 0.3f);
state->delay_index = (state->delay_index + 1) % DELAY_BUFFER_SIZE;
// Mix
float final_sample = emphasized * (1.0f - reverb) + reverb_out * reverb;
// Volume & Anti-clipping
final_sample *= vol;
if (params->enable_soft_clip) {
final_sample = soft_clip(final_sample);
} else {
if (final_sample > 1.0f) final_sample = 1.0f;
if (final_sample < -1.0f) final_sample = -1.0f;
}
output[i] = final_sample;
}
return produced;
}