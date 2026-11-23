#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioToolbox.h>
#import "anime_voice.h"
#import "fishhook.h"

static AnimeVoiceState* g_state = NULL;
static AnimeVoiceParams g_params = {1.2f, 0.35f, 0.15f, 1.2f, true};
static BOOL g_enabled = YES;

static OSStatus (*orig_AudioUnitRender)(AudioUnit inUnit, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inOutputBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData);

static OSStatus my_AudioUnitRender(AudioUnit inUnit, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inOutputBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData) {
    OSStatus status = orig_AudioUnitRender(inUnit, ioActionFlags, inTimeStamp, inOutputBusNumber, inNumberFrames, ioData);

    if (status == noErr && g_enabled && g_state && ioData) {
        for (UInt32 i = 0; i < ioData->mNumberBuffers; i++) {
            AudioBuffer *buffer = &ioData->mBuffers[i];
            
            if (buffer->mData && buffer->mDataByteSize > 0) {
                float *samples = (float *)buffer->mData;
                UInt32 frames = buffer->mDataByteSize / sizeof(float);
                
                float *tempOut = (float *)malloc(buffer->mDataByteSize);
                uint32_t produced = anime_voice_process(g_state, samples, frames, tempOut, frames, &g_params);
                
                memcpy(samples, tempOut, produced * sizeof(float));
                if (frames > produced) {
                    memset(samples + produced, 0, (frames - produced) * sizeof(float));
                }
                free(tempOut);
            }
        }
    }
    return status;
}

@interface AnimeOverlayWindow : UIWindow
@end
@implementation AnimeOverlayWindow
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hitView = [super hitTest:point withEvent:event];
    if (hitView == self || hitView == self.rootViewController.view) return nil;
    return hitView;
}
@end

@interface AnimeViewController : UIViewController
@property (nonatomic, strong) UIView *panelView;
@property (nonatomic, strong) UIButton *floatingBtn;
@end

@implementation AnimeViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];

    self.floatingBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.floatingBtn.frame = CGRectMake(20, 100, 60, 60);
    self.floatingBtn.backgroundColor = [UIColor systemPinkColor];
    self.floatingBtn.layer.cornerRadius = 30;
    [self.floatingBtn setTitle:@"🎙️" forState:UIControlStateNormal];
    self.floatingBtn.titleLabel.font = [UIFont systemFontOfSize:30];
    [self.floatingBtn addTarget:self action:@selector(togglePanel) forControlEvents:UIControlEventTouchUpInside];
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragBtn:)];
    [self.floatingBtn addGestureRecognizer:pan];
    [self.view addSubview:self.floatingBtn];

    self.panelView = [[UIView alloc] initWithFrame:CGRectMake(20, 170, 250, 220)];
    self.panelView.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.8];
    self.panelView.layer.cornerRadius = 15;
    self.panelView.hidden = YES;
    [self.view addSubview:self.panelView];

    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(15, 15, 150, 30)];
    title.text = @"Anime Voice Pro";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:18];
    [self.panelView addSubview:title];

    UISwitch *onOff = [[UISwitch alloc] initWithFrame:CGRectMake(180, 15, 50, 30)];
    onOff.onTintColor = [UIColor systemPinkColor];
    onOff.on = g_enabled;
    [onOff addTarget:self action:@selector(toggleVoice:) forControlEvents:UIControlEventValueChanged];
    [self.panelView addSubview:onOff];

    [self addSlider:@"Pitch (Độ cao)" y:60 min:0.5 max:2.0 value:g_params.pitch_shift action:@selector(pitchChanged:)];
    [self addSlider:@"Reverb (Vang)" y:110 min:0.0 max:1.0 value:g_params.reverb_level action:@selector(reverbChanged:)];
    [self addSlider:@"Brightness (Trong)" y:160 min:0.0 max:1.0 value:g_params.brightness action:@selector(brightChanged:)];
}

- (void)addSlider:(NSString*)name y:(CGFloat)y min:(float)min max:(float)max value:(float)val action:(SEL)action {
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(15, y, 100, 20)];
    lbl.text = name; lbl.textColor = [UIColor whiteColor]; lbl.font = [UIFont systemFontOfSize:12];
    [self.panelView addSubview:lbl];
    
    UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(15, y+20, 220, 30)];
    slider.minimumValue = min; slider.maximumValue = max; slider.value = val;
    slider.tintColor = [UIColor systemPinkColor];
    [slider addTarget:self action:action forControlEvents:UIControlEventValueChanged];
    [self.panelView addSubview:slider];
}

- (void)dragBtn:(UIPanGestureRecognizer *)pan {
    CGPoint p = [pan locationInView:self.view];
    self.floatingBtn.center = p;
}
- (void)togglePanel {
    self.panelView.hidden = !self.panelView.hidden;
}
- (void)toggleVoice:(UISwitch *)sender { g_enabled = sender.isOn; }
- (void)pitchChanged:(UISlider *)sender { g_params.pitch_shift = sender.value; }
- (void)reverbChanged:(UISlider *)sender { g_params.reverb_level = sender.value; }
- (void)brightChanged:(UISlider *)sender { g_params.brightness = sender.value; }
@end

__attribute__((constructor)) static void anime_voice_tweak_init() {
    g_state = anime_voice_create(44100);

    rebind_symbols((struct rebinding[1]){
        {"AudioUnitRender", (void *)my_AudioUnitRender, (void **)&orig_AudioUnitRender}
    }, 1);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        static AnimeOverlayWindow *overlay;
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    overlay = [[AnimeOverlayWindow alloc] initWithWindowScene:scene];
                    break;
                }
            }
        }
        if (!overlay) overlay = [[AnimeOverlayWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        
        overlay.windowLevel = UIWindowLevelStatusBar + 100;
        overlay.hidden = NO;
        overlay.rootViewController = [[AnimeViewController alloc] init];
    });
}