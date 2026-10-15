#!/usr/bin/env python3
"""Генератор пиксель-арта для «Я — подземелье».

Все спрайты описаны ASCII-шаблонами 12×12 (иконки 8×8), один символ = один пиксель.
Запуск: python3 tools/gen_sprites.py  → assets/sprites/**.png
"""
import os
import sys
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sprites")

ERRORS = []

PAL = {
    "k": "#18141e", "K": "#2b2236", "d": "#3e3350", "D": "#574a6e", "g": "#8b7fa3", "G": "#c2b8d6",
    "w": "#f4f0ff", "r": "#e43b44", "R": "#9e2835", "o": "#f77622", "y": "#feae34", "Y": "#c47b25",
    "l": "#63c74d", "L": "#2f7d3d", "c": "#2ce8f5", "b": "#3e8ed0", "B": "#234d8c", "p": "#c159c9",
    "P": "#6e2f7a", "m": "#f6757a", "s": "#f2c49b", "S": "#c98a64", "n": "#b86f50", "N": "#6e3f2e",
    "t": "#e4d2aa", "v": "#9d6bff", "V": "#5b3aa8",
}


def hexrgb(h):
    h = h.lstrip("#")
    a = int(h[6:8], 16) if len(h) == 8 else 255
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


def render(rows, recolor=None, name="?"):
    h = len(rows)
    w = len(rows[0])
    w = max(len(r) for r in rows) if name in ("?",) else w
    for i, r in enumerate(rows):
        if len(r) != w:
            ERRORS.append(f"{name}: строка {i} длиной {len(r)} вместо {w}: {r!r}")
    rows = [r.ljust(w, ".")[:w] for r in rows]
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch in ". ":
                continue
            if recolor and ch in recolor:
                ch = recolor[ch]
            if ch not in PAL:
                sys.exit(f"{name}: неизвестный цвет {ch!r}")
            img.putpixel((x, y), hexrgb(PAL[ch]))
    return img


def save(img, *parts, scale=1):
    path = os.path.join(ROOT, *parts)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if scale != 1:
        img = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
    img.save(path)


# ============================================================ карты (12×12)

