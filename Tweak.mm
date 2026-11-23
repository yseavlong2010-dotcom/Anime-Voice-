#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioToolbox.h>
#import "anime_voice.h"
#import "fishhook.h"

static AnimeVoiceState* g_state = NULL;
static AnimeVoiceParams g_params = {1.2f, 0.35f, 0.15f, 1.2f, true, 0.01f, 0.0f};
static BOOL g_enabled = YES;

static OSStatus (*orig_AudioUnitRender)(AudioUnit inUnit, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inOutputBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData);

static OSStatus my_AudioUnitRender(AudioUnit inUnit, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inOutputBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData) {
    OSStatus status = orig_AudioUnitRender(inUnit, ioActionFlags, inTimeStamp, inOutputBusNumber, inNumberFrames, ioData);
    
    if (status == noErr && g_enabled && g_state && ioData && inNumberFrames <= 4096) {
        for (UInt32 i = 0; i < ioData->mNumberBuffers; i++) {
            AudioBuffer *buffer = &ioData->mBuffers[i];
            if (buffer->mData && buffer->mDataByteSize > 0) {
                float *samples = (float *)buffer->mData;
                UInt32 frames = buffer->mDataByteSize / sizeof(float);
                
                if (frames > 4096) continue;
                
                // Fix C++ VLA Warning: Cấp phát mảng tĩnh với kích thước tối đa đã biết
                float tempOut[4096];
                
                uint32_t produced = anime_voice_process(g_state, samples, frames, tempOut, frames, &g_params);
                
                memcpy(samples, tempOut, produced * sizeof(float));
                if (frames > produced) {
                    memset(samples + produced, 0, (frames - produced) * sizeof(float));
                }
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
@property (nonatomic, strong) UIVisualEffectView *panelView;
@property (nonatomic, strong) UIButton *floatingBtn;
@property (nonatomic, strong) NSMutableArray<UISlider*> *sliders;
@end

@implementation AnimeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    self.sliders = [NSMutableArray array];
    
    self.floatingBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.floatingBtn.frame = CGRectMake(20, 100, 50, 50);
    self.floatingBtn.backgroundColor = [[UIColor systemPinkColor] colorWithAlphaComponent:0.9];
    self.floatingBtn.layer.cornerRadius = 25;
    self.floatingBtn.layer.shadowColor = [UIColor blackColor].CGColor;
    self.floatingBtn.layer.shadowOpacity = 0.3;
    self.floatingBtn.layer.shadowOffset = CGSizeMake(0, 2);
    [self.floatingBtn setTitle:@"🎙️" forState:UIControlStateNormal];
    self.floatingBtn.titleLabel.font = [UIFont systemFontOfSize:24];
    [self.floatingBtn addTarget:self action:@selector(togglePanel) forControlEvents:UIControlEventTouchUpInside];
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(dragBtn:)];
    [self.floatingBtn addGestureRecognizer:pan];
    [self.view addSubview:self.floatingBtn];
    
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    self.panelView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    self.panelView.frame = CGRectMake(20, 160, 260, 310);
    self.panelView.layer.cornerRadius = 15;
    self.panelView.clipsToBounds = YES;
    self.panelView.hidden = YES;
    [self.view addSubview:self.panelView];
    
    UILabel *title = [[UILabel alloc] initWithFrame:CGRectMake(15, 15, 150, 30)];
    title.text = @"AnimeVoice Pro";
    title.textColor = [UIColor whiteColor];
    title.font = [UIFont boldSystemFontOfSize:18];
    [self.panelView.contentView addSubview:title];
    
    UISwitch *onOff = [[UISwitch alloc] initWithFrame:CGRectMake(195, 15, 50, 30)];
    onOff.onTintColor = [UIColor systemPinkColor];
    onOff.on = g_enabled;
    [onOff addTarget:self action:@selector(toggleVoice:) forControlEvents:UIControlEventValueChanged];
    [self.panelView.contentView addSubview:onOff];
    
    UISegmentedControl *presetCtrl = [[UISegmentedControl alloc] initWithItems:@[@"Default", @"Loli", @"Deep"]];
    presetCtrl.frame = CGRectMake(15, 55, 230, 30);
    presetCtrl.selectedSegmentIndex = 0;
    [presetCtrl addTarget:self action:@selector(presetChanged:) forControlEvents:UIControlEventValueChanged];
    [self.panelView.contentView addSubview:presetCtrl];
    
    [self addSlider:@"Pitch (Giọng cao/thấp)" y:95 min:0.5 max:2.0 value:g_params.pitch_shift tag:0];
    [self addSlider:@"Reverb (Độ vang)" y:140 min:0.0 max:1.0 value:g_params.reverb_level tag:1];
    [self addSlider:@"Gate (Lọc tiếng ồn)" y:185 min:0.0 max:0.1 value:g_params.noise_gate tag:2];
    [self addSlider:@"Chorus (Làm ảo giọng)" y:230 min:0.0 max:1.0 value:g_params.chorus_depth tag:3];
}

- (void)addSlider:(NSString*)name y:(CGFloat)y min:(float)min max:(float)max value:(float)val tag:(NSInteger)tag {
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(15, y, 200, 15)];
    lbl.text = name; lbl.textColor = [UIColor lightGrayColor]; lbl.font = [UIFont systemFontOfSize:11];
    [self.panelView.contentView addSubview:lbl];
    
    UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(15, y+15, 230, 30)];
    slider.minimumValue = min; slider.maximumValue = max; slider.value = val;
    slider.tag = tag;
    slider.tintColor = [UIColor systemPinkColor];
    [slider addTarget:self action:@selector(sliderChanged:) forControlEvents:UIControlEventValueChanged];
    [self.panelView.contentView addSubview:slider];
    [self.sliders addObject:slider];
}

