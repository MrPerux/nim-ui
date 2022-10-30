#!/home/per/.nimble/bin/nim r
import sdl2
import sdl2/ttf

# import std/tables
# import std/sequtils
# import std/sugar
# import std/strutils

import sdl_stuff

import ui_objects
import globals

import os

proc draw(globals: Globals, renderer: RendererPtr, font: FontPtr, dt: float32) =
    # Background
    renderer.setDrawColor 8, 21, 27, 255 # dark cyaan
    renderer.clear()


proc handleInput(globals: var Globals, input: Input) =
    if input.kind == None:
        return
    if input.kind == InputKind.Keydown and input.is_ascii == false and input.mod_ctrl and input.scancode ==
            Scancode.SDL_SCANCODE_C:
        globals.running = false
    if input.kind == InputKind.Keydown and input.is_ascii == false and input.mod_ctrl and input.scancode ==
            Scancode.SDL_SCANCODE_H:
        globals.debug_should_render_hovered_objects = not globals.debug_should_render_hovered_objects
    echo $input


proc main =
    let WIDTH: cint = if existsEnv("WSL_INTEROP"): 2560 else: 1920
    let HEIGHT: cint = if existsEnv("WSL_INTEROP"): 1440 else: 1023
    var globals = Globals(running: true, width: WIDTH, height: HEIGHT)

    # SDL Stuff
    sdlFailIf(not sdl2.init(INIT_VIDEO or INIT_TIMER or INIT_EVENTS)):
        "SDL2 initialization failed"
    defer: sdl2.quit()

    let window = createWindow(
        title = "Gebruik de pijltjes",
        x = SDL_WINDOWPOS_CENTERED,
        y = SDL_WINDOWPOS_CENTERED,
        w = globals.width,
        h = globals.height,
        flags = SDL_WINDOW_SHOWN or SDL_WINDOW_MAXIMIZED or SDL_WINDOW_BORDERLESS or SDL_WINDOW_RESIZABLE
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

    let myRoot = initMyRoot(globals, renderer)

    # Setup font
    let font = ttf.openFont("Hack Regular Nerd Font Complete.ttf", 16)
    sdlFailIf font.isNil: "font could not be created"

    # Gameloop variables
    var
        dt: float32

        counter: uint64
        previousCounter: uint64

    # Set hovering state
    var mouse_x, mouse_y: cint
    getMouseState(mouse_x, mouse_y)
    getElementsContaining(globals.hovered, myRoot, pos(mouse_x, mouse_y))

    # Start gameloop
    counter = getPerformanceCounter()
    while globals.running:
        previousCounter = counter
        counter = getPerformanceCounter()

        dt = (counter - previousCounter).float / getPerformanceFrequency().float

        var event = defaultEvent

        while pollEvent(event):
            case event.kind
            of QuitEvent:
                globals.running = false
                break

            of TextInput:
                let c = event.evTextInput.text[0]
                echo "TextInput"
                globals.handleInput(toInput(c, getModState()))

            of EventType.KeyDown:
                echo "Keydown"
                globals.handleInput(toInput(event.evKeyboard.keysym.scancode, cast[
                        Keymod](event.evKeyboard.keysym.modstate)))

            of EventType.MouseMotion:
                var new_hovered: seq[UIObject] = @[]
                getElementsContaining(new_hovered, myRoot, pos(event.evMouseMotion.x, event.evMouseMotion.y))
                for obj in new_hovered:
                    if not globals.hovered.contains(obj):
                        obj.is_hovered = true
                        obj.onMouseEnter()

                for obj in globals.hovered:
                    if not new_hovered.contains(obj):
                        obj.is_hovered = false
                        obj.onMouseExit()
                globals.hovered = new_hovered

            of EventType.MouseButtonDown:
                # Go over the hovered items in reversed order and break if an object 'catches' the click
                var i = globals.hovered.len() - 1
                while i >= 0:
                    # Check if the object 'catches' the click
                    if globals.hovered[i].onClick():
                        break
                    dec(i)

            else:
                discard

        globals.draw(renderer, font, dt)
        myRoot.draw(globals, pos(0, 0), renderer)
        if globals.debug_should_render_hovered_objects:
            for obj in globals.hovered:
                let pos = getAbsolutePosition(obj)
                var r = rect(pos.x, pos.y, obj.size.x, obj.size.y)
                renderer.setDrawColor(255, 0, 255, 255)
                renderer.drawRect(r)
        renderer.present()

main()
