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

import std/tables

import std/options

import astree
import math

import os

proc draw(globals: Globals, renderer: RendererPtr, font: FontPtr, dt: float32) =
    # Background
    renderer.setDrawColor 8, 21, 27, 255 # dark cyaan
    renderer.clear()


proc handleInput(globals: var Globals, input: Input) =
    if input.kind == None:
        return

    # Debug keybinds
    if input.kind == InputKind.Keydown and input.is_ascii == false and input.mod_ctrl and input.scancode ==
            Scancode.SDL_SCANCODE_C:
        globals.running = false
    if input.kind == InputKind.Keydown and input.is_ascii == false and input.mod_ctrl and input.scancode ==
            Scancode.SDL_SCANCODE_H:
        globals.debug_should_render_hovered_objects = not globals.debug_should_render_hovered_objects
    if input.kind == InputKind.Keydown and input.is_ascii == false and input.mod_ctrl and input.scancode ==
            Scancode.SDL_SCANCODE_F:
        globals.debug_draw_frame_counter = not globals.debug_draw_frame_counter

    # Ascii typing
    if globals.typing_tree_node.isSome and input.kind == InputKind.Keydown and input.is_ascii == true:
        var tree = globals.typing_tree_node.get()
        case tree.kind:
        of IdentifierNode:
            globals.identifier_texts[tree.identifier_id] &= input.character
            var obj = tree.identifier_terminal.text_object
            obj.size = obj.calculateSize(globals)
            obj.parent.get().onChildSizeChange(obj)
        else: discard
    # Backspace
    if globals.typing_tree_node.isSome and input.kind == InputKind.Keydown and input.is_ascii == false and
            input.scancode == SDL_SCANCODE_BACKSPACE:
        var tree = globals.typing_tree_node.get()
        case tree.kind:
        of IdentifierNode:
            if globals.identifier_texts[tree.identifier_id].len() > 0:
                globals.identifier_texts[tree.identifier_id] = globals.identifier_texts[tree.identifier_id][0 ..< ^1]
                var obj = tree.identifier_terminal.text_object
                obj.size = obj.calculateSize(globals)
                obj.parent.get().onChildSizeChange(obj)
        else: discard
    # Enter
    if globals.typing_tree_node.isSome and input.kind == InputKind.Keydown and input.is_ascii == false and
            input.scancode == SDL_SCANCODE_RETURN:
        var tree = globals.typing_tree_node.get()
        case tree.kind:
        of IdentifierNode:
            assert globals.root_tree.kind == TopLevelStatementList
            let f = initFunctionCall(globals, initIdentifier(globals, getNewIdentifierNodeID(globals, "exit")), @[initIdentifier(globals, getNewIdentifierNodeID(globals, "exit_code"))])
            globals.root_tree.top_level_statements.add(f)
            f.parent = some(globals.root_tree)

            var new_floaters: seq[UIObject] = @[]
            for h in globals.floaters:
                if not (h in globals.horizontal_layouts):
                    new_floaters.add(h)
            globals.horizontal_layouts = cast[seq[UIObject]](treeToHorizontalHorizontalLayouts(globals.root_tree))
            globals.floaters = new_floaters

            for h in globals.horizontal_layouts:
                let hor = cast[MyHorizontalLayout](h)
                globals.floaters.add(hor)
                for child in hor.children:
                    if child of MyKeywordText:
                        child.size = cast[MyKeywordText](child).calculateSize()
                    if child of MyTextForNode:
                        child.size = cast[MyTextForNode](child).calculateSize(globals)
                hor.recalculateLayout()

        else: discard
    echo $input


proc main =
    let WIDTH: cint = if existsEnv("WSL_INTEROP"): 2560 else: 1920
    let HEIGHT: cint = if existsEnv("WSL_INTEROP"): 1440 else: 1053
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
    globals.floaters.add(myRoot)

    let myPopup = MyPopup(
        clicked_times: -11,
        size: pos(0, 28),
        relative_pos: pos(200, 200),
        is_visible_or_interactable: true,
        is_float: true
    )
    myPopup.recalculateSizeAfterClickedTimesChange()
    globals.floaters.add(myPopup)

    globals.root_tree = initTestTree(globals)
    globals.horizontal_layouts = cast[seq[UIObject]](treeToHorizontalHorizontalLayouts(globals.root_tree))
    for h in globals.horizontal_layouts:
        let hor = cast[MyHorizontalLayout](h)
        globals.floaters.add(hor)
        for child in hor.children:
            if child of MyKeywordText:
                child.size = cast[MyKeywordText](child).calculateSize()
            if child of MyTextForNode:
                child.size = cast[MyTextForNode](child).calculateSize(globals)
        hor.recalculateLayout()

    # Setup font
    let font = ttf.openFont("Hack Regular Nerd Font Complete.ttf", 16)
    sdlFailIf font.isNil: "font could not be created"

    globals.font = font

    # Gameloop variables
    var
        dt: float32

        counter: uint64
        previousCounter: uint64

        frame_counter: cint
        last_frame_times: seq[float32]

    globals.typing_tree_node = some(globals.root_tree.top_level_statements[0].function_value)
    for i in 0..40:
        globals.handleInput(Input(kind: InputKind.Keydown, scancode: SDL_SCANCODE_RETURN))


    # Start gameloop
    counter = getPerformanceCounter()
    while globals.running:
        previousCounter = counter
        counter = getPerformanceCounter()

        dt = (counter - previousCounter).float / getPerformanceFrequency().float
        last_frame_times.add(dt)
        if last_frame_times.len > 30:
            last_frame_times.delete(0)

        var event = defaultEvent

        # Set hovering state
        var new_hovered: seq[UIObject] = @[]
        var mouse_x, mouse_y: cint
        getMouseState(mouse_x, mouse_y)
        for obj in globals.floaters:
            getElementsContaining(new_hovered, obj, pos(mouse_x, mouse_y) - obj.relative_pos)
        for obj in new_hovered:
            if not globals.hovered.contains(obj):
                obj.is_hovered = true
                obj.onMouseEnter()

        for obj in globals.hovered:
            if not new_hovered.contains(obj):
                obj.is_hovered = false
                obj.onMouseExit()
        globals.hovered = new_hovered

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

            of EventType.MouseButtonDown:
                # Go over the hovered items in reversed order and break if an object 'catches' the click
                var i = globals.hovered.len() - 1
                while i >= 0:
                    # Check if the object 'catches' the click
                    if globals.hovered[i].onClick(globals):
                        break
                    dec(i)

            else:
                discard

        globals.draw(renderer, font, dt)
        for obj in globals.floaters:
            if obj.is_visible_or_interactable:
                obj.draw(globals, obj.relative_pos, renderer)
        if globals.debug_should_render_hovered_objects:
            for obj in globals.hovered:
                let pos = getAbsolutePosition(obj)
                var r = rect(pos.x, pos.y, obj.size.x, obj.size.y)
                renderer.setDrawColor(255, 0, 255, 255)
                renderer.drawRect(r)

        if globals.debug_draw_frame_counter:
            drawText(renderer, font, cstring("Frame #" & $frame_counter), color(255, 255, 255, 255), myRoot.size.x -
                    200, 10)
                    
        var current_fps = last_frame_times.len.toFloat / last_frame_times.sum
        drawText(renderer, font, cstring("FPS: " & $current_fps.toInt), color(255, 255, 255, 255), (30 - 16) div 2, globals.height - 16 - (30 - 16) div 2)

        renderer.present()

        frame_counter += 1

main()
