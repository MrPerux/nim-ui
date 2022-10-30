
import sdl2
import sdl2/ttf

import std/tables
# import std/sequtils
# import std/sugar
# import std/strutils

type SDLException = object of Defect


template sdlFailIf*(condition: typed, reason: string) =
    if condition: raise SDLException.newException(
        reason & ", SDL error " & $getError()
    )


proc drawText*(renderer: RendererPtr, font: FontPtr, text: cstring,
        color: Color, x: cint, y: cint) =
    if text.len == 0:
        return
    let
        surface = ttf.renderTextBlended(font, text, color)
        texture = renderer.createTextureFromSurface(surface)

    surface.freeSurface
    defer: texture.destroy

    var r = rect(
        x,
        y,
        surface.w,
        surface.h
    )
    renderer.copy texture, nil, addr r


type InputKind* = enum
    Keydown
    None


type Input* = object
    case kind*: InputKind:
    of Keydown:
        is_ascii*: bool
        character*: char
        scancode*: Scancode
        mod_shift*: bool
        mod_ctrl*: bool
        mod_alt*: bool
    of None:
        nil


func isDisplayableAsciiCharacterMap(): array[0..127, bool] =
    for c in " qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM1234567890!@#$%^&*()_+~`-=[]\\;',./{}|:\"<>?":
        result[cast[cint](c)] = true


const
    MOD_SHIFT = KMOD_LSHIFT or KMOD_RSHIFT
    MOD_CTRL = KMOD_LCTRL or KMOD_RCTRL
    MOD_ALT = KMOD_LALT or KMOD_RALT

func toInput*(c: char, mod_state: Keymod): Input =
    const table = isDisplayableAsciiCharacterMap()
    if cast[cint](c) in 0..127 and table[cast[cint](c)]:
        Input(kind: Keydown, is_ascii: true, character: c, scancode: cast[Scancode](0), mod_shift: bool(mod_state and MOD_SHIFT), mod_ctrl: bool(mod_state and MOD_CTRL), mod_alt: bool(mod_state and MOD_ALT))
    else:
        Input(kind: None)


func toInput*(key: Scancode, mod_state: Keymod): Input =
    Input(kind: Keydown, is_ascii: false, character: cast[char](0), scancode: key, mod_shift: bool(mod_state and MOD_SHIFT), mod_ctrl: bool(mod_state and MOD_CTRL), mod_alt: bool(mod_state and MOD_ALT))
