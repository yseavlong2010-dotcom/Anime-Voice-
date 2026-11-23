Makefile cho macOS / iOS GitHub Actions
CC = clang
CFLAGS = -O3 -Wall -Wextra -fPIC
LDFLAGS = -dynamiclib
Tự động nhận diện SDK iOS nếu có
IOS_SDK ?= $(shell xcrun --sdk iphoneos --show-sdk-path 2>/dev/null)
ARCH = arm64
TARGET = AnimeVoice_Pro.dylib
all: $(TARGET)
￼
￼(IOS_SDK)" ]; then 
￼(TARGET) anime_voice.c -o$(TARGET); 
echo "✅ Đã biên dịch thành công iOS dylib: $(TARGET)"; 
else 
￼(CFLAGS) (LDFLAGS) anime_voice.c -o(TARGET); 
echo "✅ Đã biên dịch thành công macOS dylib: $(TARGET) (Dùng để test nội bộ)"; 
fi
clean:
rm -f $(TARGET)