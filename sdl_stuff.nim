
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
  CtrlH
  CtrlJ
  CtrlK
  CtrlL
  CtrlSpace
  CtrlBackspace
  DisplayableCharacter
  Return
  Tab
  ShiftTab
  Backspace
  None

type Input* = object
  case kind*: InputKind:
  of DisplayableCharacter:
    character: char
  else:
    nil


func isDisplayableAsciiCharacterMap(): array[0..127, bool] =
  for c in " qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM1234567890!@#$%^&*()_+~`-=[]\\;',./{}|:\"<>?":
    result[cast[cint](c)] = true


func toInput*(c: char): Input =
  const table = isDisplayableAsciiCharacterMap()
  if cast[cint](c) in 0..127 and table[cast[cint](c)]:
    Input(kind: DisplayableCharacter, character: c)
  else:
    Input(kind: None)


func toInput*(key: Scancode, mod_state: Keymod): Input =
  let
    MOD_SHIFT = KMOD_LSHIFT or KMOD_RSHIFT
    MOD_CTRL = KMOD_LCTRL or KMOD_RCTRL

  # Only shift and no mod
  if (mod_state and not MOD_SHIFT) == 0:
    case key:
      of SDL_SCANCODE_RETURN: Input(kind: Return)
      of SDL_SCANCODE_BACKSPACE: Input(kind: Backspace)
      of SDL_SCANCODE_TAB:
        if (mod_state and MOD_SHIFT) == 0:
          Input(kind: Tab)
        else:
          Input(kind: ShiftTab)
      else: Input(kind: None)

  # Ctrl and only ctrl
  elif (mod_state and MOD_CTRL) != 0 and (mod_state and not MOD_CTRL) == 0:
    case key
    of SDL_SCANCODE_H: Input(kind: CtrlH)
    of SDL_SCANCODE_J: Input(kind: CtrlJ)
    of SDL_SCANCODE_K: Input(kind: CtrlK)
    of SDL_SCANCODE_L: Input(kind: CtrlL)
    of SDL_SCANCODE_SPACE: Input(kind: CtrlSpace)
    of SDL_SCANCODE_BACKSPACE: Input(kind: CtrlBackspace)
    else: Input(kind: None)

  else:
    Input(kind: None)
