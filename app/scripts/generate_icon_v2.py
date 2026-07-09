#!/usr/bin/env python3
"""연금나침반 앱 아이콘 생성 스크립트 - 공시한줄 브랜드 통일"""

from PIL import Image, ImageDraw
import math
import os

# 색상 정의 (공시한줄과 동일)
NAVY = (10, 37, 64)  # #0A2540 - 공시한줄 배경
GREEN = (16, 185, 129)  # #10B981 - 포인트 컬러
WHITE = (255, 255, 255)
GRAY = (156, 163, 175)  # #9CA3AF - 보조 라인


def create_compass_icon(size=1024, output_path="app_icon.png"):
    """공시한줄 스타일 나침반 아이콘 생성"""
    
    # 네이비 배경
    img = Image.new('RGBA', (size, size), NAVY)
    draw = ImageDraw.Draw(img)
    
    center = size // 2
    
    # 흰색 둥근 사각형 (카드 스타일)
    card_size = int(size * 0.55)
    card_radius = int(size * 0.08)
    card_left = center - card_size // 2
    card_top = center - card_size // 2
    card_right = center + card_size // 2
    card_bottom = center + card_size // 2
    
    draw.rounded_rectangle(
        [card_left, card_top, card_right, card_bottom],
        radius=card_radius,
        fill=WHITE
    )
    
    # 나침반 원 (카드 안)
    compass_radius = int(card_size * 0.35)
    compass_outline = int(size * 0.02)
    
    # 외곽 원 (회색)
    draw.ellipse(
        [center - compass_radius - compass_outline, 
         center - compass_radius - compass_outline,
         center + compass_radius + compass_outline, 
         center + compass_radius + compass_outline],
        fill=GRAY
    )
    
    # 내부 원 (흰색)
    draw.ellipse(
        [center - compass_radius, center - compass_radius,
         center + compass_radius, center + compass_radius],
        fill=WHITE
    )
    
    # 나침반 바늘 - 오른쪽 위 (성장 상징)
    needle_angle = -45  # 오른쪽 위 45도
    needle_length = int(compass_radius * 0.7)
    rad = math.radians(needle_angle)
    
    # 바늘 끝점
    tip_x = center + int(needle_length * math.cos(rad))
    tip_y = center + int(needle_length * math.sin(rad))
    
    # 바늘 꼬리
    tail_x = center - int(needle_length * 0.4 * math.cos(rad))
    tail_y = center - int(needle_length * 0.4 * math.sin(rad))
    
    # 바늘 너비
    perp_rad = rad + math.pi / 2
    width_offset = int(size * 0.025)
    
    # 초록색 바늘 (상승 방향)
    needle_points = [
        (tip_x, tip_y),
        (center + int(width_offset * math.cos(perp_rad)), 
         center + int(width_offset * math.sin(perp_rad))),
        (tail_x, tail_y),
        (center - int(width_offset * math.cos(perp_rad)), 
         center - int(width_offset * math.sin(perp_rad)))
    ]
    draw.polygon(needle_points, fill=GREEN)
    
    # 중심점 (회색)
    center_dot_radius = int(size * 0.025)
    draw.ellipse(
        [center - center_dot_radius, center - center_dot_radius,
         center + center_dot_radius, center + center_dot_radius],
        fill=GRAY
    )
    
    # 저장
    img.save(output_path, 'PNG')
    print(f"✅ Created: {output_path}")
    return img


def create_foreground_icon(size=1024, output_path="app_icon_foreground.png"):
    """Android Adaptive Icon용 전경 이미지 (투명 배경)"""
    
    # 투명 캔버스
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    center = size // 2
    
    # 흰색 둥근 사각형 (더 작게 - adaptive icon safe zone)
    card_size = int(size * 0.45)
    card_radius = int(size * 0.06)
    card_left = center - card_size // 2
    card_top = center - card_size // 2
    card_right = center + card_size // 2
    card_bottom = center + card_size // 2
    
    draw.rounded_rectangle(
        [card_left, card_top, card_right, card_bottom],
        radius=card_radius,
        fill=WHITE
    )
    
    # 나침반 원
    compass_radius = int(card_size * 0.32)
    compass_outline = int(size * 0.015)
    
    draw.ellipse(
        [center - compass_radius - compass_outline, 
         center - compass_radius - compass_outline,
         center + compass_radius + compass_outline, 
         center + compass_radius + compass_outline],
        fill=GRAY
    )
    
    draw.ellipse(
        [center - compass_radius, center - compass_radius,
         center + compass_radius, center + compass_radius],
        fill=WHITE
    )
    
    # 나침반 바늘
    needle_angle = -45
    needle_length = int(compass_radius * 0.65)
    rad = math.radians(needle_angle)
    
    tip_x = center + int(needle_length * math.cos(rad))
    tip_y = center + int(needle_length * math.sin(rad))
    tail_x = center - int(needle_length * 0.4 * math.cos(rad))
    tail_y = center - int(needle_length * 0.4 * math.sin(rad))
    
    perp_rad = rad + math.pi / 2
    width_offset = int(size * 0.02)
    
    needle_points = [
        (tip_x, tip_y),
        (center + int(width_offset * math.cos(perp_rad)), 
         center + int(width_offset * math.sin(perp_rad))),
        (tail_x, tail_y),
        (center - int(width_offset * math.cos(perp_rad)), 
         center - int(width_offset * math.sin(perp_rad)))
    ]
    draw.polygon(needle_points, fill=GREEN)
    
    # 중심점
    center_dot_radius = int(size * 0.02)
    draw.ellipse(
        [center - center_dot_radius, center - center_dot_radius,
         center + center_dot_radius, center + center_dot_radius],
        fill=GRAY
    )
    
    img.save(output_path, 'PNG')
    print(f"✅ Created: {output_path}")
    return img


if __name__ == "__main__":
    output_dir = "/Users/jechangryu/Workspace/pension-compass/app/assets/icons"
    os.makedirs(output_dir, exist_ok=True)
    
    # 메인 아이콘 생성 (1024x1024)
    create_compass_icon(1024, f"{output_dir}/app_icon.png")
    
    # Android Adaptive Icon 전경
    create_foreground_icon(1024, f"{output_dir}/app_icon_foreground.png")
    
    print("\n🎨 앱 아이콘 생성 완료! (공시한줄 브랜드 통일)")
    print("다음 단계: cd app && dart run flutter_launcher_icons")