CARDS = {
    "slime": [
        "............",
        "............",
        "............",
        "....kkkk....",
        "...kllllk...",
        "..kllwllLk..",
        "..klkllklLk.",
        ".kllllllllLk",
        ".kLllllllLLk",
        ".kLLLLLLLLLk",
        "..kkkkkkkkk.",
        "............",
    ],
    "spikes": [
        "............",
        "............",
        "..w...w...w.",
        "..G...G...G.",
        ".kGk.kGk.kGk",
        ".kgk.kgk.kgk",
        "kGgDkGgDkGgD",
        "kgDDkgDDkgDD",
        "kkkkkkkkkkkk",
        "dDdDdDdDdDdD",
        "dddddddddddd",
        "............",
    ],
    "bats": [
        "............",
        "............",
        "............",
        "k....kk....k",
        "kk..kPPk..kk",
        "kPk.kPPk.kPk",
        "kPPkPrrPkPPk",
        "kPPPPPPPPPPk",
        ".kPPkPPkPPk.",
        "..kk.kk.kk..",
        "............",
        "............",
    ],
    "ghost": [
        "............",
        "....kkkk....",
        "...kwwwwk...",
        "..kwwwwwwk..",
        "..kwkwwkwk..",
        "..kwkwwkwk..",
        "..kwwwwwwk..",
        "..kwwkkwwk..",
        "..kwwwwwwk..",
        "..kwGwwGwk..",
        "..kGkGGkGk..",
        "..k.k..k.k..",
    ],
    "skeleton": [
        "............",
        "...kkkkkk...",
        "..kwwwwwwk..",
        ".kwwwwwwwwk.",
        ".kwkkwwkkwk.",
        ".kwkkwwkkwk.",
        ".kwwwkkwwwk.",
        "..kwwwwwwk..",
        "...kwkwkk...",
        "...kwkwkwk..",
        "....kkkkk...",
        "............",
    ],
    "poison_fog": [
        "............",
        "............",
        "....kkk.....",
        "...klllk.kk.",
        "..kllllLkllk",
        ".kllwllllllk",
        ".klllllllLLk",
        "kLlllllLLLLk",
        "kLLLLLLLLLk.",
        ".kkkkkkkkk..",
        "...l..l..l..",
        "..l..l..l...",
    ],
    "false_chest": [
        "............",
        "............",
        "..kkkkkkkk..",
        ".knnnnnnnnk.",
        ".knNNNNNNnk.",
        ".kkkkyykkkk.",
        ".knnnyynnnk.",
        ".knnnkknnnk.",
        ".knnnnnnnnk.",
        ".kNNNNNNNNk.",
        "..kkkkkkkk..",
        "............",
    ],
    "torch": [
        "....kk......",
        "...kyk......",
        "...kyok.....",
        "..koyyok....",
        "..koywyok...",
        "...koook....",
        "....knk.....",
        "....knk.....",
        "....kNk.....",
        "...kGGGk....",
        "....kNk.....",
        "....kkk.....",
    ],
    "cave_in": [
        "..kkk.......",
        ".kgGgk..kk..",
        ".kgggk.kgGk.",
        "..kkk..kgdk.",
        "........kk..",
        "....kkk.....",
        "...kgGgk....",
        "...kgddk....",
        "....kkk.....",
        "..g...g..g..",
        "kkkkkkkkkkkk",
        "dDdDdDdDdDdD",
    ],
    "dark_ritual": [
        "............",
        ".....k......",
        "....kvk.....",
        "....kVk.....",
        "....kwk.....",
        "...kGGGk....",
        "...kGwGk....",
        "...kGGGk....",
        "..vkGGGkv...",
        ".v.kkkkk.v..",
        "..v.....v...",
        "...vvvvv....",
    ],
    "dark_gust": [
        "............",
        "...kkkkk....",
        "..kvvvvvk...",
        ".kvkkkkkvk..",
        ".kvk...kvk..",
        "..k..kkvk...",
        "....kvvk....",
        "...kvkk..k..",
        "..kvk...kvk.",
        "..kvvkkkvk..",
        "...kvvvvk...",
        "....kkkk....",
    ],
    "dark_altar": [
        "............",
        "....r..r....",
        "....y..y....",
        "....w..w....",
        "..kkkkkkkk..",
        ".kGGGGGGGGk.",
        ".kgvgggvggk.",
        ".kkkkkkkkkk.",
        "..kgDkkDgk..",
        "..kgDkkDgk..",
        ".kkkkkkkkkk.",
        "............",
    ],
    "mimic": [
        "............",
        "..kkkkkkkk..",
        ".knnnnnnnnk.",
        ".kNrNNNNrNk.",
        ".kwkwkwkwkk.",
        ".kRRRRRRRRk.",
        ".kRmmRRmmRk.",
        ".kwkwkwkwkk.",
        ".knnnyynnnk.",
        ".kNNNNNNNNk.",
        "..kkkkkkkk..",
        "............",
    ],
    "curse": [
        "............",
        "............",
        "...kkkkkk...",
        "..kPPPPPPk..",
        ".kPwwwwwwPk.",
        "kPwwkvvkwwPk",
        "kPwwvvvvwwPk",
        ".kPwwwwwwPk.",
        "..kPPPPPPk..",
        "...kkkkkk...",
        "............",
        "............",
    ],
    "zombie": [
        "............",
        "...kkkkkk...",
        "..klllllLk..",
        "..klkllkLk..",
        "..klrllrLk..",
        "..klllllLk..",
        "..kLkkkkLk..",
        "...kLLLLk...",
        "..kNNNNNNk..",
        ".klNNnnNNlk.",
        ".kk.kNNk.kk.",
        "....k..k....",
    ],
    "bone_wall": [
        "............",
        "kkkkkkkkkkkk",
        "kwGwkwwGkwGk",
        "kGwGkGwwkGwk",
        "kkkkkkkkkkkk",
        "kwwGkwGwwkGk",
        "kGwwkwwGwkwk",
        "kkkkkkkkkkkk",
        "kwGwkwGwkwwk",
        "kGwGkGwGkGwk",
        "kkkkkkkkkkkk",
        "............",
    ],
    "grave_whisper": [
        "............",
        "....kkkk....",
        "...kGGGGk...",
        "..kGGGGGGk..",
        "..kGgkkgGk..",
        "..kGkGGkGk..",
        "..kGgkkgGk..",
        "..kGGGGGGk..",
        "..kGgggggk..",
        ".kkkkkkkkkk.",
        "kLlLlLlLlLLk",
        "kkkkkkkkkkkk",
    ],
    "necro_circle": [
        "............",
        "....kkkk....",
        "..kkLllLkk..",
        ".kLk.ww.kLk.",
        ".kl.kwwk.lk.",
        "kL.kwkkwk.Lk",
        "kL.kwkkwk.Lk",
        ".kl.kwwk.lk.",
        ".kLk.ww.kLk.",
        "..kkLllLkk..",
        "....kkkk....",
        "............",
    ],
    "lich": [
        "..k.k.k.k...",
        "..kykykyk...",
        "..kyyyyyk...",
        "..kwwwwwwk..",
        ".kwwwwwwwwk.",
        ".kwkkwwkkwk.",
        ".kwkckkckwk.",
        ".kwwwkkwwwk.",
        "..kwwwwwwk..",
        ".kPkwkwkPk..",
        "kPPPkkkkPPk.",
        "kkkkkkkkkkk.",
    ],
    "acid_pool": [
        "............",
        "............",
        "............",
        "......l.....",
        ".....kwk....",
        "...kkkkkkk..",
        "..kllwllllk.",
        ".kllllllwllk",
        ".kLlllllllLk",
        "..kLLLLLLLk.",
        "...kkkkkkk..",
        "............",
    ],
    "poison_ivy": [
        "......kk....",
        ".....klLk...",
        "..kk.kLk....",
        ".kllkkLk.kk.",
        ".kLlLLk.kllk",
        "..kkkLk.kLLk",
        ".....kLkkk..",
        "...kkkLLk...",
        "..kllkLk....",
        "..kLLLLk....",
        "...kkkLk....",
        ".....kkk....",
    ],
    "slime_chimera": [
        "............",
        "...k....k...",
        "...pk..kp...",
        "....kkkk....",
        "...kppppk...",
        "..kpwkpwkk..",
        "..kpkkpkkPk.",
        ".kppppppppPk",
        ".kPpmmmmpPPk",
        ".kPPPPPPPPPk",
        "..kkkkkkkkk.",
        "............",
    ],
    "mutation_flask": [
        "............",
        "....kkkk....",
        "....kGGk....",
        "....kGGk....",
        "....kwGk....",
        "...kwGGGk...",
        "..kGllllGk..",
        "..klwlllLk..",
        "..kllllLLk..",
        "..kLLLLLLk..",
        "...kkkkkk...",
        "............",
    ],
    "cauldron": [
        "............",
        "...l..l.....",
        "..l..l..l...",
        "...kwkk.l...",
        ".kkkkkkkkkk.",
        "kdkllwlllkdk",
        ".kdddddddk..",
        ".kDdddddddk.",
        ".kDDddddddk.",
        "..kDDDdddk..",
        "..kk.kk.kk..",
        "............",
    ],
    "wolf": [
        "............",
        ".kk......kk.",
        ".kGk....kGk.",
        ".kGgkkkkgGk.",
        ".kggggggggk.",
        "kgggkggkgggk",
        "kgggyggyGggk",
        ".kgggggggk..",
        "..kgGGGGgk..",
        "..kgkwkwgk..",
        "...kggggk...",
        "....kkkk....",
    ],
    "bear_trap": [
        "............",
        "............",
        "k..........k",
        "kGk......kGk",
        "kGwk....kwGk",
        ".kGwk..kwGk.",
        ".kgGwkkwGgk.",
        "..kgGGGGgk..",
        "...kgggGk...",
        "kkkkkkkkkkkk",
        "dDdDdDdDdDdD",
        "............",
    ],
    "rat_swarm": [
        "............",
        "............",
        "..kk........",
        ".kGgkkkk....",
        ".kgggggggk..",
        "kgkgggggggk.",
        "kmggggggggk.",
        ".kkggggggk..",
        "..kgk..kgkmm",
        "..kk....kk.m",
        "............",
        "............",
    ],
    "spider_nest": [
        "k....k.....k",
        ".k...k....k.",
        "..k..k...k..",
        "...kkkkkk...",
        "kkkk.kk.kkkk",
        "...k.kk.k...",
        "..kkkkkkkk..",
        ".k..kPPk..k.",
        "k..kPrrPk..k",
        "...kkPPkk...",
        "..k..kk..k..",
        ".k........k.",
    ],
    "pendulum": [
        ".....kk.....",
        ".....kk.....",
        ".....kk.....",
        ".....kk.....",
        ".....kk.....",
        "...kkkkkk...",
        "..kGGGGGGk..",
        ".kGwwwwwwGk.",
        "kGwGGGGGGwGk",
        "kgGggggggGgk",
        ".kkgggggkkk.",
        "...kkkkkk...",
    ],
    "crusher": [
        "kkkkkkkkkkkk",
        "kdDdDdDdDdDk",
        "kkkkkkkkkkkk",
        "....kGGk....",
        "....kggk....",
        ".kkkkkkkkkk.",
        ".kGGGGGGGGk.",
        ".kggggggggk.",
        ".kkkkkkkkkk.",
        "............",
        "kkkkkkkkkkkk",
        "dDdDdDdDdDdD",
    ],
    "spring_plate": [
        "............",
        ".kkkkkkkkkk.",
        ".kGGGGGGGGk.",
        ".kkkkkkkkkk.",
        "...kGGGGk...",
        "....kggk....",
        "...kGGGGk...",
        "....kggk....",
        "...kGGGGk...",
        ".kkkkkkkkkk.",
        ".kddddddddk.",
        ".kkkkkkkkkk.",
    ],
    "flamethrower": [
        "............",
        "......kkk...",
        ".....koyok..",
        "....koywyok.",
        "...koyyyyk..",
        "..kooyyok...",
        "..kkkkk.....",
        ".kGGGk......",
        "kGgggk......",
        "kgdddk......",
        ".kkkk.......",
        "............",
    ],
    "gear": [
        "............",
        ".....kk.....",
        "..kk.kGk.kk.",
        "..kGkkGkkGk.",
        "...kGGGGGk..",
        ".kkGGkkkGGkk",
        ".kGGGk..kGGk",
        ".kkGGkkkGGkk",
        "...kGGGGGk..",
        "..kGkkGkkGk.",
        "..kk.kGk.kk.",
        ".....kk.....",
    ],
    "mech_golem": [
        "...kkkkkk...",
        "..kGGGGGGk..",
        "..kGckkcGk..",
        "..kGGGGGGk..",
        ".kkkkkkkkkk.",
        "kGkGGGGGGkGk",
        "kgkGyGGyGkgk",
        "kGkgggggkkGk",
        "kk.kGGGGk.kk",
        "...kGkkGk...",
        "..kgGk.kgGk.",
        "..kkkk.kkkk.",
    ],
    "kobold": [
        "............",
        "......kkk...",
        ".....kooyk..",
        "....kooykyk.",
        "....koooook.",
        "...kkoook...",
        "..kNNkook...",
        ".kNyNkook...",
        "..kNkoooook.",
        "...kook.kok.",
        "..kok....kk.",
        "..kk........",
    ],
    "lava": [
        "............",
        "............",
        "......y.....",
        ".....kok....",
        "...kkkkkkk..",
        "..kooyoooyk.",
        ".koyyyooooYk",
        ".kYoooooyoYk",
        ".kRYYYYYYYRk",
        "..kRRRRRRRk.",
        "...kkkkkkk..",
        "............",
    ],
    "dragon_scale": [
        "............",
        "..kkkkkkkk..",
        ".krrrrrrrRk.",
        ".krmrrrmrRk.",
        ".krrrrrrrRk.",
        ".kRrrmrrRRk.",
        "..kRrrrRRk..",
        "..kRRrRRRk..",
        "...kRRRRk...",
        "....kRRk....",
        ".....kk.....",
        "............",
    ],
    "treasure_lair": [
        "............",
        "............",
        "....kkk.....",
        "...kyyyk....",
        "..kkkkkkk...",
        ".kyyyywyyk..",
        "kyyYyyyyYyk.",
        "kYyyyYyyyyk.",
        "kyykkkkkyyYk",
        "kkkyyyyykkkk",
        "kyyyYyyyYyyk",
        "kkkkkkkkkkkk",
    ],
    "dragon_egg": [
        "............",
        "....kkkk....",
        "...kmwmmk...",
        "..kmwmmmmk..",
        "..kmmrmmmk..",
        ".kmmmmmrmmk.",
        ".kmrmmmmmmk.",
        ".kmmmmrmmRk.",
        ".kRmmmmmRRk.",
        "..kRRmmRRk..",
        "...kkkkkk...",
        "............",
    ],
    "dragon": [
        "..k.....k...",
        ".kyk...kyk..",
        ".krrkkkkrk..",
        "kRrrrrrrrrk.",
        "krrykrrrykrk",
        "krrrrrrrrrrk",
        ".krrrrwwwrrk",
        "..krrkwkwkk.",
        "..krrkkkk...",
        ".kRrrrk.....",
        "kRRRRk......",
        "kkkkk.......",
    ],
    "debris": [
        "............",
        "............",
        "............",
        "....kkk.....",
        "...kgGgk.kk.",
        "...kgddkkgGk",
        "..kkkkkkkgdk",
        ".kgGgk.kgkk.",
        ".kgdgkkgGgk.",
        "kkkkkkkkkkkk",
        "dDdDdDdDdDdD",
        "............",
    ],
    "coward_squire": [
        "............",
        "...kkkkkk...",
        "..kGGGGGGk..",
        "..kGkkkkGk..",
        "..kkswswkk..",
        "...kssssk...",
        "...kkkkkk...",
        "..kbbbbbbk..",
        ".ksbbBBbbsk.",
        "..kbbbbbbk..",
        "..kNNkkNNk..",
        "..kkk..kkk..",
    ],
    "usurper_crown": [
        "............",
        "............",
        "............",
        ".k...k...k..",
        "kyk.kyk.kyk.",
        "kyykkyykkyyk",
        "kyyyyryyyyyk",
        "kyyrrrryyyyk",
        "kyyyyryyyyyk",
        "kYYYYYYYYYYk",
        "kkkkkkkkkkkk",
        "............",
    ],
    "wine_barrel": [
        "............",
        "...kkkkkk...",
        "..knnnnnnk..",
        ".kNNNNNNNNk.",
        ".knnnnnnnnk.",
        ".knnnkknnnk.",
        ".knnkRRknnk.",
        ".knnnkknnnk.",
        ".kNNNNNNNNk.",
        ".knnnnnnnnk.",
        "..kkkkkkkk..",
        "............",
    ],
    "grate": [
        "kkkkkkkkkkkk",
        "kGGGGGGGGGGk",
        "kgkgkgkgkgkk",
        "kgkgkgkgkgkk",
        "kGGGGGGGGGGk",
        "kgkgkgkgkgkk",
        "kgkgkgkgkgkk",
        "kGGGGGGGGGGk",
        "kgkgkgkgkgkk",
        "kgkgkgkgkgkk",
        "kGkGkGkGkGkk",
        "k.k.k.k.k.k.",
    ],
    "mine_cart": [
        "............",
        "...kk.kk....",
        "..kgGkGgk...",
        "kkkkkkkkkkk.",
        "knnnnnnnnnk.",
        "kNnnnnnnnNk.",
        ".kNNNNNNNk..",
        ".kkkkkkkkk..",
        "..kgk..kgk..",
        "..kkk..kkk..",
        "kkkkkkkkkkkk",
        "dDdDdDdDdDdD",
    ],
    "gas_pocket": [
        "............",
        ".......kk...",
        "......klLk..",
        "..kk...kk...",
        ".kllk.......",
        ".kLlk..kkk..",
        "..kk..klllk.",
        "......klwlk.",
        "...o..kLllk.",
        "..oyo..kkk..",
        "kkkkkkkkkkkk",
        "dDdDdDdDdDdD",
    ],
    "sarcophagus": [
        "...kkkkkk...",
        "..kyyyyyyk..",
        ".kyYkyykYyk.",
        ".kyyyyyyyyk.",
        ".kYkyyyykYk.",
        ".kyYrrrrYyk.",
        ".kyyyyyyyyk.",
        ".kYyyyyyyYk.",
        "..kyYyyYyk..",
        "..kYyyyyYk..",
        "...kkkkkk...",
        "............",
    ],
    "electric_eel": [
        "........kk..",
        ".......kyk..",
        "......kyk...",
        ".....kyyyk..",
        "..kkk..kyk..",
        ".kbbbk.kk...",
        "kbwbbbk..kk.",
        "kbbbbBBkkbBk",
        ".kBBBbbbBBk.",
        "..kkkBBBBk..",
        ".....kkkk...",
        "............",
    ],
    "icicle": [
        "kkkkkkkkkkkk",
        "kcwcccwcccck",
        ".kccbkccbck.",
        ".kcbk.kcbk..",
        "..kck.kck...",
        "..kbk..kk...",
        "..kck.......",
        "...k........",
        "........w...",
        "............",
        "....w.......",
        "............",
    ],
    "snow_golem": [
        "....kkkk....",
        "...kwwwwk...",
        "...kwkwkk...",
        "...kwwowk...",
        "....kkkk....",
        "..kkwwwwkk..",
        "nkwwwkwwwwkn",
        ".nkwwwwwwkn.",
        "..kwwkwwwk..",
        ".kwwwwwwwwk.",
        ".kGwwwwwwGk.",
        "..kkkkkkkk..",
    ],
    "geyser": [
        "...b..b..b..",
        "..b.cbbc.b..",
        "....bwcb....",
        "...kbccbk...",
        "....kcck....",
        "....kbbk....",
        "....kcbk....",
        "...kbccbk...",
        "..kkkkkkkk..",
        ".kgGgkkgGgk.",
        "kkkkkkkkkkkk",
        "dDdDdDdDdDdD",
    ],
}