- (void)presetChanged:(UISegmentedControl *)sender {
    if (sender.selectedSegmentIndex == 0) {
        g_params.pitch_shift = 1.2f; g_params.reverb_level = 0.15f; g_params.noise_gate = 0.01f; g_params.chorus_depth = 0.0f;
    } else if (sender.selectedSegmentIndex == 1) {
        g_params.pitch_shift = 1.6f; g_params.reverb_level = 0.3f; g_params.noise_gate = 0.02f; g_params.chorus_depth = 0.2f;
    } else if (sender.selectedSegmentIndex == 2) {
        g_params.pitch_shift = 0.7f; g_params.reverb_level = 0.1f; g_params.noise_gate = 0.01f; g_params.chorus_depth = 0.1f;
    }
    
    for (UISlider *s in self.sliders) {
        if (s.tag == 0) s.value = g_params.pitch_shift;
        if (s.tag == 1) s.value = g_params.reverb_level;
        if (s.tag == 2) s.value = g_params.noise_gate;
        if (s.tag == 3) s.value = g_params.chorus_depth;
    }
}

- (void)sliderChanged:(UISlider *)sender {
    if (sender.tag == 0) g_params.pitch_shift = sender.value;
    if (sender.tag == 1) g_params.reverb_level = sender.value;
    if (sender.tag == 2) g_params.noise_gate = sender.value;
    if (sender.tag == 3) g_params.chorus_depth = sender.value;
}

- (void)dragBtn:(UIPanGestureRecognizer *)pan {
    CGPoint p = [pan locationInView:self.view];
    self.floatingBtn.center = p;
}

- (void)togglePanel {
    self.panelView.hidden = !self.panelView.hidden;
}

- (void)toggleVoice:(UISwitch *)sender {
    g_enabled = sender.isOn;
}

@end

@interface AnimeVoiceLoader : NSObject
@end

@implementation AnimeVoiceLoader
+ (void)load {
    g_state = anime_voice_create(44100);
    rebind_symbols((struct rebinding[1]){
        {"AudioUnitRender", (void*)my_AudioUnitRender, (void**)&orig_AudioUnitRender}
    }, 1);
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification 
                                                      object:nil 
                                                       queue:[NSOperationQueue mainQueue] 
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        (void)note; // Fix Warning unused parameter
        static AnimeOverlayWindow *overlay = nil;
        if (overlay) return; 
        
        UIWindowScene *activeScene = nil;
        if (@available(iOS 13.0, *)) {
            for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    activeScene = scene;
                    break;
                }
            }
        }
        
        if (activeScene) {
            overlay = [[AnimeOverlayWindow alloc] initWithWindowScene:activeScene];
        } else {
            overlay = [[AnimeOverlayWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        }
        
        overlay.windowLevel = UIWindowLevelStatusBar + 100;
        overlay.backgroundColor = [UIColor clearColor]; 
        overlay.hidden = NO;
        overlay.rootViewController = [[AnimeViewController alloc] init];
    }];
}
@end