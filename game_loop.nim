#!/home/per/.nimble/bin/nim r
import sdl2
import sdl2/ttf

# import std/tables
# import std/sequtils
# import std/sugar
# import std/strutils

import sdl_stuff


type Globals* = object
  discard


proc draw(globals: Globals, renderer: RendererPtr, font: FontPtr, dt: float32) =
  renderer.setDrawColor 255, 255, 255, 255 # black # prenk
  renderer.clear()

  renderer.present()


proc handleInput(globals: var Globals, input: Input) =
  if input.kind == None:
    return
  echo $input


proc main =
  # SDL Stuff
  sdlFailIf(not sdl2.init(INIT_VIDEO or INIT_TIMER or INIT_EVENTS)):
    "SDL2 initialization failed"
  defer: sdl2.quit()

  let window = createWindow(
    title = "Gebruik de pijltjes",
    x = SDL_WINDOWPOS_CENTERED,
    y = SDL_WINDOWPOS_CENTERED,
    w = 1920,
    h = 1023,
    flags = SDL_WINDOW_SHOWN or SDL_WINDOW_RESIZABLE or SDL_WINDOW_FULLSCREEN
  )

  sdlFailIf window.isNil: "window could not be created"
  defer: window.destroy()

  let renderer = createRenderer(
    window = window,
    index = -1,
    flags = Renderer_Accelerated or Renderer_PresentVsync or Renderer_TargetTexture
  )
  sdlFailIf renderer.isNil: "renderer could not be created"
  defer: renderer.destroy()

  sdlFailIf(not ttfInit()): "SDL_TTF initialization failed"
  defer: ttfQuit()


  # Setup font
  let font = ttf.openFont("Hack Regular Nerd Font Complete.ttf", 16)
  sdlFailIf font.isNil: "font could not be created"


  # Gameloop variables
  var
    running = true

    globals = Globals()

    dt: float32

    counter: uint64
    previousCounter: uint64


  # Start gameloop
  counter = getPerformanceCounter()
  while running:
    previousCounter = counter
    counter = getPerformanceCounter()

    dt = (counter - previousCounter).float / getPerformanceFrequency().float

    var event = defaultEvent

    while pollEvent(event):
      case event.kind
      of QuitEvent:
        running = false
        break

      of TextInput:
        let c = event.evTextInput.text[0]
        echo "TextInput"
        globals.handleInput(toInput(c))

      of KeyDown:
        echo "Keydown"
        globals.handleInput(toInput(event.evKeyboard.keysym.scancode, cast[
            Keymod](event.evKeyboard.keysym.modstate)))

      else:
        discard

    globals.draw(renderer, font, dt)

main()
