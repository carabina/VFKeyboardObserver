/*
 
 Copyright 2013 Valery Fomenko
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 
 */

#import "VFKeyboardObserver.h"

VFKeyboardProperties VFKeyboardPropertiesMake(CGSize size,
                                              NSTimeInterval animationDuration,
                                              UIViewAnimationCurve animationCurve);

@implementation VFKeyboardObserver {
    NSHashTable *_delegates;
    BOOL _interfaceOrientationWillChange;
}

+ (instancetype)sharedKeyboardObserver {
    static VFKeyboardObserver *sharedKeyboardObserver;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        sharedKeyboardObserver = [VFKeyboardObserver new];
    });
    return sharedKeyboardObserver;
}

- (instancetype)init {
    self = [super init];
    _delegates = [NSHashTable weakObjectsHashTable];
    return self;
}

- (void)start {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardDidShow:)
                                                 name:UIKeyboardDidShowNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardDidHide:)
                                                 name:UIKeyboardDidHideNotification object:nil];
}

- (void)dealloc {
    [self stop];
}

- (void)stop {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)addDelegate:(id<VFKeyboardObserverDelegate>)delegate {
    [_delegates addObject:delegate];
}

- (void)removeDelegate:(id<VFKeyboardObserverDelegate>)delegate {
    [_delegates removeObject:delegate];
}

- (void)interfaceOrientationWillChange {
    if (self.keyboardXShow) {
        _interfaceOrientationWillChange = YES;
    }
}

- (void)animateWithKeyboardProperties:(void(^)())animations {
    [self animateWithKeyboardProperties:animations completion:nil];
}

- (void)animateWithKeyboardProperties:(void(^)())animations completion:(void (^)(BOOL finished))completion {
    if (_interfaceOrientationWillChange) {
        if (animations) {animations();}
        if (completion) {completion(YES);}
        
    } else {
        
        [UIView animateWithDuration:_lastKeyboardProperties.animationDuration
                              delay:0.0
                            options:_lastKeyboardProperties.animationCurve << 16
                         animations:animations completion:completion];
    }
}

- (BOOL)keyboardXShow {
    return _keyboardWillShow || _keyboardDidShow;
}

- (BOOL)keyboardXHide {
    return _keyboardWillHide || _keyboardDidHide;
}

- (void)keyboardWillShow:(NSNotification *)notification {
    [self setKeyboardWillShow:YES];
    [self updateKeyboardPropertiesWithNotification:notification];
    [self notifyKeyboardWillShow];
    
    if (_interfaceOrientationWillChange) {
        _interfaceOrientationWillChange = NO;
    }
}

- (void)keyboardDidShow:(NSNotification *)notification {
    [self setKeyboardDidShow:YES];
    [self notifyKeyboardDidShow];
}

- (void)keyboardWillHide:(NSNotification *)notification {
    if (_interfaceOrientationWillChange) {
        return;
    }
    
    [self setKeyboardWillHide:YES];
    [self updateKeyboardPropertiesWithNotification:notification];
    [self notifyKeyboardWillHide];
}

- (void)keyboardDidHide:(NSNotification *)notification {
    if (_interfaceOrientationWillChange) {
        return;
    }
    
    [self setKeyboardDidHide:YES];
    [self notifyKeyboardDidHide];
}

- (void)setKeyboardWillShow:(BOOL)keyboardWillShow {
    _keyboardWillShow = keyboardWillShow;
    
    if (_keyboardWillShow) {
        _keyboardDidHide = NO;
    }
}

- (void)setKeyboardDidShow:(BOOL)keyboardDidShow {
    _keyboardDidShow = keyboardDidShow;
    
    if (_keyboardDidShow) {
        _keyboardWillShow = NO;
    }
}

- (void)setKeyboardWillHide:(BOOL)keyboardWillHide {
    _keyboardWillHide = keyboardWillHide;
    
    if (_keyboardWillHide) {
        _keyboardDidShow = NO;
    }
}

- (void)setKeyboardDidHide:(BOOL)keyboardDidHide {
    _keyboardDidHide = keyboardDidHide;
    
    if (_keyboardDidHide) {
        _keyboardWillHide = NO;
    }
}

- (void)notifyKeyboardWillShow {
    for (id<VFKeyboardObserverDelegate> delegate in [_delegates allObjects]) {
        if ([delegate respondsToSelector:@selector(keyboardObserver:observeKeyboardWillShowWithProperties:interfaceOrientationWillChange:)]) {
            [delegate keyboardObserver:self observeKeyboardWillShowWithProperties:_lastKeyboardProperties interfaceOrientationWillChange:_interfaceOrientationWillChange];
        }
    }
}

- (void)notifyKeyboardDidShow {
    for (id<VFKeyboardObserverDelegate> delegate in [_delegates allObjects]) {
        if ([delegate respondsToSelector:@selector(keyboardObserver:observeKeyboardDidShowWithProperties:)]) {
            [delegate keyboardObserver:self observeKeyboardDidShowWithProperties:_lastKeyboardProperties];
        }
    }
}

- (void)notifyKeyboardWillHide {
    for (id<VFKeyboardObserverDelegate> delegate in [_delegates allObjects]) {
        if ([delegate respondsToSelector:@selector(keyboardObserver:observeKeyboardWillHideWithProperties:)]) {
            [delegate keyboardObserver:self observeKeyboardWillHideWithProperties:_lastKeyboardProperties];
        }
    }
}

- (void)notifyKeyboardDidHide {
    for (id<VFKeyboardObserverDelegate> delegate in [_delegates allObjects]) {
        if ([delegate respondsToSelector:@selector(keyboardObserver:observeKeyboardDidHideWithProperties:)]) {
            [delegate keyboardObserver:self observeKeyboardDidHideWithProperties:_lastKeyboardProperties];
        }
    }
}

- (void)updateKeyboardPropertiesWithNotification:(NSNotification *)notification {
    CGSize size = [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].size;
    if (UIInterfaceOrientationIsLandscape([UIApplication sharedApplication].statusBarOrientation)) {
        size = CGSizeMake(size.height, size.width);
    }
    
    NSTimeInterval animationDuration = [[[notification userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    UIViewAnimationCurve animationCurve = [[[notification userInfo] objectForKey:UIKeyboardAnimationCurveUserInfoKey] integerValue];
    _lastKeyboardProperties = VFKeyboardPropertiesMake(size, animationDuration, animationCurve);
}

@end

VFKeyboardProperties VFKeyboardPropertiesMake(CGSize size,
                                              NSTimeInterval animationDuration,
                                              UIViewAnimationCurve animationCurve) {
    VFKeyboardProperties keyboardProperties;
    keyboardProperties.size = size;
    keyboardProperties.animationDuration = animationDuration;
    keyboardProperties.animationCurve = animationCurve;
    return keyboardProperties;
}

NSString *NSStringFromVFKeyboardProperties(VFKeyboardProperties keyboardProperties) {
    return [NSString stringWithFormat:@"VFKeyboardProperties (size: %@; animationDuration:%f; animationCurve:%d)",
            NSStringFromCGSize(keyboardProperties.size),
            keyboardProperties.animationDuration,
            keyboardProperties.animationCurve];
}