# Перекраски уже нарисованных шаблонов
DERIVED = {
    "banshee": ("ghost", {"w": "c", "G": "b"}),
    "pack_leader": ("wolf", {"g": "D", "G": "g", "y": "r"}),
    "alpha_beast": ("wolf", {"g": "N", "G": "n", "y": "r", "w": "y"}),
    "catalyst": ("mutation_flask", {"l": "p", "L": "P"}),
    "bone_dust": ("debris", {"g": "G", "G": "w", "d": "g"}),
    "whirlpool": ("dark_gust", {"v": "b"}),
    "lava_golem": ("mech_golem", {"G": "o", "g": "R", "c": "y", "y": "r"}),
}

# ============================================================ герои (12×12)

HERO_BASE = [
    "...kkkkkk...",
    "..kHHHHHHk..",
    "..kHssssHk..",
    "..kskssksk..",
    "..kssssssk..",
    "...kkkkkk...",
    "..kAAAAAAk..",
    ".ksAAaaAAsk.",
    ".kskAAAAksk.",
    "..kaaaaaak..",
    "..kLLkkLLk..",
    "..kkk..kkk..",
]

OVERLAYS = {
    "sword": (10, 1, ["k.", "w", "w", "w", "G", "y", "N"]),
    "dagger": (10, 5, ["w", "G", "y"]),
    "staff": (10, 0, ["kc", "cw", "N.", "N.", "N.", "N.", "N.", "N.", "N."]),
    "shield": (0, 6, ["kk.", "yGk", "Gyk", "kk."]),
    "bow": (9, 3, [".kn", "k.n", "k.n", "k.n", ".kn"]),
    "holy": (5, 7, ["y", "y"]),
    "axe": (9, 2, ["kGk", "GGk", "kNk", ".N.", ".N.", ".N."]),
    "lute": (9, 6, [".n", "ynn", "nnn"]),
    "hat": (2, 0, ["..kbbk..", "kbbbbbbk"]),
    "feather": (8, 0, ["m.", ".m"]),
    "crown": (3, 0, ["kykyky"]),
    "horns": (1, 0, ["r........r", ".r......r."]),
    "hammer": (9, 3, ["kkk", "GGk", ".N.", ".N.", ".N."]),
    "flask": (10, 6, ["G", "l"]),
    "cape": (1, 6, ["r.........r", "r.........r", "r.........r"]),
    "pick": (9, 2, ["GGG", ".N.", ".N.", ".N."]),
    "net": (9, 5, ["kGk", "GkG", "kGk"]),
    "trident": (9, 1, ["c.c", "ccc", ".N.", ".N.", ".N.", ".N."]),
    "whip": (9, 6, ["n..", ".n.", "..n"]),
    "rune": (5, 7, ["c", "c"]),
    "eyes_red": (4, 3, ["r..r"]),
    "eyes_glow": (4, 3, ["c..c"]),
}

