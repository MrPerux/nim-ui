import std/options
import sdl2
import sdl2/image

{.experimental: "codeReordering".}

# every object (position) has a global position
# every (non-root) object (position) has a parent object with a layout algorithm object (layouter)
# some objects (shape) have an interactable arbitrary counterpart object (data)


### 2D position object
type Pos* = object
    x*: cint
    y*: cint

proc `+`*(a: Pos, b: Pos): Pos =
    Pos(x: a.x + b.x, y: a.y + b.y)
proc `-`*(a: Pos, b: Pos): Pos =
    Pos(x: a.x - b.x, y: a.y - b.y)


### Base objects for UI elements
type UIChild = object
    relative_pos: Pos
    is_float: bool
    is_visible_or_interactable: bool
    itself: UIObject
    sibling_index: cint

type UIObject = ref object of RootObj
    children: seq[UIChild]
    parent: Option[UIObject]
    size: Pos

method draw*(obj: UIObject, position: Pos,
        renderer: RendererPtr) {.base.} = discard
method onClick*(obj: UIObject): bool {.base.} = discard

proc privateOnClick*(obj: UIObject, relative_pos: Pos) =
    let is_in_obj_bounding_box = (
        relative_pos.x >= 0 and obj.size.x > relative_pos.x
    ) and (
        relative_pos.y >= 0 and obj.size.y > relative_pos.y
    ) 
    if is_in_obj_bounding_box:
        if obj.onClick():
            return
    for child in obj.children:
        if child.is_visible_or_interactable:
            privateOnClick(child.itself, relative_pos - child.relative_pos)


### Custom UI elements
## Icon UI element
# type MyIcon = object of UIObject
#     is_active: bool
#     icon_surface: TexturePtr


## Sidebar UI element
type MySidebar* = ref object of UIObject
    active_icon_index: cint
    icons: seq[TexturePtr]
    # icons: seq[MyIcon]

method draw*(obj: MySidebar, position: Pos, renderer: RendererPtr) =
    var background_rect = rect(position.x, position.y, 42, 1080 - 2 * 2) # FIXME: make height dynamic
    renderer.setDrawColor(28, 41, 47, 255)
    renderer.fillRect(addr background_rect)
    
    var r = rect(position.x + 5, position.y + 5, 32, 32)
    var i = 0
    for icon in obj.icons:
        if i == obj.active_icon_index:
            discard icon.setTextureColorMod(255, 255, 255)
            renderer.copy icon, nil, addr r
        else:
            discard icon.setTextureColorMod(13, 26, 31)
            renderer.copy icon, nil, addr r
        r.y += 40
        i += 1
    
method onClick*(obj: MySidebar): bool =
    discard


## Root UI element
type MyRoot* = ref object of UIObject
    sidebar: MySidebar
    text: string

method draw*(obj: MyRoot, position: Pos, renderer: RendererPtr) =
    for child in obj.children:
        let x = child.relative_pos.x + position.x
        let y = child.relative_pos.y + position.y
        child.itself.draw(Pos(x: x, y: y), renderer)

method onClick*(obj: MyRoot): bool =
    discard


### Initializing procedures for ui elements
proc loadIcon(renderer: RendererPtr, file: cstring): TexturePtr = 
    let surface = load(file)
    var pixels = cast [ptr array[0..(512*512),uint32]](surface.pixels)
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

proc initMyRoot*(renderer: RendererPtr): MyRoot =
    var mySidebar = MySidebar(
        children: @[],
        parent: none[UIObject](),
        size: Pos(x: 42, y: 1080),
        active_icon_index: 1,
        icons: @[
            loadIcon(renderer, "icons/Animals-Dinosaur-icon.png"),
            loadIcon(renderer, "icons/Animals-Dolphin-icon.png"),
            loadIcon(renderer, "icons/Animals-Shark-icon.png"),
            loadIcon(renderer, "icons/Animals-Shrimp-icon.png"),
            loadIcon(renderer, "icons/Animals-Starfish-icon.png"),
        ]
    )

    let myRoot = MyRoot(
        children: @[UIChild(
            relative_pos: Pos(x: 2, y: 2),
            is_float: false,
            is_visible_or_interactable: true,
            itself: mySidebar,
            sibling_index: 0)],
        parent: none[UIObject](),
        size: Pos(x: 1920, y: 1080),
        sidebar: mySidebar,
        text: "Hey guys!"
    )
    mySidebar.parent = some[UIObject](myRoot)

    return myRoot