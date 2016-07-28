//
//  YOLayout.m
//  YOLayout
//
//  Created by Gabriel Handford on 10/29/13.
//  Copyright (c) 2014 YOLayout. All rights reserved.
//

#import "YOLayout_IMP.h"
#import "YOCGUtils.h"

@protocol YOView <NSObject>
- (CGRect)frame;
- (void)setFrame:(CGRect)frame;
- (NSArray *)subviews;
@end

const UIEdgeInsets UIEdgeInsetsZero = {0, 0, 0, 0};

@interface YOLayout ()
@property BOOL needsLayout;
@property BOOL needsSizing;
@property CGSize cachedSize;
@property CGSize cachedLayoutSize;
@end

@implementation YOLayout

- (id)init {
  if ((self = [super init])) {
    _needsLayout = YES;
    _needsSizing = YES;
  }
  return self;
}

- (id)initWithLayoutBlock:(YOLayoutBlock)layoutBlock {
  NSParameterAssert(layoutBlock);

  if ((self = [self init])) {
    _layoutBlock = layoutBlock;
  }
  return self;
}

+ (YOLayout *)layoutWithLayoutBlock:(YOLayoutBlock)layoutBlock {
  return [[YOLayout alloc] initWithLayoutBlock:layoutBlock];
}

- (CGSize)_layout:(CGSize)size sizing:(BOOL)sizing {
  if (YOCGSizeIsEqual(size, _cachedSize) && ((!_needsSizing && sizing) || (!_needsLayout && !sizing))) {
    return _cachedLayoutSize;
  }

  _sizing = sizing;
  _cachedSize = size;
  CGSize layoutSize = self.layoutBlock(self, size);
  _cachedLayoutSize = layoutSize;
  if (!_sizing) {
    _needsLayout = NO;
  }
  _needsSizing = NO;
  _sizing = NO;
  return layoutSize;
}

- (void)setNeedsLayout {
  _needsLayout = YES;
  _needsSizing = YES;
  _cachedSize = CGSizeZero;
}

- (CGSize)layoutSubviews:(CGSize)size {
  return [self _layout:size sizing:NO];
}

- (CGSize)sizeThatFits:(CGSize)size {
  if (_sizeThatFits.width > 0 && _sizeThatFits.height > 0) return _sizeThatFits;
  if (_sizeThatFits.width > 0) size = _sizeThatFits;
  return [self _layout:size sizing:YES];
}

- (CGSize)sizeThatFits:(CGSize)size view:(id)view options:(YOLayoutOptions)options {
  CGRect frame = [self size:size inRect:CGRectMake(0, 0, size.width, size.height) view:view options:options];
  return frame.size;
}

- (CGRect)sizeToFitVerticalInFrame:(CGRect)frame view:(id)view {
  return [self setFrame:frame view:view options:YOLayoutOptionsSizeToFitVertical];
}

- (CGRect)sizeToFitHorizontalInFrame:(CGRect)frame view:(id)view {
  return [self setFrame:frame view:view options:YOLayoutOptionsSizeToFitHorizontal];
}

- (CGRect)sizeToFitInFrame:(CGRect)frame view:(id)view {
  return [self setFrame:frame view:view options:YOLayoutOptionsSizeToFit];
}

- (CGRect)setFrame:(CGRect)frame view:(id)view options:(YOLayoutOptions)options {
  return [self setSize:frame.size inRect:frame view:view options:options];
}

- (CGRect)centerWithSize:(CGSize)size frame:(CGRect)frame view:(id)view {
  YOLayoutOptions options = YOLayoutOptionsAlignCenter;
  if (size.width == 0 || size.height == 0) options |= YOLayoutOptionsSizeToFit;
  return [self setSize:size inRect:frame view:view options:options];
}

- (CGRect)setSize:(CGSize)size inRect:(CGRect)inRect view:(id)view options:(YOLayoutOptions)options {
  CGRect frame = [self size:size inRect:inRect view:view options:options];
  [self setFrame:frame view:view];
  return frame;
}