HEROES = {
    # классы
    "warrior": ({"H": "g", "A": "r", "a": "R", "L": "N"}, ["sword"]),
    "thief": ({"H": "d", "A": "L", "a": "k", "L": "d"}, ["dagger"]),
    "mage": ({"H": "b", "A": "b", "a": "B", "L": "B"}, ["hat", "staff"]),
    "paladin": ({"H": "y", "A": "G", "a": "y", "L": "g"}, ["shield", "sword"]),
    "archer": ({"H": "l", "A": "L", "a": "N", "L": "N"}, ["bow"]),
    "priest": ({"H": "w", "A": "w", "a": "y", "L": "G"}, ["holy"]),
    "barbarian": ({"H": "o", "A": "s", "a": "N", "L": "N"}, ["axe"]),
    "bard": ({"H": "p", "A": "p", "a": "P", "L": "P"}, ["feather", "lute"]),
    # местные
    "ratcatcher": ({"H": "N", "A": "n", "a": "N", "L": "N"}, ["net"]),
    "squire": ({"H": "g", "A": "b", "a": "B", "L": "N"}, ["dagger"]),
    "gnome_sapper": ({"H": "r", "A": "n", "a": "N", "L": "N"}, ["pick"]),
    "prospector": ({"H": "Y", "A": "t", "a": "n", "L": "N"}, ["pick"]),
    "undead_hunter": ({"H": "d", "A": "D", "a": "k", "L": "k"}, ["sword"]),
    "tomb_raider": ({"H": "n", "A": "t", "a": "N", "L": "N"}, ["whip"]),
    "diver": ({"H": "c", "A": "b", "a": "B", "L": "B"}, ["trident"]),
    "tide_priestess": ({"H": "c", "A": "c", "a": "b", "L": "b"}, ["staff"]),
    "firefighter": ({"H": "R", "A": "o", "a": "R", "L": "N"}, ["axe"]),
    "dragon_tamer": ({"H": "N", "A": "R", "a": "N", "L": "N"}, ["whip"]),
    "north_ranger": ({"H": "w", "A": "G", "a": "b", "L": "B"}, ["bow"]),
    "rune_smith": ({"H": "D", "A": "g", "a": "d", "L": "d"}, ["hammer", "rune"]),
    # боссы
    "sir_fearless": ({"H": "G", "A": "G", "a": "y", "L": "g"}, ["cape", "crown", "shield", "sword"]),
    "dorn": ({"H": "y", "A": "n", "a": "N", "L": "N"}, ["crown", "hammer"]),
    "olwen": ({"H": "V", "A": "V", "a": "v", "L": "V"}, ["cape", "crown", "staff", "eyes_glow"]),
    "mika": ({"H": "R", "A": "r", "a": "k", "L": "k"}, ["crown", "sword"]),
    "aurelius": ({"H": "y", "A": "w", "a": "y", "L": "y"}, ["cape", "crown", "shield", "sword"]),
    "irsa": ({"H": "c", "A": "w", "a": "c", "L": "b"}, ["crown", "bow"]),
    "chosen": ({"H": "w", "A": "w", "a": "y", "L": "G", "s": "G"}, ["cape", "crown", "sword", "eyes_glow"]),
}

MASTERS = {
    "dark_lord": ({"H": "P", "A": "P", "a": "k", "L": "k", "s": "k"}, ["horns", "eyes_red", "cape"]),
    "necromancer": ({"H": "L", "A": "d", "a": "L", "L": "k", "s": "G"}, ["staff", "eyes_glow"]),
    "goblin_king": ({"H": "y", "A": "R", "a": "y", "L": "N", "s": "l"}, ["crown", "eyes_red"]),
    "alchemist": ({"H": "N", "A": "t", "a": "l", "L": "N"}, ["flask"]),
    "smith": ({"H": "N", "A": "n", "a": "k", "L": "N"}, ["hammer"]),
    "dragoness": ({"H": "r", "A": "R", "a": "y", "L": "R"}, ["horns", "cape"]),
}


