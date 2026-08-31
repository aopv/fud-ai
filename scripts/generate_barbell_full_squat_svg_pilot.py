#!/usr/bin/env python3
"""Generate and validate the Barbell Full Squat vector-motion pilot.

Canonical SVG masters live in a top-level shared directory outside either app
bundle. Android packages that directory directly, while iOS compiles generated
vector-preserving asset-catalog copies. The artwork is deterministic and uses
SVG primitives only: no embedded bitmap, external reference, font, filter, or
background.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path


EXERCISE_ID = "Barbell_Full_Squat"
VIEW_BOX = "0 0 1024 768"
REGISTRATION = "bar-center-x=512;ground-y=724;feet-x=505,575"
GENDERS = ("male", "female")
FRAME_COUNT = 4

CHARCOAL = "#272A2B"
CLOTHING_DARK = "#1E2223"
CLOTHING = "#34383A"
CLOTHING_LIGHT = "#505759"
CORAL = "#F15B5D"
CORAL_DARK = "#C8474B"
CORAL_LIGHT = "#FF8F87"
STEEL = "#777E80"
STEEL_LIGHT = "#AAB0B1"
GROUND = "#272A2B"

REPO_ROOT = Path(__file__).resolve().parents[1]
SHARED_OUTPUT_DIR = REPO_ROOT / "shared" / "workout-vectors"
LEGACY_IOS_OUTPUT_DIR = (
    REPO_ROOT
    / "ios"
    / "calorietracker"
    / "Resources"
    / "FreeExerciseDB"
    / "images"
)
ASSET_CATALOG_DIR = REPO_ROOT / "ios" / "calorietracker" / "Assets.xcassets"
MANIFEST_FILENAME = "exercise-visual-manifest.json"
MANIFEST_PATH = SHARED_OUTPUT_DIR / MANIFEST_FILENAME
MANIFEST_DATASET_DIR = ASSET_CATALOG_DIR / "ExerciseVisualManifest.dataset"
MANIFEST_SCHEMA_VERSION = 1


@dataclass(frozen=True)
class Point:
    x: float
    y: float


@dataclass(frozen=True)
class Pose:
    index: int
    phase: str
    description: str
    hip: Point
    shoulder: Point
    near_knee: Point
    far_knee: Point
    bar_y: float


POSES = (
    Pose(
        index=0,
        phase="standing",
        description="Balanced standing start with the bar across the upper back.",
        hip=Point(520, 434),
        shoulder=Point(520, 215),
        near_knee=Point(568, 570),
        far_knee=Point(512, 570),
        bar_y=231,
    ),
    Pose(
        index=1,
        phase="descent",
        description="Controlled descent: hips travel back and knees track over the toes.",
        hip=Point(474, 505),
        shoulder=Point(526, 288),
        near_knee=Point(625, 610),
        far_knee=Point(572, 604),
        bar_y=304,
    ),
    Pose(
        index=2,
        phase="bottom",
        description="Stable bottom position with heels planted and thighs below parallel.",
        hip=Point(430, 579),
        shoulder=Point(530, 394),
        near_knee=Point(647, 641),
        far_knee=Point(594, 634),
        bar_y=410,
    ),
    Pose(
        index=3,
        phase="ascent",
        description="Ascent near standing as hips and knees extend together.",
        hip=Point(490, 472),
        shoulder=Point(524, 250),
        near_knee=Point(603, 594),
        far_knee=Point(547, 588),
        bar_y=266,
    ),
)


STYLE = {
    "male": {
        "skin": "#D5A07F",
        "skin_far": "#B98266",
        "skin_shadow": "#A66F55",
        "shoulder_radius": 75,
        "waist_radius": 46,
        "hip_radius": 56,
        "near_thigh": 52,
        "far_thigh": 46,
        "near_calf": 38,
        "far_calf": 32,
        "upper_arm": 31,
        "forearm": 24,
        "head_rx": 39,
        "head_ry": 48,
        "head_forward": 15,
        "hair": "short",
    },
    "female": {
        "skin": "#E2B19B",
        "skin_far": "#C28E79",
        "skin_shadow": "#B77F6B",
        "shoulder_radius": 60,
        "waist_radius": 35,
        "hip_radius": 63,
        "near_thigh": 48,
        "far_thigh": 43,
        "near_calf": 34,
        "far_calf": 29,
        "upper_arm": 25,
        "forearm": 20,
        "head_rx": 36,
        "head_ry": 45,
        "head_forward": 17,
        "hair": "ponytail",
    },
}


def number(value: float) -> str:
    rounded = round(value, 1)
    if rounded == int(rounded):
        return str(int(rounded))
    return f"{rounded:.1f}"


def point(value: Point) -> str:
    return f"{number(value.x)} {number(value.y)}"


def add(a: Point, b: Point) -> Point:
    return Point(a.x + b.x, a.y + b.y)


def scale(value: Point, amount: float) -> Point:
    return Point(value.x * amount, value.y * amount)


def unit(a: Point, b: Point) -> Point:
    dx = b.x - a.x
    dy = b.y - a.y
    length = math.hypot(dx, dy)
    if length == 0:
        raise ValueError("Cannot normalize a zero-length segment")
    return Point(dx / length, dy / length)


def lerp(a: Point, b: Point, amount: float) -> Point:
    return Point(
        a.x + (b.x - a.x) * amount,
        a.y + (b.y - a.y) * amount,
    )


def midpoint(a: Point, b: Point) -> Point:
    return Point((a.x + b.x) / 2, (a.y + b.y) / 2)


def smooth_closed_path(points: list[Point]) -> str:
    """Return a closed quadratic spline through the supplied contour points."""

    if len(points) < 3:
        raise ValueError("A closed contour needs at least three points")
    start = midpoint(points[-1], points[0])
    commands = [f"M {point(start)}"]
    for index, control in enumerate(points):
        end = midpoint(control, points[(index + 1) % len(points)])
        commands.append(f"Q {point(control)} {point(end)}")
    commands.append("Z")
    return " ".join(commands)


def anatomical_limb_path(
    a: Point,
    b: Point,
    radius_a: float,
    radius_mid_a: float,
    radius_mid_b: float,
    radius_b: float,
    *,
    offset: float = 0,
) -> str:
    """Build a softly bulged limb rather than a straight capsule/slab."""

    direction = unit(a, b)
    normal = Point(-direction.y, direction.x)
    samples = (
        (0.00, radius_a),
        (0.28, radius_mid_a),
        (0.68, radius_mid_b),
        (1.00, radius_b),
    )
    centers = [add(lerp(a, b, amount), scale(normal, offset)) for amount, _ in samples]
    left = [add(center, scale(normal, radius)) for center, (_, radius) in zip(centers, samples)]
    right = [add(center, scale(normal, -radius)) for center, (_, radius) in zip(centers, samples)]
    return smooth_closed_path(left + list(reversed(right)))


def tapered_limb_path(a: Point, b: Point, radius_a: float, radius_b: float) -> str:
    direction = unit(a, b)
    normal = Point(-direction.y, direction.x)
    a_left = add(a, scale(normal, radius_a))
    b_left = add(b, scale(normal, radius_b))
    b_right = add(b, scale(normal, -radius_b))
    a_right = add(a, scale(normal, -radius_a))
    return (
        f"M {point(a_left)} L {point(b_left)} "
        f"Q {point(b)} {point(b_right)} L {point(a_right)} "
        f"Q {point(a)} {point(a_left)} Z"
    )


def torso_path(shoulder: Point, hip: Point, shoulder_radius: float, hip_radius: float) -> str:
    return tapered_limb_path(shoulder, hip, shoulder_radius, hip_radius)


def shoe_path(ankle: Point, toe_x: float, far: bool) -> str:
    top = ankle.y - (15 if far else 17)
    sole = 716 if far else 719
    heel = ankle.x - (27 if far else 30)
    toe = toe_x
    return (
        f"M {number(heel)} {number(top)} "
        f"Q {number(ankle.x + 6)} {number(top - 4)} {number(ankle.x + 25)} {number(top + 5)} "
        f"L {number(toe - 6)} {number(sole - 11)} "
        f"Q {number(toe + 5)} {number(sole - 5)} {number(toe)} {number(sole)} "
        f"L {number(heel - 5)} {number(sole)} "
        f"Q {number(heel - 12)} {number(sole - 8)} {number(heel)} {number(top)} Z"
    )


def shoe_markup(ankle: Point, toe_x: float, far: bool) -> str:
    """Build a recognisable low-top training shoe with sole, panels, and laces."""

    top = ankle.y - (15 if far else 17)
    sole = 716 if far else 719
    heel = ankle.x - (27 if far else 30)
    toe = toe_x
    outer_fill = CLOTHING_LIGHT if far else CLOTHING
    panel_fill = CLOTHING if far else CLOTHING_LIGHT
    opacity = ' opacity="0.92"' if far else ""
    panel = (
        f"M {number(heel + 5)} {number(top + 4)} "
        f"Q {number(ankle.x + 8)} {number(top - 1)} {number(ankle.x + 25)} {number(top + 8)} "
        f"L {number(toe - 24)} {number(sole - 12)} "
        f"Q {number(toe - 44)} {number(sole - 21)} {number(ankle.x + 11)} {number(sole - 25)} "
        f"Q {number(heel + 3)} {number(sole - 26)} {number(heel + 5)} {number(top + 4)} Z"
    )
    toe_cap = (
        f"M {number(toe - 55)} {number(sole - 22)} "
        f"Q {number(toe - 22)} {number(sole - 20)} {number(toe - 6)} {number(sole - 11)} "
        f"Q {number(toe - 21)} {number(sole - 7)} {number(toe - 59)} {number(sole - 9)} Z"
    )
    lace_start = ankle.x + 18
    laces = "".join(
        f'<line x1="{number(lace_start + offset)}" y1="{number(top + 8 + offset * 0.08)}" '
        f'x2="{number(lace_start + offset + 13)}" y2="{number(top + 16 + offset * 0.08)}" '
        f'stroke="#D7DBDC" stroke-width="4" stroke-linecap="round"/>'
        for offset in (0, 14, 28)
    )
    return (
        f'<path d="{shoe_path(ankle, toe_x, far)}" fill="{outer_fill}" stroke="{CHARCOAL}" '
        f'stroke-width="11" stroke-linejoin="round" paint-order="stroke fill"{opacity}/>'
        f'<path d="{panel}" fill="{panel_fill}" stroke="{CHARCOAL}" stroke-width="4" '
        f'stroke-linejoin="round"{opacity}/>'
        f'<path d="{toe_cap}" fill="{CLOTHING_DARK}" opacity="0.90"/>'
        f'{laces}'
        f'<line x1="{number(heel - 4)}" y1="{number(sole - 2)}" '
        f'x2="{number(toe - 2)}" y2="{number(sole - 2)}" stroke="{CHARCOAL}" '
        f'stroke-width="11" stroke-linecap="round"{opacity}/>'
        f'<line x1="{number(heel - 2)}" y1="{number(sole - 4)}" '
        f'x2="{number(toe - 4)}" y2="{number(sole - 4)}" stroke="#D7DBDC" '
        f'stroke-width="5" stroke-linecap="round"{opacity}/>'
    )


def glute_path(hip: Point, radius: float) -> str:
    left = hip.x - radius * 0.98
    right = hip.x + radius * 0.22
    top = hip.y - radius * 0.64
    bottom = hip.y + radius * 0.62
    return (
        f"M {number(right)} {number(hip.y - 9)} "
        f"C {number(hip.x - 5)} {number(top - 8)} {number(left + 7)} {number(top)} {number(left)} {number(hip.y - 3)} "
        f"C {number(left - 2)} {number(bottom - 4)} {number(hip.x - 13)} {number(bottom + 4)} {number(right)} {number(hip.y + 10)} "
        f"Q {number(hip.x + radius * 0.34)} {number(hip.y)} {number(right)} {number(hip.y - 9)} Z"
    )


def head_shadow_path(center: Point, rx: float, ry: float) -> str:
    """Return a clean cel-shadow contained within the faceless head silhouette."""

    return (
        f"M {number(center.x - rx + 5)} {number(center.y - ry * 0.36)} "
        f"Q {number(center.x - rx * 0.98)} {number(center.y + ry * 0.42)} "
        f"{number(center.x - rx * 0.33)} {number(center.y + ry * 0.90)} "
        f"Q {number(center.x - rx * 0.03)} {number(center.y + ry * 0.77)} "
        f"{number(center.x + rx * 0.02)} {number(center.y + ry * 0.28)} "
        f"Q {number(center.x - rx * 0.03)} {number(center.y - ry * 0.06)} "
        f"{number(center.x - rx + 5)} {number(center.y - ry * 0.36)} Z"
    )


def hair_markup(gender: str, center: Point, rx: float, ry: float) -> str:
    cap = (
        f'<path d="M {number(center.x - rx)} {number(center.y - 2)} '
        f'A {number(rx)} {number(ry)} 0 0 1 {number(center.x + rx)} {number(center.y - 2)} '
        f'Q {number(center.x + rx * 0.72)} {number(center.y - ry * 0.78)} '
        f'{number(center.x)} {number(center.y - ry)} '
        f'Q {number(center.x - rx * 0.72)} {number(center.y - ry * 0.78)} '
        f'{number(center.x - rx)} {number(center.y - 2)} Z" fill="{CHARCOAL}"/>'
    )
    if gender == "male":
        return cap

    pony_center = Point(center.x - rx - 13, center.y + 8)
    return (
        f'<ellipse cx="{number(pony_center.x)}" cy="{number(pony_center.y)}" '
        f'rx="22" ry="35" fill="{CHARCOAL}" stroke="{CHARCOAL}" stroke-width="5"/>'
        + cap
    )


def arm_markup(
    shoulder: Point,
    elbow: Point,
    hand: Point,
    skin: str,
    skin_shadow: str,
    far: bool,
    upper_radius: float,
    forearm_radius: float,
) -> str:
    opacity = ' opacity="0.88"' if far else ""
    bicep_opacity = "0.72" if far else "0.82"
    upper = anatomical_limb_path(
        shoulder,
        elbow,
        upper_radius * 0.82,
        upper_radius * 1.10,
        upper_radius,
        upper_radius * 0.76,
    )
    forearm = anatomical_limb_path(
        elbow,
        hand,
        forearm_radius * 0.98,
        forearm_radius * 1.08,
        forearm_radius * 0.82,
        forearm_radius * 0.64,
    )
    bicep_start = lerp(shoulder, elbow, 0.18)
    bicep_end = lerp(shoulder, elbow, 0.76)
    bicep = anatomical_limb_path(
        bicep_start,
        bicep_end,
        upper_radius * 0.35,
        upper_radius * 0.55,
        upper_radius * 0.42,
        upper_radius * 0.22,
        offset=-upper_radius * 0.18,
    )
    return (
        f'<path d="{upper}" fill="{skin}" stroke="{CHARCOAL}" stroke-width="10" '
        f'stroke-linejoin="round" paint-order="stroke fill"{opacity}/>'
        f'<path d="{bicep}" fill="{skin_shadow}" stroke="{CHARCOAL}" stroke-width="3" '
        f'stroke-linejoin="round" opacity="{bicep_opacity}"/>'
        f'<circle cx="{number(elbow.x)}" cy="{number(elbow.y)}" r="{number(forearm_radius * 0.82)}" '
        f'fill="{skin}" stroke="{CHARCOAL}" stroke-width="9" paint-order="stroke fill"{opacity}/>'
        f'<path d="{forearm}" fill="{skin}" stroke="{CHARCOAL}" stroke-width="10" '
        f'stroke-linejoin="round" paint-order="stroke fill"{opacity}/>'
        f'<ellipse cx="{number(hand.x)}" cy="{number(hand.y)}" rx="{number(forearm_radius * 0.72)}" '
        f'ry="{number(forearm_radius * 0.58)}" fill="{skin}" stroke="{CHARCOAL}" '
        f'stroke-width="8" paint-order="stroke fill"{opacity}/>'
    )


def barbell_markup(bar_y: float) -> str:
    def plate(cx: int, half_width: int, half_height: int, fill: str) -> str:
        left = cx - half_width
        right = cx + half_width
        top = bar_y - half_height
        bottom = bar_y + half_height
        return (
            f'<path d="M {number(left + 7)} {number(top)} L {number(right - 7)} {number(top)} '
            f'Q {number(right)} {number(top)} {number(right)} {number(top + 7)} '
            f'L {number(right)} {number(bottom - 7)} Q {number(right)} {number(bottom)} {number(right - 7)} {number(bottom)} '
            f'L {number(left + 7)} {number(bottom)} Q {number(left)} {number(bottom)} {number(left)} {number(bottom - 7)} '
            f'L {number(left)} {number(top + 7)} Q {number(left)} {number(top)} {number(left + 7)} {number(top)} Z" '
            f'fill="{fill}" stroke="{CHARCOAL}" stroke-width="9" paint-order="stroke fill"/>'
        )

    knurling = "".join(
        f'<line x1="{x}" y1="{number(bar_y - 7)}" x2="{x}" y2="{number(bar_y + 7)}" '
        f'stroke="{CHARCOAL}" stroke-width="2" opacity="0.65"/>'
        for x in range(463, 568, 14)
    )
    return (
        f'<g id="barbell" data-center-x="512" data-bar-y="{number(bar_y)}">'
        f'<line x1="74" y1="{number(bar_y)}" x2="950" y2="{number(bar_y)}" '
        f'stroke="{CHARCOAL}" stroke-width="26" stroke-linecap="round"/>'
        f'<line x1="74" y1="{number(bar_y)}" x2="950" y2="{number(bar_y)}" '
        f'stroke="{STEEL_LIGHT}" stroke-width="11" stroke-linecap="round"/>'
        f'{plate(126, 28, 84, STEEL)}{plate(181, 21, 71, CLOTHING_LIGHT)}'
        f'{plate(898, 28, 84, STEEL)}{plate(843, 21, 71, CLOTHING_LIGHT)}'
        f'<line x1="116" y1="{number(bar_y - 61)}" x2="116" y2="{number(bar_y + 61)}" '
        f'stroke="{STEEL_LIGHT}" stroke-width="5" stroke-linecap="round" opacity="0.62"/>'
        f'<line x1="888" y1="{number(bar_y - 61)}" x2="888" y2="{number(bar_y + 61)}" '
        f'stroke="{STEEL_LIGHT}" stroke-width="5" stroke-linecap="round" opacity="0.62"/>'
        f'<line x1="210" y1="{number(bar_y)}" x2="814" y2="{number(bar_y)}" '
        f'stroke="{STEEL_LIGHT}" stroke-width="10" stroke-linecap="round"/>'
        f'<line x1="232" y1="{number(bar_y - 1)}" x2="792" y2="{number(bar_y - 1)}" '
        f'stroke="#D7DBDC" stroke-width="3" stroke-linecap="round" opacity="0.72"/>'
        f'{knurling}</g>'
    )


def render_svg(gender: str, pose: Pose) -> str:
    style = STYLE[gender]
    near_ankle = Point(575, 690)
    far_ankle = Point(505, 690)
    near_toe = 704
    far_toe = 625

    spine = unit(pose.hip, pose.shoulder)
    torso_normal = Point(-spine.y, spine.x)
    head_center = add(
        add(pose.shoulder, scale(spine, 101)),
        Point(style["head_forward"], 0),
    )
    neck_top = add(pose.shoulder, scale(spine, 57))
    neck_shadow = anatomical_limb_path(
        add(pose.shoulder, scale(spine, 7)),
        add(neck_top, scale(spine, -4)),
        10,
        13,
        11,
        7,
        offset=10,
    )

    far_hip = Point(pose.hip.x - 17, pose.hip.y + 5)
    near_hip = Point(pose.hip.x + 11, pose.hip.y)
    waist = add(pose.hip, scale(spine, 72))

    far_shoulder = add(
        add(pose.shoulder, scale(torso_normal, -style["shoulder_radius"] * 0.68)),
        scale(spine, -13),
    )
    near_shoulder = add(
        add(pose.shoulder, scale(torso_normal, style["shoulder_radius"] * 0.72)),
        scale(spine, -12),
    )
    grip_half_width = 131 if gender == "female" else 145
    far_hand = Point(512 - grip_half_width, pose.bar_y + 1)
    near_hand = Point(512 + grip_half_width, pose.bar_y + 1)
    far_elbow = Point(pose.shoulder.x - 100, pose.bar_y + 112)
    near_elbow = Point(pose.shoulder.x + 105, pose.bar_y + 114)

    far_thigh = anatomical_limb_path(
        far_hip,
        pose.far_knee,
        style["far_thigh"] * 0.92,
        style["far_thigh"] * 1.10,
        style["far_thigh"] * 0.94,
        style["far_thigh"] * 0.68,
    )
    near_thigh = anatomical_limb_path(
        near_hip,
        pose.near_knee,
        style["near_thigh"] * 0.94,
        style["near_thigh"] * 1.13,
        style["near_thigh"] * 0.98,
        style["near_thigh"] * 0.69,
    )
    far_calf = anatomical_limb_path(
        pose.far_knee,
        far_ankle,
        style["far_calf"] * 0.78,
        style["far_calf"] * 1.18,
        style["far_calf"] * 0.97,
        style["far_calf"] * 0.48,
    )
    near_calf = anatomical_limb_path(
        pose.near_knee,
        near_ankle,
        style["near_calf"] * 0.80,
        style["near_calf"] * 1.24,
        style["near_calf"] * 1.02,
        style["near_calf"] * 0.50,
    )

    far_hamstring = anatomical_limb_path(
        lerp(far_hip, pose.far_knee, 0.24),
        lerp(far_hip, pose.far_knee, 0.84),
        style["far_thigh"] * 0.34,
        style["far_thigh"] * 0.50,
        style["far_thigh"] * 0.40,
        style["far_thigh"] * 0.18,
        offset=style["far_thigh"] * 0.38,
    )
    near_hamstring = anatomical_limb_path(
        lerp(near_hip, pose.near_knee, 0.23),
        lerp(near_hip, pose.near_knee, 0.85),
        style["near_thigh"] * 0.34,
        style["near_thigh"] * 0.53,
        style["near_thigh"] * 0.42,
        style["near_thigh"] * 0.18,
        offset=style["near_thigh"] * 0.39,
    )
    far_quad = anatomical_limb_path(
        lerp(far_hip, pose.far_knee, 0.28),
        lerp(far_hip, pose.far_knee, 0.87),
        style["far_thigh"] * 0.31,
        style["far_thigh"] * 0.54,
        style["far_thigh"] * 0.46,
        style["far_thigh"] * 0.20,
        offset=-style["far_thigh"] * 0.34,
    )
    near_quad = anatomical_limb_path(
        lerp(near_hip, pose.near_knee, 0.27),
        lerp(near_hip, pose.near_knee, 0.88),
        style["near_thigh"] * 0.32,
        style["near_thigh"] * 0.58,
        style["near_thigh"] * 0.49,
        style["near_thigh"] * 0.20,
        offset=-style["near_thigh"] * 0.35,
    )
    far_quad_highlight = anatomical_limb_path(
        lerp(far_hip, pose.far_knee, 0.38),
        lerp(far_hip, pose.far_knee, 0.72),
        style["far_thigh"] * 0.10,
        style["far_thigh"] * 0.20,
        style["far_thigh"] * 0.15,
        style["far_thigh"] * 0.06,
        offset=-style["far_thigh"] * 0.49,
    )
    near_quad_highlight = anatomical_limb_path(
        lerp(near_hip, pose.near_knee, 0.37),
        lerp(near_hip, pose.near_knee, 0.73),
        style["near_thigh"] * 0.11,
        style["near_thigh"] * 0.21,
        style["near_thigh"] * 0.16,
        style["near_thigh"] * 0.06,
        offset=-style["near_thigh"] * 0.51,
    )
    far_gastrocnemius = anatomical_limb_path(
        lerp(pose.far_knee, far_ankle, 0.18),
        lerp(pose.far_knee, far_ankle, 0.72),
        style["far_calf"] * 0.20,
        style["far_calf"] * 0.50,
        style["far_calf"] * 0.36,
        style["far_calf"] * 0.12,
        offset=style["far_calf"] * 0.32,
    )
    near_gastrocnemius = anatomical_limb_path(
        lerp(pose.near_knee, near_ankle, 0.18),
        lerp(pose.near_knee, near_ankle, 0.73),
        style["near_calf"] * 0.21,
        style["near_calf"] * 0.53,
        style["near_calf"] * 0.38,
        style["near_calf"] * 0.12,
        offset=style["near_calf"] * 0.33,
    )

    torso = anatomical_limb_path(
        pose.shoulder,
        pose.hip,
        style["shoulder_radius"],
        style["shoulder_radius"] * 0.94,
        style["waist_radius"],
        style["hip_radius"],
    )
    torso_panel = anatomical_limb_path(
        add(pose.shoulder, scale(spine, -2)),
        add(waist, scale(spine, 4)),
        style["shoulder_radius"] * 0.54,
        style["shoulder_radius"] * 0.60,
        style["waist_radius"] * 0.55,
        style["waist_radius"] * 0.45,
        offset=-style["shoulder_radius"] * 0.17,
    )
    torso_shadow = anatomical_limb_path(
        add(pose.shoulder, scale(spine, -1)),
        add(waist, scale(spine, 2)),
        style["shoulder_radius"] * 0.42,
        style["shoulder_radius"] * 0.48,
        style["waist_radius"] * 0.45,
        style["waist_radius"] * 0.34,
        offset=style["shoulder_radius"] * 0.30,
    )
    pelvis = anatomical_limb_path(
        waist,
        pose.hip,
        style["waist_radius"] * 1.05,
        style["hip_radius"] * 0.92,
        style["hip_radius"] * 1.03,
        style["hip_radius"] * 0.98,
    )
    far_shorts = anatomical_limb_path(
        far_hip,
        lerp(far_hip, pose.far_knee, 0.25),
        style["far_thigh"] * 1.01,
        style["far_thigh"] * 1.06,
        style["far_thigh"] * 0.94,
        style["far_thigh"] * 0.83,
    )
    near_shorts = anatomical_limb_path(
        near_hip,
        lerp(near_hip, pose.near_knee, 0.25),
        style["near_thigh"] * 1.02,
        style["near_thigh"] * 1.08,
        style["near_thigh"] * 0.96,
        style["near_thigh"] * 0.84,
    )

    trap_left = add(
        add(pose.shoulder, scale(torso_normal, -style["shoulder_radius"] * 0.78)),
        scale(spine, -27),
    )
    trap_left_top = add(
        add(pose.shoulder, scale(torso_normal, -style["shoulder_radius"] * 0.45)),
        scale(spine, 18),
    )
    trap_neck_left = add(
        add(pose.shoulder, scale(torso_normal, -21)),
        scale(spine, 37),
    )
    trap_neck_right = add(
        add(pose.shoulder, scale(torso_normal, 21)),
        scale(spine, 37),
    )
    trap_right_top = add(
        add(pose.shoulder, scale(torso_normal, style["shoulder_radius"] * 0.45)),
        scale(spine, 18),
    )
    trap_right = add(
        add(pose.shoulder, scale(torso_normal, style["shoulder_radius"] * 0.78)),
        scale(spine, -27),
    )
    traps = smooth_closed_path(
        [trap_left, trap_left_top, trap_neck_left, trap_neck_right, trap_right_top, trap_right]
    )
    glute_radius = style["hip_radius"] * 0.92
    glute_shadow = glute_path(
        Point(pose.hip.x - glute_radius * 0.13, pose.hip.y + glute_radius * 0.10),
        glute_radius * 0.57,
    )

    metadata = {
        "exercise": EXERCISE_ID,
        "gender": gender,
        "frame": pose.index,
        "phase": pose.phase,
        "viewBox": VIEW_BOX,
        "registration": REGISTRATION,
        "palette": {
            "outline": CHARCOAL,
            "clothing": CLOTHING,
            "targetMuscles": CORAL,
        },
    }

    title_gender = gender.capitalize()
    pieces = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        (
            f'<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="768" '
            f'viewBox="{VIEW_BOX}" role="img" aria-labelledby="title desc" '
            f'data-exercise-id="{EXERCISE_ID}" data-gender="{gender}" '
            f'data-frame="{pose.index}" data-phase="{pose.phase}" '
            f'data-registration="{REGISTRATION}">'
        ),
        f'<title id="title">Barbell Full Squat — {title_gender} — {pose.phase}</title>',
        f'<desc id="desc">{pose.description} Faceless cel-vector anatomical training illustration.</desc>',
        f'<metadata>{json.dumps(metadata, sort_keys=True, separators=(",", ":"))}</metadata>',
        '<g id="grounding">',
        f'<ellipse cx="548" cy="712" rx="232" ry="20" fill="{GROUND}" opacity="0.10"/>',
        f'<line x1="292" y1="724" x2="756" y2="724" stroke="{GROUND}" stroke-width="4" '
        'stroke-linecap="round" opacity="0.22"/>',
        '</g>',
        barbell_markup(pose.bar_y),
        '<g id="body">',
        '<g id="back-squat-grip">',
        arm_markup(
            far_shoulder,
            far_elbow,
            far_hand,
            style["skin_far"],
            style["skin_shadow"],
            True,
            style["upper_arm"] * 0.88,
            style["forearm"] * 0.88,
        ),
        arm_markup(
            near_shoulder,
            near_elbow,
            near_hand,
            style["skin"],
            style["skin_shadow"],
            False,
            style["upper_arm"],
            style["forearm"],
        ),
        '</g>',
        '<g id="far-side" opacity="0.92">',
        f'<path d="{far_thigh}" fill="{style["skin_far"]}" stroke="{CHARCOAL}" stroke-width="11" '
        'stroke-linejoin="round" paint-order="stroke fill"/>',
        f'<path d="{far_hamstring}" fill="{style["skin_shadow"]}" stroke="{CHARCOAL}" '
        'stroke-width="3" stroke-linejoin="round" opacity="0.82"/>',
        f'<circle cx="{number(pose.far_knee.x)}" cy="{number(pose.far_knee.y)}" '
        f'r="{number(style["far_thigh"] * 0.54)}" fill="{style["skin_far"]}" '
        f'stroke="{CHARCOAL}" stroke-width="10" paint-order="stroke fill"/>',
        f'<path d="{far_calf}" fill="{style["skin_far"]}" stroke="{CHARCOAL}" stroke-width="11" '
        'stroke-linejoin="round" paint-order="stroke fill"/>',
        f'<path d="{far_gastrocnemius}" fill="{style["skin_shadow"]}" stroke="{CHARCOAL}" '
        'stroke-width="3" stroke-linejoin="round" opacity="0.78"/>',
        shoe_markup(far_ankle, far_toe, True),
        '</g>',
        '<g id="near-side">',
        f'<path d="{near_thigh}" fill="{style["skin"]}" stroke="{CHARCOAL}" stroke-width="12" '
        'stroke-linejoin="round" paint-order="stroke fill"/>',
        f'<path d="{near_hamstring}" fill="{style["skin_shadow"]}" stroke="{CHARCOAL}" '
        'stroke-width="3" stroke-linejoin="round" opacity="0.86"/>',
        f'<circle cx="{number(pose.near_knee.x)}" cy="{number(pose.near_knee.y)}" '
        f'r="{number(style["near_thigh"] * 0.55)}" fill="{style["skin"]}" '
        f'stroke="{CHARCOAL}" stroke-width="11" paint-order="stroke fill"/>',
        f'<path d="{near_calf}" fill="{style["skin"]}" stroke="{CHARCOAL}" stroke-width="12" '
        'stroke-linejoin="round" paint-order="stroke fill"/>',
        f'<path d="{near_gastrocnemius}" fill="{style["skin_shadow"]}" stroke="{CHARCOAL}" '
        'stroke-width="3" stroke-linejoin="round" opacity="0.82"/>',
        shoe_markup(near_ankle, near_toe, False),
        '</g>',
        '<g id="torso-and-pelvis">',
        f'<path d="{torso}" fill="{CLOTHING}" stroke="{CHARCOAL}" stroke-width="13" '
        'stroke-linejoin="round" paint-order="stroke fill"/>',
        f'<path d="{torso_shadow}" fill="{CLOTHING_DARK}" stroke="{CHARCOAL}" stroke-width="3" '
        'stroke-linejoin="round" opacity="0.90"/>',
        f'<path d="{torso_panel}" fill="{CLOTHING_LIGHT}" stroke="{CHARCOAL}" stroke-width="3" '
        'stroke-linejoin="round" opacity="0.88"/>',
        f'<path d="{traps}" fill="{CLOTHING_LIGHT}" stroke="{CHARCOAL}" stroke-width="11" '
        'stroke-linejoin="round" paint-order="stroke fill"/>',
        f'<path d="{pelvis}" fill="{CLOTHING_LIGHT}" stroke="{CHARCOAL}" stroke-width="11" '
        'stroke-linejoin="round" paint-order="stroke fill"/>',
        f'<path d="{far_shorts}" fill="{CLOTHING}" stroke="{CHARCOAL}" stroke-width="10" '
        'stroke-linejoin="round" paint-order="stroke fill" opacity="0.96"/>',
        f'<path d="{near_shorts}" fill="{CLOTHING_LIGHT}" stroke="{CHARCOAL}" stroke-width="11" '
        'stroke-linejoin="round" paint-order="stroke fill"/>',
        f'<ellipse cx="{number(far_shoulder.x)}" cy="{number(far_shoulder.y)}" '
        f'rx="{number(style["upper_arm"] * 1.22)}" ry="{number(style["upper_arm"] * 1.02)}" '
        f'fill="{CLOTHING}" stroke="{CHARCOAL}" stroke-width="10" paint-order="stroke fill"/>',
        f'<ellipse cx="{number(near_shoulder.x)}" cy="{number(near_shoulder.y)}" '
        f'rx="{number(style["upper_arm"] * 1.30)}" ry="{number(style["upper_arm"] * 1.08)}" '
        f'fill="{CLOTHING_LIGHT}" stroke="{CHARCOAL}" stroke-width="11" paint-order="stroke fill"/>',
        f'<ellipse cx="{number(near_shoulder.x - 5)}" cy="{number(near_shoulder.y - 4)}" '
        f'rx="{number(style["upper_arm"] * 0.55)}" ry="{number(style["upper_arm"] * 0.40)}" '
        f'fill="#687073" opacity="0.78"/>',
        '</g>',
        '<g id="muscle-highlights">',
        f'<path d="{far_quad}" fill="{CORAL_DARK}" stroke="{CHARCOAL}" stroke-width="7" '
        'stroke-linejoin="round" paint-order="stroke fill" opacity="0.90"/>',
        f'<path d="{far_quad_highlight}" fill="{CORAL_LIGHT}" opacity="0.58"/>',
        f'<path d="{near_quad}" fill="{CORAL}" stroke="{CHARCOAL}" stroke-width="8" '
        'stroke-linejoin="round" paint-order="stroke fill"/>',
        f'<path d="{near_quad_highlight}" fill="{CORAL_LIGHT}" opacity="0.88"/>',
        f'<ellipse cx="{number(pose.near_knee.x + 4)}" cy="{number(pose.near_knee.y - 5)}" '
        f'rx="{number(style["near_thigh"] * 0.25)}" ry="{number(style["near_thigh"] * 0.31)}" '
        f'fill="{CORAL}" stroke="{CHARCOAL}" stroke-width="6" paint-order="stroke fill" opacity="0.92"/>',
        f'<path d="{glute_path(pose.hip, glute_radius)}" fill="{CORAL}" '
        f'stroke="{CHARCOAL}" stroke-width="8" stroke-linejoin="round" paint-order="stroke fill"/>',
        f'<path d="{glute_shadow}" fill="{CORAL_DARK}" opacity="0.82"/>',
        f'<path d="M {number(near_hip.x - 25)} {number(near_hip.y - 13)} '
        f'Q {number(near_hip.x - 8)} {number(near_hip.y - 27)} '
        f'{number(near_hip.x + 12)} {number(near_hip.y - 12)}" '
        f'fill="none" stroke="{CORAL_LIGHT}" stroke-width="7" stroke-linecap="round" opacity="0.90"/>',
        '</g>',
        '<g id="head-and-neck">',
        f'<path d="{anatomical_limb_path(pose.shoulder, neck_top, 27, 29, 25, 22)}" '
        f'fill="{style["skin"]}" stroke="{CHARCOAL}" stroke-width="11" paint-order="stroke fill"/>',
        f'<path d="{neck_shadow}" fill="{style["skin_shadow"]}" opacity="0.82"/>',
        f'<ellipse cx="{number(head_center.x)}" cy="{number(head_center.y)}" '
        f'rx="{style["head_rx"]}" ry="{style["head_ry"]}" fill="{style["skin"]}" '
        f'stroke="{CHARCOAL}" stroke-width="12" paint-order="stroke fill"/>',
        f'<path d="{head_shadow_path(head_center, style["head_rx"], style["head_ry"])}" '
        f'fill="{style["skin_shadow"]}" opacity="0.52"/>',
        hair_markup(gender, head_center, style["head_rx"], style["head_ry"]),
        '</g>',
        '</g>',
        '</svg>',
        '',
    ]
    return "\n".join(pieces)


def expected_assets() -> dict[Path, str]:
    return {
        SHARED_OUTPUT_DIR / f"{EXERCISE_ID}_{gender}_{pose.index}.svg": render_svg(gender, pose)
        for gender in GENDERS
        for pose in POSES
    }


def manifest_content() -> str:
    frame_count = len(POSES)
    if frame_count not in range(3, 6):
        raise ValueError(f"Exercise visual frame count must be 3...5, got {frame_count}")

    payload = {
        "schemaVersion": MANIFEST_SCHEMA_VERSION,
        "exercises": [
            {
                "exerciseId": EXERCISE_ID,
                "frameCount": frame_count,
                "representativeFrameIndex": min(2, frame_count - 1),
                "maleFrames": [f"{EXERCISE_ID}_male_{index}" for index in range(frame_count)],
                "femaleFrames": [f"{EXERCISE_ID}_female_{index}" for index in range(frame_count)],
            }
        ],
    }
    return json.dumps(payload, indent=2, sort_keys=True) + "\n"


def asset_catalog_contents(filename: str) -> str:
    payload = {
        "images": [
            {
                "filename": filename,
                "idiom": "universal",
                "scale": "1x",
            }
        ],
        "info": {
            "author": "xcode",
            "version": 1,
        },
        "properties": {
            "preserves-vector-representation": True,
        },
    }
    return json.dumps(payload, indent=2, sort_keys=True) + "\n"


def manifest_dataset_contents(filename: str) -> str:
    payload = {
        "data": [
            {
                "filename": filename,
                "idiom": "universal",
            }
        ],
        "info": {
            "author": "xcode",
            "version": 1,
        },
    }
    return json.dumps(payload, indent=2, sort_keys=True) + "\n"


def expected_catalog_assets(raw_assets: dict[Path, str]) -> dict[Path, str]:
    catalog_assets: dict[Path, str] = {}
    for raw_path, svg_content in raw_assets.items():
        imageset = ASSET_CATALOG_DIR / f"{raw_path.stem}.imageset"
        catalog_assets[imageset / raw_path.name] = svg_content
        catalog_assets[imageset / "Contents.json"] = asset_catalog_contents(raw_path.name)
    return catalog_assets


def local_name(element: ET.Element) -> str:
    return element.tag.rsplit("}", 1)[-1]


def validate_assets(expected: dict[Path, str], *, verify_determinism: bool) -> None:
    expected_paths = set(expected)
    actual_paths = set(SHARED_OUTPUT_DIR.glob(f"{EXERCISE_ID}_*_*.svg"))
    if actual_paths != expected_paths:
        missing = sorted(str(path) for path in expected_paths - actual_paths)
        extra = sorted(str(path) for path in actual_paths - expected_paths)
        raise ValueError(f"Pilot asset set mismatch; missing={missing}, extra={extra}")

    allowed_tags = {
        "svg",
        "title",
        "desc",
        "metadata",
        "g",
        "path",
        "circle",
        "ellipse",
        "line",
        "polyline",
        "polygon",
    }
    required_group_ids = {"grounding", "barbell", "body", "muscle-highlights"}

    for path, deterministic_content in sorted(expected.items()):
        content = path.read_text(encoding="utf-8")
        if verify_determinism and content != deterministic_content:
            raise ValueError(f"{path.name} differs from deterministic generator output")

        lowered = content.lower()
        forbidden_tokens = (
            "<image",
            "<foreignobject",
            "data:image",
            "base64",
            "href=",
            ".png",
            ".jpg",
            ".jpeg",
            ".webp",
            "background:",
        )
        for token in forbidden_tokens:
            if token in lowered:
                raise ValueError(f"{path.name} contains forbidden raster/external token {token!r}")

        root = ET.fromstring(content)
        if local_name(root) != "svg":
            raise ValueError(f"{path.name} does not have an SVG root")
        if root.attrib.get("viewBox") != VIEW_BOX:
            raise ValueError(f"{path.name} has an inconsistent viewBox")
        if root.attrib.get("data-registration") != REGISTRATION:
            raise ValueError(f"{path.name} has inconsistent registration metadata")
        if root.attrib.get("data-exercise-id") != EXERCISE_ID:
            raise ValueError(f"{path.name} has the wrong exercise ID")

        expected_stem = path.stem.removeprefix(f"{EXERCISE_ID}_")
        gender, frame_text = expected_stem.rsplit("_", 1)
        pose = POSES[int(frame_text)]
        if root.attrib.get("data-gender") != gender:
            raise ValueError(f"{path.name} has the wrong gender metadata")
        if root.attrib.get("data-frame") != frame_text:
            raise ValueError(f"{path.name} has the wrong frame metadata")
        if root.attrib.get("data-phase") != pose.phase:
            raise ValueError(f"{path.name} has the wrong phase metadata")

        tags = {local_name(element) for element in root.iter()}
        unexpected_tags = tags - allowed_tags
        if unexpected_tags:
            raise ValueError(f"{path.name} contains unsupported SVG tags: {sorted(unexpected_tags)}")
        if "rect" in tags or "image" in tags:
            raise ValueError(f"{path.name} contains a background rectangle or raster image")

        group_ids = {
            element.attrib["id"]
            for element in root.iter()
            if local_name(element) == "g" and "id" in element.attrib
        }
        if not required_group_ids.issubset(group_ids):
            raise ValueError(f"{path.name} is missing required semantic vector groups")

        barbell = next(
            element
            for element in root.iter()
            if local_name(element) == "g" and element.attrib.get("id") == "barbell"
        )
        if barbell.attrib.get("data-center-x") != "512":
            raise ValueError(f"{path.name} barbell is not registered at center x=512")
        if CORAL.lower() not in lowered or CHARCOAL.lower() not in lowered:
            raise ValueError(f"{path.name} is missing the approved target-muscle/outline palette")

    legacy_paths = {
        LEGACY_IOS_OUTPUT_DIR / path.name
        for path in expected_paths
        if (LEGACY_IOS_OUTPUT_DIR / path.name).exists()
    }
    if legacy_paths:
        raise ValueError(
            "Raw pilot SVGs must not be bundled through the iOS FreeExerciseDB directory: "
            + ", ".join(str(path) for path in sorted(legacy_paths))
        )


def validate_catalog_assets(
    raw_assets: dict[Path, str],
    catalog_assets: dict[Path, str],
    *,
    verify_determinism: bool,
) -> None:
    expected_imagesets = {path.parent for path in catalog_assets}
    actual_imagesets = set(ASSET_CATALOG_DIR.glob(f"{EXERCISE_ID}_*.imageset"))
    if actual_imagesets != expected_imagesets:
        missing = sorted(str(path) for path in expected_imagesets - actual_imagesets)
        extra = sorted(str(path) for path in actual_imagesets - expected_imagesets)
        raise ValueError(f"Pilot asset-catalog set mismatch; missing={missing}, extra={extra}")

    for raw_path, svg_content in sorted(raw_assets.items()):
        imageset = ASSET_CATALOG_DIR / f"{raw_path.stem}.imageset"
        svg_path = imageset / raw_path.name
        contents_path = imageset / "Contents.json"
        actual_files = set(imageset.iterdir())
        expected_files = {svg_path, contents_path}
        if actual_files != expected_files:
            raise ValueError(f"{imageset.name} must contain exactly its SVG master and Contents.json")
        if svg_path.read_text(encoding="utf-8") != svg_content:
            raise ValueError(f"{svg_path} differs from its canonical shared SVG")

        contents_text = contents_path.read_text(encoding="utf-8")
        if verify_determinism and contents_text != asset_catalog_contents(raw_path.name):
            raise ValueError(f"{contents_path} differs from deterministic generator output")
        contents = json.loads(contents_text)
        if contents.get("images") != [
            {"filename": raw_path.name, "idiom": "universal", "scale": "1x"}
        ]:
            raise ValueError(f"{contents_path} has an invalid universal SVG slot")
        if contents.get("properties", {}).get("preserves-vector-representation") is not True:
            raise ValueError(f"{contents_path} does not preserve vector representation")


def validate_manifest(expected_content: str, *, verify_determinism: bool) -> None:
    if not MANIFEST_PATH.is_file():
        raise ValueError(f"Missing shared exercise visual manifest: {MANIFEST_PATH}")
    actual_content = MANIFEST_PATH.read_text(encoding="utf-8")
    if verify_determinism and actual_content != expected_content:
        raise ValueError(f"{MANIFEST_PATH} differs from deterministic generator output")

    payload = json.loads(actual_content)
    if payload.get("schemaVersion") != MANIFEST_SCHEMA_VERSION:
        raise ValueError(f"{MANIFEST_PATH} has an unsupported schema version")
    exercises = payload.get("exercises")
    if not isinstance(exercises, list) or len(exercises) != 1:
        raise ValueError(f"{MANIFEST_PATH} must contain the pilot exercise exactly once")
    entry = exercises[0]
    frame_count = entry.get("frameCount")
    if not isinstance(frame_count, int) or frame_count not in range(3, 6):
        raise ValueError(f"{MANIFEST_PATH} frameCount must be 3...5")
    if entry.get("representativeFrameIndex") not in range(frame_count):
        raise ValueError(f"{MANIFEST_PATH} has an invalid representative frame")
    for gender in GENDERS:
        expected_names = [f"{EXERCISE_ID}_{gender}_{index}" for index in range(frame_count)]
        if entry.get(f"{gender}Frames") != expected_names:
            raise ValueError(f"{MANIFEST_PATH} has an incomplete {gender} frame set")

    expected_dataset_files = {
        MANIFEST_DATASET_DIR / MANIFEST_FILENAME,
        MANIFEST_DATASET_DIR / "Contents.json",
    }
    if not MANIFEST_DATASET_DIR.is_dir() or set(MANIFEST_DATASET_DIR.iterdir()) != expected_dataset_files:
        raise ValueError("ExerciseVisualManifest.dataset must contain only the manifest and Contents.json")
    dataset_manifest = MANIFEST_DATASET_DIR / MANIFEST_FILENAME
    if dataset_manifest.read_text(encoding="utf-8") != actual_content:
        raise ValueError("iOS exercise visual manifest differs from the canonical shared manifest")
    expected_contents = manifest_dataset_contents(MANIFEST_FILENAME)
    if (MANIFEST_DATASET_DIR / "Contents.json").read_text(encoding="utf-8") != expected_contents:
        raise ValueError("ExerciseVisualManifest.dataset/Contents.json is not deterministic")


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="Validate existing assets and fail if they differ from deterministic output.",
    )
    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()
    expected = expected_assets()
    catalog_expected = expected_catalog_assets(expected)
    expected_manifest = manifest_content()
    if not arguments.check:
        SHARED_OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
        for path, content in sorted(expected.items()):
            path.write_text(content, encoding="utf-8", newline="\n")
        MANIFEST_PATH.write_text(expected_manifest, encoding="utf-8", newline="\n")
        for path, content in sorted(catalog_expected.items()):
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content, encoding="utf-8", newline="\n")
        MANIFEST_DATASET_DIR.mkdir(parents=True, exist_ok=True)
        (MANIFEST_DATASET_DIR / MANIFEST_FILENAME).write_text(
            expected_manifest,
            encoding="utf-8",
            newline="\n",
        )
        (MANIFEST_DATASET_DIR / "Contents.json").write_text(
            manifest_dataset_contents(MANIFEST_FILENAME),
            encoding="utf-8",
            newline="\n",
        )
        for shared_path in expected:
            legacy_path = LEGACY_IOS_OUTPUT_DIR / shared_path.name
            legacy_path.unlink(missing_ok=True)

    validate_assets(expected, verify_determinism=True)
    validate_catalog_assets(
        expected,
        catalog_expected,
        verify_determinism=True,
    )
    validate_manifest(expected_manifest, verify_determinism=True)
    mode = "validated" if arguments.check else "generated and validated"
    print(
        f"{mode} {len(expected)} genuine-vector SVG assets for {EXERCISE_ID}; "
        f"viewBox={VIEW_BOX}; frames=0..{FRAME_COUNT - 1}; genders={','.join(GENDERS)}; "
        f"canonical={SHARED_OUTPUT_DIR.relative_to(REPO_ROOT)}; "
        f"iOS vector imagesets={len(expected)}"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, ET.ParseError) as error:
        print(f"error: {error}", file=sys.stderr)
        raise SystemExit(1)
