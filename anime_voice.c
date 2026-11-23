#include "anime_voice.h"
#include <stdlib.h>
#include <math.h>
#include <Accelerate/Accelerate.h>

#if defined(__GNUC__)
#define EXPORT __attribute__((visibility("default")))
#else
#define EXPORT
#endif

#define DELAY_BUFFER_SIZE 4096

struct AnimeVoiceState {
    int sample_rate;
    float prev_sample;
    float delay_buffer[DELAY_BUFFER_SIZE];
    int delay_index;
    float lfo_phase;
};

EXPORT AnimeVoiceState* anime_voice_create(int sample_rate) {
    AnimeVoiceState* state = (AnimeVoiceState*)calloc(1, sizeof(AnimeVoiceState));
    if (!state) return NULL;
    state->sample_rate = sample_rate > 0 ? sample_rate : 44100;
    return state;
}

EXPORT void anime_voice_destroy(AnimeVoiceState* state) {
    if (state) free(state);
}

EXPORT const char *anime_voice_version(void) {
    return "AnimeVoice Pro v3.0 - Ultimate DSP Edition";
}

static inline float soft_clip(float x) {
    if (x < -3.0f) return -1.0f;
    if (x > 3.0f) return 1.0f;
    return x * (27.0f + x * x) / (27.0f + 9.0f * x * x);
}

EXPORT uint32_t anime_voice_process(AnimeVoiceState* state,
                                    const float *input,
                                    uint32_t input_frames,
                                    float *output,
                                    uint32_t output_capacity,
                                    const AnimeVoiceParams *params) {
    if (!state || !input || !output || input_frames < 2 || output_capacity == 0 || !params) return 0;

    float pitch = params->pitch_shift;
    if (pitch < 0.5f) pitch = 0.5f;
    if (pitch > 2.0f) pitch = 2.0f;
    
    float brightness = params->brightness;
    float reverb = params->reverb_level;
    float vol = params->volume_boost;
    float gate = params->noise_gate;
    float chorus = params->chorus_depth;

    uint32_t produced = (uint32_t)((float)(input_frames - 1) / pitch);
    if (produced > output_capacity) produced = output_capacity;

    for (uint32_t i = 0; i < produced; ++i) {
        float position = (float)i * pitch;
        uint32_t index = (uint32_t)position;
        float fraction = position - (float)index;
        
        if (index + 1 >= input_frames) break;

        float sample = input[index] + (input[index + 1] - input[index]) * fraction;
        
        // Khử ồn (Noise Gate)
        if (fabsf(sample) < gate) {
            sample *= 0.1f;
        }

        // Tăng độ sáng (High-pass/Brightness)
        float emphasized = sample + brightness * (sample - state->prev_sample);
        state->prev_sample = sample;

        // Xử lý LFO cho Chorus
        state->lfo_phase += 0.005f;
        if (state->lfo_phase > M_PI * 2.0f) state->lfo_phase -= M_PI * 2.0f;
        int chorus_offset = (int)((sinf(state->lfo_phase) * 0.5f + 0.5f) * 100.0f * chorus);
        
        // Đọc Reverb & Chorus từ buffer
        int read_index = (state->delay_index - 1000 - chorus_offset + DELAY_BUFFER_SIZE) % DELAY_BUFFER_SIZE;
        float delayed_sample = state->delay_buffer[read_index];
        float reverb_out = emphasized + (delayed_sample * 0.5f);
        
        // Cập nhật Delay buffer
        state->delay_buffer[state->delay_index] = emphasized + (delayed_sample * 0.3f);
        state->delay_index = (state->delay_index + 1) % DELAY_BUFFER_SIZE;

        // Mix cuối
        float final_sample = emphasized * (1.0f - reverb) + reverb_out * reverb;
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