- (CGRect)size:(CGSize)size inRect:(CGRect)inRect view:(id)view options:(YOLayoutOptions)options {
  CGSize originalSize = size;
  BOOL sizeToFit = ((options & YOLayoutOptionsSizeToFitHorizontal) != 0)
    || ((options & YOLayoutOptionsSizeToFitVertical) != 0);

  CGSize sizeThatFits = CGSizeZero;
  if (sizeToFit) {
    NSAssert([view respondsToSelector:@selector(sizeThatFits:)], @"sizeThatFits: must be implemented on %@ for use with YOLayoutOptionsSizeToFit", view);
    sizeThatFits = [view sizeThatFits:size];
    
    // If size that fits returns a larger width, then we'll need to constrain it.
    if (((options & YOLayoutOptionsConstrainWidth) != 0) && sizeThatFits.width > size.width) {
      sizeThatFits.width = size.width;
    }

    // If size that fits returns a larger height, then we'll need to constrain it.
    if (((options & YOLayoutOptionsConstrainHeight) != 0) && sizeThatFits.height > size.height) {
      sizeThatFits.height = size.height;
    }

    // If size that fits returns a larger width or height, constrain it, but also maintain the aspect ratio from sizeThatFits
    if (((options & YOLayoutOptionsConstrainSizeMaintainAspectRatio) != 0) && (sizeThatFits.height > size.height || sizeThatFits.width > size.width)) {
      CGFloat aspectRatio = sizeThatFits.width / sizeThatFits.height;
      // If we're going to constrain by width
      if (sizeThatFits.width / size.width > sizeThatFits.height / size.height) {
        sizeThatFits.width = size.width;
        sizeThatFits.height = roundf(size.width / aspectRatio);
        // If we're going to constrain by height
      } else {
        sizeThatFits.height = size.height;
        sizeThatFits.width = roundf(size.height * aspectRatio);
      }
    }

    if (sizeThatFits.width == 0 && ((options & YOLayoutOptionsDefaultWidth) != 0)) {
      sizeThatFits.width = size.width;
    }
    
    if (sizeThatFits.height == 0 && ((options & YOLayoutOptionsDefaultHeight) != 0)) {
      sizeThatFits.height = size.height;
    }

    size = sizeThatFits;
  }
  
  if ((options & YOLayoutOptionsSizeToFitHorizontal) == 0) {
    size.width = originalSize.width;
  }
  
  if ((options & YOLayoutOptionsSizeToFitVertical) == 0) {
    size.height = originalSize.height;
  }

  // If we passed in 0 for inRect height or width, then lets set it to the frame height or width.
  // This usually happens if we are sizing to fit, and is needed to align below.
  if (inRect.size.width == 0) inRect.size.width = size.width;
  if (inRect.size.height == 0) inRect.size.height = size.height;

  CGPoint p = inRect.origin;
  if ((options & YOLayoutOptionsAlignCenterHorizontal) != 0) {
    p.x += YOCGPointToCenterX(size, inRect.size).x;
  }

  if ((options & YOLayoutOptionsAlignCenterVertical) != 0) {
    p.y += YOCGPointToCenterY(size, inRect.size).y;
  }

  if ((options & YOLayoutOptionsAlignRight) != 0) {
    p.x = inRect.origin.x + inRect.size.width - size.width;
  }

  if ((options & YOLayoutOptionsAlignBottom) != 0) {
    p.y = inRect.origin.y + inRect.size.height - size.height;
  }

  CGRect frame = CGRectMake(p.x, p.y, size.width, size.height);
  return frame;
}

- (CGRect)setOrigin:(CGPoint)origin view:(id)view options:(YOLayoutOptions)options {
  return [self setFrame:CGRectMake(origin.x, origin.y, [view frame].size.width, [view frame].size.height) view:view options:options];
}

- (CGRect)setSize:(CGSize)size view:(id)view options:(YOLayoutOptions)options {
  return [self setFrame:CGRectMake([view frame].origin.x, [view frame].origin.y, size.width, size.height) view:view options:options];
}

- (CGRect)setFrame:(CGRect)frame view:(id)view {
  if (!view) return CGRectZero;
  if (!_sizing) {
    [view setFrame:frame];
    // Since we are applying the frame, the subview will need to re-layout
    if ([view respondsToSelector:@selector(setNeedsLayout)]) {
      [view setNeedsLayout];
    }
  }
  return frame;
}

#pragma mark -

+ (YOLayout *)fill:(id)subview {
  return [self layoutWithLayoutBlock:^CGSize(id<YOLayout> layout, CGSize size) {
    [layout setFrame:CGRectMake(0, 0, size.width, size.height) view:subview];
    return size;
  }];
}

+ (YOLayout *)center:(id)subview {
  return [self layoutWithLayoutBlock:^CGSize(id<YOLayout> layout, CGSize size) {
    CGSize sizeThatFits = [subview sizeThatFits:size];
    [layout centerWithSize:sizeThatFits frame:CGRectMake(0, 0, size.width, size.height) view:subview];
    return size;
  }];
}

+ (YOLayout *)fitVertical:(id)subview {
  return [self layoutWithLayoutBlock:^CGSize(id<YOLayout> layout, CGSize size) {
    CGFloat y = 0;
    y += [layout sizeToFitVerticalInFrame:CGRectMake(0, 0, size.width, size.height) view:subview].size.height;
    return CGSizeMake(size.width, y);
  }];
}

+ (YOLayout *)fitHorizontal:(id)subview {
  return [self layoutWithLayoutBlock:^CGSize(id<YOLayout> layout, CGSize size) {
    CGFloat x = 0;
    x += [layout sizeToFitHorizontalInFrame:CGRectMake(0, 0, size.width, size.height) view:subview].size.width;
    return CGSizeMake(x, size.height);
  }];
}

@end

NSString *YONSStringFromCGRect(CGRect rect) {
  return [NSString stringWithFormat:@"(%@, %@, %@, %@)", @(rect.origin.x), @(rect.origin.y), @(rect.size.width), @(rect.size.height)];
}

NSString *YONSStringFromCGSize(CGSize size) {
  return [NSString stringWithFormat:@"(%@, %@)", @(size.width), @(size.height)];
}


CGRect YOCGRectApplyInsets(CGRect frame, UIEdgeInsets insets) {
  CGRect f = frame;
  f.origin.x += insets.left;
  f.origin.y += insets.top;
  f.size.width -= insets.left + insets.right;
  f.size.height -= insets.top + insets.bottom;
  return f;
}