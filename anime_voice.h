#ifndef ANIME_VOICE_H
#define ANIME_VOICE_H
#include <stdint.h>
#include <stdbool.h>
#ifdef __cplusplus
extern "C" {
#endif
/
￼ Cấu hình thông số DSP cho AnimeVoice
*/
typedef struct {
float pitch_shift;      // Độ cao giọng: 1.0 = Bình thường, 1.2 = Giọng nữ/Anime, 0.8 = Giọng nam trầm.
float brightness;       // Độ sáng (EQ): 0.0 đến 1.0 (Tăng âm sắc trong trẻo).
float reverb_level;     // Độ vang (Reverb): 0.0 đến 1.0 (Tạo không gian mượt mà).
float volume_boost;     // Khuếch đại âm lượng: 1.0 = Chuẩn, >1.0 = Tăng âm.
bool enable_soft_clip;  // Bật/tắt chế độ Soft Clipping để chống rè (khuyên dùng: true).
} AnimeVoiceParams;
// Cấu trúc state nội bộ (ẩn) để xử lý âm thanh mượt mà
typedef struct AnimeVoiceState AnimeVoiceState;
/
￼ Khởi tạo bộ xử lý DSP
￼ @param sample_rate Tần số lấy mẫu (vd: 44100 hoặc 48000)
/
AnimeVoiceState anime_voice_create(int sample_rate);
/
￼ Xử lý một đoạn âm thanh (Chunk processing)
￼ @return Số lượng frame đã xử lý thành công.
/
uint32_t anime_voice_process(AnimeVoiceState state,
const float *input,
uint32_t input_frames,
float output,
uint32_t output_capacity,
const AnimeVoiceParams params);
/
￼ Giải phóng bộ nhớ DSP
/
void anime_voice_destroy(AnimeVoiceState state);
/
￼ Trả về thông tin phiên bản
*/
const char *anime_voice_version(void);
#ifdef __cplusplus
}
#endif
#endif // ANIME_VOICE_H