def hero_img(spec, name):
    pal, overlays = spec
    rows = [list(r) for r in HERO_BASE]
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            if ch in pal:
                rows[y][x] = pal[ch]
    for o in overlays:
        ox, oy, art = OVERLAYS[o]
        for dy, line in enumerate(art):
            for dx, ch in enumerate(line):
                if ch == ".":
                    continue
                x, y = ox + dx, oy + dy
                if 0 <= x < 12 and 0 <= y < 12:
                    rows[y][x] = ch
    return render(["".join(r) for r in rows], name=name)


# ============================================================ реликвии (12×12)

RELICS = {
    "tyrant_crown": [
        "............",
        "............",
        ".k...k...k..",
        "kvk.kvk.kvk.",
        "kvvkkvvkkvvk",
        "kvvvvrvvvvvk",
        "kvvrrrrrvvvk",
        "kvvvvrvvvvvk",
        "kVVVVVVVVVVk",
        "kkkkkkkkkkkk",
        "............",
        "............",
    ],
    "old_key": [
        "............",
        "..kkkk......",
        ".kyyyyk.....",
        "kyykkyyk....",
        "kyk..kyk....",
        "kyykkyyk....",
        ".kyyyyYkkkkk",
        "..kkkkYyyyyk",
        "......kkYkYk",
        ".......kYkYk",
        "........k.k.",
        "............",
    ],
    "coin_bag": [
        "....kkkk....",
        "...knNNnk...",
        "....kNNk....",
        "...kkkkkk...",
        "..knnnnnnk..",
        ".knnnyynnnk.",
        ".knnyYYynnk.",
        ".knnnyynnnk.",
        ".knnnnnnnnk.",
        ".kNnnnnnnNk.",
        "..kNNNNNNk..",
        "...kkkkkk...",
    ],
    "pact_scroll": [
        "............",
        ".kkkkkkkkk..",
        "ktttttttttk.",
        ".ktNtNNtNtk.",
        ".kttttttttk.",
        ".ktNNtNNtk..",
        ".kttttttttk.",
        ".ktNtNNrrk..",
        ".ktttttrrk..",
        "ktttttttttk.",
        ".kkkkkkkkk..",
        "............",
    ],
    "blood_chalice": [
        "............",
        ".kkkkkkkkkk.",
        ".kyrrrrrryk.",
        ".kyrrmrrryk.",
        "..kyrrrryk..",
        "...kyyyyk...",
        "....kyyk....",
        "....kYYk....",
        "....kyyk....",
        "..kkyyyykk..",
        "..kYYYYYYk..",
        "..kkkkkkkk..",
    ],
    "heart_stone": [
        "............",
        "............",
        ".kkk...kkk..",
        "kgGgk.kgGgk.",
        "kGwggkggggk.",
        "kgggggggggk.",
        "kggggrgggDk.",
        ".kgggggggk..",
        "..kgggDgk...",
        "...kgDDk....",
        "....kDk.....",
        ".....k......",
    ],
    "blood_ruby": [
        "............",
        "...kkkkkk...",
        "..kmwrrrRk..",
        ".kmwrrrrrRk.",
        "kkkkkkkkkkkk",
        "kRrrrmrrrrRk",
        ".kRrrrrrrRk.",
        "..kRrrrrRk..",
        "...kRrrRk...",
        "....kRRk....",
        ".....kk.....",
        "............",
    ],
    "night_cloak": [
        "....kkkk....",
        "...kVVVVk...",
        "..kVkkkkVk..",
        "..kVkyykVk..",
        ".kVVkkkkVVk.",
        ".kVvVVVVvVk.",
        "kVVvVVVVvVVk",
        "kVvVVVVVVvVk",
        "kVvVVVVVVvVk",
        "kVVVVVVVVVVk",
        "kVkVVkkVVkVk",
        "kk.kk..kk.kk",
    ],
    "resin_drop": [
        ".....k......",
        "....kyk.....",
        "....kyk.....",
        "...kyyyk....",
        "...kyyyk....",
        "..kyywyYk...",
        "..kywyyYk...",
        ".kyyyyyYYk..",
        ".kyyyyYYYk..",
        ".kYyyyYYYk..",
        "..kYYYYYk...",
        "...kkkkk....",
    ],
    "hourglass": [
        ".kkkkkkkkkk.",
        ".kNNNNNNNNk.",
        "..kccccccK..".replace("K", "k"),
        "..kcyyyyck..",
        "...kcyyck...",
        "....kcyk....",
        "....kcck....",
        "...kcccck...",
        "..kcccyyck..",
        "..kcyyyyyk..",
        ".kNNNNNNNNk.",
        ".kkkkkkkkkk.",
    ],
    "mirror_shard": [
        "............",
        "......kk....",
        ".....kcwk...",
        "....kcwcck..",
        "...kcwccbk..",
        "..kcwccbk...",
        ".kcwccbk....",
        ".kwccbk.....",
        ".kccbk......",
        "..kbk.......",
        "...k........",
        "............",
    ],
    "dark_throne": [
        ".kk......kk.",
        ".kPk....kPk.",
        ".kPkkkkkkPk.",
        ".kPvvvvvvPk.",
        ".kPvVVVVvPk.",
        ".kPvVVVVvPk.",
        ".kPkkkkkkPk.",
        "kPPPPPPPPPPk",
        "kkkkkkkkkkkk",
        ".kPk....kPk.",
        ".kPk....kPk.",
        ".kkk....kkk.",
    ],
    "fear_bell": [
        ".....kk.....",
        "....kNNk....",
        "...kkkkkk...",
        "..kyyyyyyk..",
        "..kywyyyyk..",
        "..kywyyyyk..",
        ".kyyyyyyyYk.",
        ".kyyyyyyyYk.",
        "kyyyyyyyyYYk",
        "kkkkkkkkkkkk",
        ".....kYk....",
        "......k.....",
    ],
    "luck_bone": [
        "............",
        "............",
        ".kk......kk.",
        "kwwk....kwwk",
        "kwwwkkkkwwwk",
        ".kwwwwwwwwk.",
        ".kwGwwwwwGk.",
        "kwwwkkkkwwwk",
        "kwwk....kwwk",
        ".kk......kk.",
        "............",
        "............",
    ],
}


# ============================================================ узлы карты (12×12)

