import std/options
import sdl2
import sdl2/image

import sdl_stuff

import globals

{.experimental: "codeReordering".}

## UI Object helper functions
proc addChild*(parent: UIObject, new_child: UIObject) =
    new_child.sibling_index = cast[cint](parent.children.len())
    new_child.parent = some(parent)
    parent.children.add(new_child)
func getAbsolutePosition*(obj: UIObject): Pos =
    if obj.parent.isSome:
        return obj.relative_pos + getAbsolutePosition(obj.parent.get())
    else:
        return obj.relative_pos
proc getElementsContaining*(output: var seq[UIObject], obj: UIObject, relative_pos: Pos) =
    if not obj.is_visible_or_interactable:
        return
    let is_in_obj_bounding_box = (
        relative_pos.x >= 0 and obj.size.x > relative_pos.x
    ) and (
        relative_pos.y >= 0 and obj.size.y > relative_pos.y
    )
    if is_in_obj_bounding_box:
        output.add(obj)
        for child in obj.children:
            getElementsContaining(output, child, relative_pos - child.relative_pos)

## UI Object virtual methods
method draw*(obj: UIObject, globals: Globals, position: Pos, renderer: RendererPtr) {.base.} = discard
method onClick*(obj: UIObject, globals: var Globals): bool {.base.} = discard
method onMouseEnter*(obj: UIObject) {.base.} = discard
method onMouseExit*(obj: UIObject) {.base.} = discard
method onChildSizeChange*(parent: UIObject, child: UIObject) {.base.} = discard


### Custom UI elements

## Horizontal Layouter UI Element
type MyHorizontalLayout* = ref object of UIObject
    discard
method onChildSizeChange*(parent: MyHorizontalLayout, child: UIObject) =
    parent.recalculateLayout()
proc recalculateLayout*(obj: MyHorizontalLayout) =
    var p = pos(0, 0)
    var max_height: cint = 0
    for child in obj.children:
        child.relative_pos = p
        p.x += child.size.x
        max_height = max(max_height, child.size.y)
    obj.size = pos(p.x, max_height)

method draw*(obj: MyHorizontalLayout, globals: Globals, position: Pos, renderer: RendererPtr) =
    for child in obj.children:
        let x = child.relative_pos.x + position.x
        let y = child.relative_pos.y + position.y
        child.draw(globals, pos(x, y), renderer)


## Keyword Text UI Element
type MyKeywordText* = ref object of UIObject
    text*: string
func calculateSize*(obj: MyKeywordText): Pos =
    pos(10 * cast[cint](obj.text.len()), 20)
proc recalculateSizeAfterTextChange*(obj: MyKeywordText) =
    let new_size = obj.calculateSize()
    if obj.size != new_size:
        obj.size = new_size
        if obj.parent.isSome:
            onChildSizeChange(obj.parent.get(), obj)
method draw*(obj: MyKeywordText, globals: Globals, position: Pos, renderer: RendererPtr) =
    drawText(renderer, globals.font, cstring(obj.text), color(240, 140, 140, 255), position.x, position.y)


## Example Pop-up UI Element
type MyPopup* = ref object of UIObject
    clicked_times*: cint
method draw*(obj: MyPopup, globals: Globals, position: Pos, renderer: RendererPtr) =
    var outline = rect(position.x, position.y, obj.size.x, obj.size.y)
    renderer.setDrawColor(140, 240, 140, 255)
    renderer.fillRect(outline)
    renderer.setDrawColor(14, 14, 14, 255)
    renderer.drawRect(outline)
    drawText(renderer, globals.font, cstring($obj.clicked_times), color(14, 14, 14, 255), position.x + 4, position.y + 4)
    discard

method onClick*(obj: MyPopup, globals: var Globals): bool =
    echo "CLICKED POPUP"
    obj.clicked_times += 1
    obj.recalculateSizeAfterClickedTimesChange()
    return true
func int_str_len(n: cint): cint =
    var x = n
    if n < 0:
        result = 2
        x = -n
    else:
        result = 1
    while x >= 10:
        result += 1
        x = x div 10
proc recalculateSizeAfterClickedTimesChange*(obj: MyPopup) =
    let new_x = 8 + 10 * int_str_len(obj.clicked_times)
    if obj.size.x != new_x:
        obj.size.x = new_x
        if obj.parent.isSome:
            onChildSizeChange(obj.parent.get(), obj)

## Icon UI Element
type MyIcon* = ref object of UIObject
    is_active: bool
    icon_surface: TexturePtr