NODES = {
    "battle": [
        "k..........k",
        "kwk......kwk",
        ".kwk....kwk.",
        "..kwk..kwk..",
        "...kwkkwk...",
        "....kwwk....",
        "....kwwk....",
        "...kwkkwk...",
        "..kyk..kyk..",
        ".kNk....kNk.",
        "kyk......kyk",
        "kk........kk",
    ],
    "elite": [
        "k.........k.",
        "rk.......kr.",
        "rrkkkkkkkrr.",
        ".kwwwwwwwk..",
        "kwwwwwwwwwk.",
        "kwkkwwwkkwk.",
        "kwkrkwkrkwk.",
        "kwwwwkwwwwk.",
        ".kwwwwwwwk..",
        "..kwkwkwk...",
        "..kkkkkkk...",
        "............",
    ],
    "shop": [
        "....kkkk....",
        "...knNNnk...",
        "....kNNk....",
        "...kkkkkk...",
        "..knnnnnnk..",
        ".knnnyynnnk.",
        ".knnyYYynnk.",
        ".knnnyynnnk.",
        ".knnnnnnnnk.",
        ".kNnnnnnnNk.",
        "..kNNNNNNk..",
        "...kkkkkk...",
    ],
    "altar": [
        ".....k......",
        "....kvk.....",
        "...kvwvk....",
        "....kvk.....",
        ".....k......",
        "..kkkkkkkk..",
        ".kGGGGGGGGk.",
        ".kkkkkkkkkk.",
        "..kgDkkDgk..",
        "..kgDkkDgk..",
        ".kkkkkkkkkk.",
        "............",
    ],
    "event": [
        "............",
        "...kkkkkk...",
        "..kbbbbbbk..",
        "..kbkkkkbk..",
        "..kkk..kbk..",
        "......kbbk..",
        ".....kbbk...",
        ".....kbk....",
        ".....kkk....",
        ".....kbk....",
        ".....kkk....",
        "............",
    ],
    "treasure": [
        "............",
        "............",
        "..kkkkkkkk..",
        ".knnnnnnnnk.",
        ".knNNNNNNnk.",
        ".kkkkyykkkk.",
        ".knnnyynnnk.",
        ".knnnkknnnk.",
        ".knnnnnnnnk.",
        ".kNNNNNNNNk.",
        "..kkkkkkkk..",
        "............",
    ],
    "boss": [
        "..k.k.k.k...",
        "..kykykyk...",
        "..kyyyyyk...",
        "..kwwwwwwk..",
        ".kwwwwwwwwk.",
        ".kwkkwwkkwk.",
        ".kwkrkkrkwk.",
        ".kwwwkkwwwk.",
        "..kwwwwwwk..",
        "...kwkwkk...",
        "...kkkkkk...",
        "............",
    ],
}

# ============================================================ значки (8×8)

ICONS = {
    "heart": [
        "........",
        ".kk.kk..",
        "krrkrrk.",
        "krwrrrk.",
        "krrrrrk.",
        ".krrrk..",
        "..krk...",
        "...k....",
    ],
    "sword": [
        "......kk",
        ".....kwk",
        "....kwk.",
        "k..kwk..",
        "kk kwk..".replace(" ", "."),
        ".kyk....",
        "kNkk....",
        "kk......",
    ],
    "coin": [
        "..kkkk..",
        ".kyyyyk.",
        "kyywyyYk",
        "kyywyyYk",
        "kyyyyyYk",
        "kYyyyYYk",
        ".kYYYYk.",
        "..kkkk..",
    ],
    "soul": [
        "...k....",
        "..kck...",
        "..kcck..",
        ".kcwck..",
        ".kcwwck.",
        "kbcwwcbk",
        ".kbccbk.",
        "..kkkk..",
    ],
    "dark": [
        "...kk...",
        "..kvwk..",
        ".kvvwvk.",
        ".kvvvVk.",
        ".kvvVVk.",
        ".kVvVVk.",
        "..kVVk..",
        "...kk...",
    ],
    "dark_off": [
        "...kk...",
        "..kDdk..",
        ".kDddDk.",
        ".kddddk.",
        ".kddddk.",
        ".kddddk.",
        "..kddk..",
        "...kk...",
    ],
    "armor": [
        "kkkkkkk.",
        "kGGwGGk.",
        "kGgwgGk.",
        "kGgggGk.",
        ".kGggk..",
        ".kGgGk..",
        "..kGk...",
        "...k....",
    ],
    "greed": [
        "..kkk...",
        ".kNnNk..",
        "..kNk...",
        ".knnnk..",
        "knnynnk.",
        "knyYynk.",
        "knnynnk.",
        ".kkkkk..",
    ],
    "slow": [
        "...kk...",
        "..kcck..",
        ".kcwcck.",
        "kcwccbk.",
        "kccccbk.",
        "kbccbbk.",
        ".kbbbk..",
        "..kkk...",
    ],
    "poison": [
        "...k....",
        "..klk...",
        "..klk...",
        ".kllLk..",
        "kllwlLk.",
        "klllLLk.",
        ".kLLLk..",
        "..kkk...",
    ],
    "burn": [
        "...k....",
        "..kok...",
        "..koyk..",
        ".koyyok.",
        "koywyyok",
        "koyyyyok",
        ".kooook.",
        "..kkkk..",
    ],
    "vuln": [
        "kkkkkkk.",
        "kGGkGGk.",
        "kGkgkGk.",
        "kGgk.Gk.",
        ".kGkgk..",
        ".kGgGk..",
        "..kGk...",
        "...k....",
    ],
    "stun": [
        "...k....",
        "..kyk...",
        "kkkykkk.",
        "kyyyyyk.",
        ".kyyyk..",
        ".kykyk..",
        "kyk.kyk.",
        "kk...kk.",
    ],
    "curse": [
        "..kkkk..",
        ".kPPPPk.",
        "kPwwwwPk",
        "kPwvvwPk",
        "kPwvvwPk",
        "kPwwwwPk",
        ".kPPPPk.",
        "..kkkk..",
    ],
    "fear": [
        "..kkkk..",
        ".kwwwwk.",
        "kwkwwkwk",
        "kwkwwkwk",
        "kwwwwwwk",
        "kwwkkwwk",
        ".kwkkwk.",
        "..kkkk..",
    ],
    "lock": [
        "..kkk...",
        ".kG.Gk..",
        ".kG.Gk..",
        "kkkkkkk.",
        "kyyyyyk.",
        "kyykyyk.",
        "kYYYYYk.",
        "kkkkkkk.",
    ],
    "torch": [
        "..kk....",
        ".koyk...",
        ".kyyok..",
        "..kyk...",
        "..knk...",
        "..knk...",
        ".kGGGk..",
        "..kNk...",
    ],
}


# ============================================================ сундуки и меню

CHEST_CLOSED = [
    "...kkkkkkkkkk...",
    "..k4411111111k..",
    ".k111111111111k.",
    "k22222222222222k",
    "k11111111111111k",
    "kkkkkkyyyykkkkkk",
    "k2222kykkyk2222k",
    "k1111kyyyyk1111k",
    "k11111kkkk11111k",
    "k11111111111111k",
    "k22222222222222k",
    "k33333333333333k",
    "kkkkkkkkkkkkkkkk",
]
CHEST_OPEN = [
    ".kkkkkkkkkkkkkk.",
    ".k441111111111k.",
    ".k222222222222k.",
    "kkkkkkkkkkkkkkkk",
    "kKKyKwKKyKKwKyKk",
    "kyyyyyyyyyyyyyyk",
    "k22222222222222k",
    "k11111111111111k",
    "k11111kyyk11111k",
    "k11111111111111k",
    "k22222222222222k",
    "k33333333333333k",
    "kkkkkkkkkkkkkkkk",
]
CHESTS = {
    "wood": {"1": "n", "2": "G", "3": "N", "4": "t"},
    "silver": {"1": "g", "2": "G", "3": "D", "4": "w"},
    "gold": {"1": "y", "2": "n", "3": "Y", "4": "w"},
    "magic": {"1": "p", "2": "c", "3": "P", "4": "m"},
    "legendary": {"1": "o", "2": "y", "3": "R", "4": "w"},
}