method draw*(obj: MyIcon, globals: Globals, position: Pos, renderer: RendererPtr) =
    var r = rect(position.x, position.y, 32, 32)
    if obj.is_active:
        var active_r = rect(position.x - 5, position.y - 2, 2, 32 + 2 * 2)
        renderer.setDrawColor(255, 255, 255, 255)
        renderer.fillRect(active_r)
        discard obj.icon_surface.setTextureColorMod(255, 255, 255)
        renderer.copy obj.icon_surface, nil, addr r
    elif obj.is_hovered:
        discard obj.icon_surface.setTextureColorMod(255, 255, 255)
        renderer.copy obj.icon_surface, nil, addr r
    else:
        discard obj.icon_surface.setTextureColorMod(13, 26, 31)
        renderer.copy obj.icon_surface, nil, addr r

method onClick*(obj: MyIcon, globals: var Globals): bool =
    echo "CLICKED ICON"
    var sidebar = cast[MySidebar](obj.parent.get())
    for icon in sidebar.icons:
        icon.is_active = icon == obj
    return true

## Sidebar UI element
type MySidebar* = ref object of UIObject
    active_icon_index: cint
    icons: seq[MyIcon]

method draw*(obj: MySidebar, globals: Globals, position: Pos, renderer: RendererPtr) =
    var background_rect = rect(position.x, position.y, obj.size.x, obj.size.y)
    renderer.setDrawColor(28, 41, 47, 255)
    renderer.fillRect(addr background_rect)

    for child in obj.children:
        let x = child.relative_pos.x + position.x
        let y = child.relative_pos.y + position.y
        child.draw(globals, pos(x, y), renderer)

method onClick*(obj: MySidebar, globals: var Globals): bool =
    echo "CLICKED SIDEBAR"


## Root UI Element
type MyRoot* = ref object of UIObject
    sidebar: MySidebar
    text: string

method draw*(obj: MyRoot, globals: Globals, position: Pos, renderer: RendererPtr) =
    for child in obj.children:
        let x = child.relative_pos.x + position.x
        let y = child.relative_pos.y + position.y
        child.draw(globals, pos(x, y), renderer)

    renderer.setDrawColor(14, 14, 14, 255) # Grey lines
    # Right side of sidebar
    renderer.drawLine(
        position.x + obj.sidebar.size.x,
        position.y + 0,
        position.x + obj.sidebar.size.x,
        position.y + obj.sidebar.size.y)

    # Below bar
    renderer.setDrawColor(140, 140, 240, 255) # Light magenta below bar
    var below_bar_rect = rect(
        position.x + 0,
        position.y + obj.size.y - 30,
        obj.size.x,
        30)
    renderer.fillRect(below_bar_rect)
    renderer.setDrawColor(14, 14, 14, 255) # Grey lines
    renderer.drawLine(
        position.x + 0,
        position.y + obj.size.y - 30,
        position.x + obj.size.x,
        position.y + obj.size.y - 30)


method onClick*(obj: MyRoot, globals: var Globals): bool =
    discard


### Initializing procedures for UI Elements
proc loadIcon(renderer: RendererPtr, file: cstring): TexturePtr =
    let surface = load(file)
    var pixels = cast [ptr array[0..(512*512), uint32]](surface.pixels)
    # echo surface.h, surface.w,surface.pitch
    for y in 0..(surface.h-1):
        for x in 0..(surface.w-1):
            # surface.pixels[y * surface.h + x] = 0xffffffff
            # let z = cast[uint32](surface.pixels)
            if (pixels[y * 512 + x] and 0xff000000u32) != 0:
                pixels[y * 512 + x] = pixels[y * 512 + x] or 0x00ffffffu32
    let texture = createTextureFromSurface(renderer, surface)
    surface.freeSurface()
    return texture

proc initMyRoot*(globals: Globals, renderer: RendererPtr): MyRoot =
    var mySidebar = MySidebar(
        children: @[],
        parent: none[UIObject](),
        size: pos(42, globals.height),
        active_icon_index: 1,
        relative_pos: pos(0, 0),
        icons: @[],
        is_visible_or_interactable: true
    )

    var current_icon_position = pos(5, 5)
    for surface in [loadIcon(renderer, "icons/Animals-Dinosaur-icon.png"),
                    loadIcon(renderer, "icons/Animals-Dolphin-icon.png"),
                    loadIcon(renderer, "icons/Animals-Shark-icon.png"),
                    loadIcon(renderer, "icons/Animals-Shrimp-icon.png"),
                    loadIcon(renderer, "icons/Animals-Starfish-icon.png")]:
        var icon = MyIcon(
            size: pos(32, 32),
            is_active: false,
            icon_surface: surface,
            relative_pos: current_icon_position,
            is_visible_or_interactable: true
        )
        mySidebar.icons.add(icon)
        mySidebar.addChild(icon)
        current_icon_position.y += 40
    mySidebar.icons[mySidebar.active_icon_index].is_active = true

    let myRoot = MyRoot(
        size: pos(globals.width, globals.height),
        sidebar: mySidebar,
        text: "Hey guys!",
        is_visible_or_interactable: true
    )
    myRoot.addChild(mySidebar)

    return myRoot