MENU_ICONS = {
    "gem": [
        "..kkkk..",
        ".kwllLk.",
        "kwllllLk",
        "kllllLLk",
        ".kllLLk.",
        "..klLk..",
        "...kk...",
        "........",
    ],
    "tab_deck": [
        "...kkkkk",
        "...krrrk",
        "kkkkkrrk",
        "kbbbkrrk",
        "kbwbkrrk",
        "kbbbkkkk",
        "kbbbk...",
        "kkkkk...",
    ],
    "tab_castle": [
        "k.k..k.k",
        "kkk..kkk",
        "kGk..kGk",
        "kGkkkkGk",
        "kGGGGGGk",
        "kGGkkGGk",
        "kGkNNkGk",
        "kkkkkkkk",
    ],
    "tab_trophy": [
        "kkkkkkkk",
        "kywyyyYk",
        ".kwyyYk.",
        ".kyyyYk.",
        "..kyYk..",
        "...kk...",
        "..kYYk..",
        ".kkkkkk.",
    ],
    "tab_shop": [
        "...kk...",
        "..kNNk..",
        "...kk...",
        ".knnnnk.",
        "knnyynNk",
        "knnyynNk",
        "knnnnnNk",
        ".kkkkkk.",
    ],
    "pause": [
        "kkkkk..kkkkk",
        "kwGgk..kwGgk",
        "kwGgk..kwGgk",
        "kwGgk..kwGgk",
        "kwGgk..kwGgk",
        "kwGgk..kwGgk",
        "kwGgk..kwGgk",
        "kwGgk..kwGgk",
        "kwGgk..kwGgk",
        "kgggk..kgggk",
        "kkkkk..kkkkk",
    ],
    "tab_battle": [
        "k......k",
        "kwk..kwk",
        ".kwkkwk.",
        "..kwwk..",
        "..kwwk..",
        ".kNkkNk.",
        "kNk..kNk",
        "kk....kk",
    ],
    "gear": [
        "...kk...",
        ".kkGGkk.",
        ".kGGGGk.",
        "kGGkkGGk",
        "kGGkkGGk",
        ".kGGGGk.",
        ".kkGGkk.",
        "...kk...",
    ],
}


# ============================================================ рамки (9-patch, ×2)

def frame(fill, border="k", light=None, shadow=None, size=12, b=3):
    """Пиксельная рамка: срезанные углы, обводка, блик сверху-слева, тень снизу."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    F, B = hexrgb(fill), hexrgb(PAL.get(border, border))
    L = hexrgb(light) if light else None
    S = hexrgb(shadow) if shadow else None
    for y in range(size):
        for x in range(size):
            corner = (x in (0, size - 1)) and (y in (0, size - 1))
            if corner:
                continue
            edge = x == 0 or y == 0 or x == size - 1 or y == size - 1
            if edge:
                img.putpixel((x, y), B)
            elif L and (y == 1 or x == 1) and not (x == size - 2 or y == size - 2):
                img.putpixel((x, y), L)
            elif S and (y == size - 2 or x == size - 2):
                img.putpixel((x, y), S)
            else:
                img.putpixel((x, y), F)
    return img


def frames():
    out = {
        "panel": frame("#241c30", "k", "#33294a", "#1c1626"),
        "panel_dark": frame("#16111d", "k", None, "#241c30"),
        "panel_light": frame("#30264a", "k", "#463a66", "#241c30"),
        "popup": frame("#211a2c", "#feae34", "#33294a", "#1c1626"),
        "btn": frame("#45385a", "k", "#65558a", "#2b2236"),
        "btn_hover": frame("#55467a", "k", "#7a68a8", "#2b2236"),
        "btn_pressed": frame("#2b2236", "k", "#1c1626", "#45385a"),
        "btn_disabled": frame("#2a2433", "#2b2236", None, None),
        "btn_red": frame("#9e2835", "k", "#e43b44", "#5c1720"),
        "btn_red_hover": frame("#b8303f", "k", "#f6757a", "#5c1720"),
        "btn_green": frame("#2f7d3d", "k", "#63c74d", "#1b4a24"),
        "btn_green_hover": frame("#3a9449", "k", "#8ade72", "#1b4a24"),
        "btn_gold": frame("#a8641c", "k", "#feae34", "#5e3810"),
        "btn_gold_hover": frame("#c47b25", "k", "#ffd27a", "#5e3810"),
        "btn_purple": frame("#6e2f7a", "k", "#c159c9", "#3c1844"),
        "btn_purple_hover": frame("#843a92", "k", "#e08ae6", "#3c1844"),
        "btn_blue": frame("#234d8c", "k", "#3e8ed0", "#132a4d"),
        "btn_blue_hover": frame("#2c5ea8", "k", "#6fb2ea", "#132a4d"),
        "card_selected": frame("#2b2236", "#f4f0ff", "#45385a", None),
        "slot": frame("#00000000", "#2b2236", None, None),
        "slot_ok": frame("#63c74d22", "#63c74d", None, None),
        "bar_bg": frame("#16111d", "k", None, None, size=8, b=2),
        "bar_hp": frame("#e43b44", "#9e2835", "#f6757a", None, size=8, b=2),
    }
    for k, img in out.items():
        save(img, "ui", k + ".png", scale=2)
    card_art()


# ============================================================ рамки карт, редкость, тип

def hexmap_render(rows, cmap, name):
    """Рисует шаблон, где буквы — ключи cmap (hex-цвета); '.' — прозрачно."""
    w = len(rows[0])
    img = Image.new("RGBA", (w, len(rows)), (0, 0, 0, 0))
    for y, r in enumerate(rows):
        if len(r) != w:
            ERRORS.append(f"{name}: строка {y} длиной {len(r)}")
        for x, ch in enumerate(r):
            if ch != ".":
                img.putpixel((x, y), hexrgb(cmap[ch]))
    return img


# Рамка карты 24×24: по краю — узор типа (повторяется при растяжении), в углах — украшение 6×6.
CARD_BANDS = {   # 4 ряда от края внутрь, период 8: цветная полоса с узором
    "trap": ["kkkkkkkk", "BBOOBBBB", "BBOOBBBB", "BBBBBBBB"],        # заклёпки
    "monster": ["kkkkkkkk", "BBBBBBBB", "BwwwBBBB", "DDwDDDDD"],     # клыки
    "room": ["kkkkkkkk", "BBBDBBBB", "BBBDBBBB", "DDDDDDDD"],        # кладка
    "spell": ["kkkkkkkk", "BBBOOBBB", "BBBOOBBB", "BBBBBBBB"],       # светящиеся руны
}
CARD_CORNERS = {
    "trap": ["kkkkkk", "kBBBBB", "kBwOBB", "kBOOBB", "kBBBFF", "kBBBFF"],
    "monster": ["kkkkkk", "kBBBBB", "kBwwBB", "kBwwwD", "kBBwwF", "kBBDwF"],
    "room": ["kkkkkk", "kOOOOB", "kOyyOB", "kOyyOD", "kOOOOF", "kBBDFF"],
    "spell": ["..kkkk", ".kBOBB", "kBOOOB", "kBBOBB", "kBBBFF", "kBBBFF"],
}
CARD_COLORS = {
    "trap": {"B": "#8b7fa3", "O": "#c2b8d6", "w": "#f4f0ff", "D": "#2b2236"},
    "monster": {"B": "#e43b44", "w": "#f4f0ff", "D": "#5c1720"},
    "room": {"B": "#c159c9", "O": "#feae34", "y": "#fff3b0", "D": "#3c1844"},
    "spell": {"B": "#3e8ed0", "O": "#2ce8f5", "D": "#132a4d"},
}


def card_frame(kind):
    n = 24
    band = CARD_BANDS[kind]
    rows = [["F"] * n for _ in range(n)]
    for y in range(n):
        for x in range(n):
            # расстояние до ближайшего края и позиция вдоль этого края
            d, along = min((y, x), (n - 1 - y, x), (x, y), (n - 1 - x, y))
            if d < 4:
                rows[y][x] = band[d][along % 8]
    tl = CARD_CORNERS[kind]
    for y in range(6):
        for x in range(6):
            ch = tl[y][x]
            rows[y][x] = ch
            rows[y][n - 1 - x] = ch
            rows[n - 1 - y][x] = ch
            rows[n - 1 - y][n - 1 - x] = ch
    cmap = {"k": "#18141e", "F": "#1c1626", ".": "#00000000"}
    cmap.update(CARD_COLORS[kind])
    return hexmap_render(["".join(r) for r in rows], cmap, "card_" + kind)


GEM = ["..kkk..", ".kLCCk.", "kLCCCCk", "kCCCCDk", ".kCCDk.", "..kDk..", "...k..."]
RARITY_GEMS = {
    "common": {"C": "#b0b0b0", "L": "#f4f0ff", "D": "#6b6577"},
    "rare": {"C": "#4a9ae0", "L": "#9fd0ff", "D": "#234d8c"},
    "epic": {"C": "#b060e0", "L": "#e08ae6", "D": "#6e2f7a"},
    "legendary": {"C": "#f0a020", "L": "#ffe08a", "D": "#c47b25"},
    "special": {"C": "#60c0a0", "L": "#a8f0d8", "D": "#2f7d5d"},
}

TYPE_ICONS = {
    "trap": (["...k....", "..kGk...", "..kGk.k.", ".kGGGkGk", ".kGGGkGk", "kGGGGGGk", "kkkkkkkk", "........"],
             {"k": "#18141e", "G": "#c2b8d6"}),
    "monster": ([".kkkkkk.", "kwwwwwwk", "kwrwwrwk", "kwwwwwwk", ".kwwwwk.", ".kwkkwk.", "..k..k..", "........"],
                {"k": "#18141e", "w": "#f4f0ff", "r": "#e43b44"}),
    "room": (["..kkkk..", ".kPPPPk.", "kPppppPk", "kPppppPk", "kPpppyPk", "kPppppPk", "kPppppPk", "kkkkkkkk"],
             {"k": "#18141e", "P": "#6e2f7a", "p": "#c159c9", "y": "#feae34"}),
    "spell": (["..kkkk..", "...kk...", "..kbbk..", ".kbccbk.", "kbcccbbk", "kbccccbk", ".kbbbbk.", "..kkkk.."],
              {"k": "#18141e", "b": "#3e8ed0", "c": "#2ce8f5"}),
}


def card_art():
    for kind in CARD_CORNERS:
        save(card_frame(kind), "ui", "card_" + kind + ".png", scale=3)
        save(card_frame(kind), "ui", "card_" + kind + "_small.png", scale=2)
    for r, cm in RARITY_GEMS.items():
        m = {"k": "#18141e"}
        m.update(cm)
        save(hexmap_render(GEM, m, "gem_" + r), "rarity", r + ".png")
    for t, (rows, cm) in TYPE_ICONS.items():
        save(hexmap_render(rows, cm, "type_" + t), "icons", "type_" + t + ".png")


# ============================================================ плитки (16×16, ×4)

LOC_TILES = {
    "cellar": ("#4a3528", "#3a281d", "#5e4433", "#241812"),
    "mine": ("#4d4128", "#3b311c", "#665634", "#231c10"),
    "catacombs": ("#34403a", "#27302b", "#47574e", "#151b17"),
    "temple": ("#244a50", "#1b383d", "#326870", "#0f2427"),
    "volcano": ("#52241e", "#3d1914", "#6e3027", "#220c09"),
    "citadel": ("#3a4f66", "#2c3d50", "#52708f", "#18222e"),
    "menu": ("#2b2236", "#211a2c", "#3a2f4a", "#16111d"),
}


def _shade(hexc, f):
    r, g, b, _ = hexrgb(hexc)
    return "#%02x%02x%02x" % (min(255, int(r * f)), min(255, int(g * f)), min(255, int(b * f)))


def floor_tile(base, dark, light, line):
    """Пол: одна большая плита на плитку, светлая кромка сверху-слева, камешки."""
    import random
    rnd = random.Random(11)
    B = hexrgb(_shade(base, 1.0))
    D = hexrgb(_shade(base, 0.86))
    L = hexrgb(_shade(base, 1.22))
    N = hexrgb(_shade(base, 0.62))
    img = Image.new("RGBA", (16, 16), B)
    for y in range(16):
        for x in range(16):
            if y == 15 or x == 15:
                img.putpixel((x, y), N)
            elif y == 0 or x == 0:
                img.putpixel((x, y), L)
            elif rnd.random() < 0.06:
                img.putpixel((x, y), D)
    for (x, y) in [(4, 5), (5, 5), (11, 10), (10, 11)]:
        img.putpixel((x, y), D)
    return img


def wall_tile(base, dark, light, line):
    """Стена: тёмная кирпичная кладка."""
    B = hexrgb(_shade(base, 0.62))
    L = hexrgb(_shade(base, 0.8))
    N = hexrgb(_shade(base, 0.35))
    img = Image.new("RGBA", (16, 16), B)
    for y in range(16):
        for x in range(16):
            row = y // 4
            off = 0 if row % 2 == 0 else 4
            if y % 4 == 3 or (x + off) % 8 == 7:
                img.putpixel((x, y), N)
            elif y % 4 == 0:
                img.putpixel((x, y), L)
    return img


def tiles():
    for loc, (base, dark, light, line) in LOC_TILES.items():
        save(floor_tile(base, dark, light, line), "tiles", f"floor_{loc}.png", scale=4)
        save(wall_tile(base, dark, light, line), "tiles", f"wall_{loc}.png", scale=4)


def main():
    for name, rows in CARDS.items():
        save(render(rows, name=name), "cards", name + ".png")
    for name, (src, rec) in DERIVED.items():
        save(render(CARDS[src], rec, name), "cards", name + ".png")
    for name, spec in HEROES.items():
        save(hero_img(spec, name), "heroes", name + ".png")
    for name, spec in MASTERS.items():
        save(hero_img(spec, name), "masters", name + ".png")
    for name, rows in RELICS.items():
        save(render(rows, name=name), "relics", name + ".png")
    for name, rows in NODES.items():
        save(render(rows, name=name), "nodes", name + ".png")
    for name, rows in ICONS.items():
        save(render(rows, name=name), "icons", name + ".png")
    for name, rows in MENU_ICONS.items():
        save(render(rows, name=name), "icons", name + ".png")
    for name, rec in CHESTS.items():
        save(render(CHEST_CLOSED, rec, "chest_" + name), "chests", name + ".png")
        save(render(CHEST_OPEN, rec, "chest_open_" + name), "chests", name + "_open.png")
    frames()
    tiles()
    if ERRORS:
        print("\n".join(ERRORS))
        sys.exit(1)
    print("готово:", ROOT)


if __name__ == "__main__":
    main()
