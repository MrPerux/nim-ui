import std/options
import sdl2/ttf

{.experimental: "codeReordering".}

# every object (position) has a global position
# every (non-root) object (position) has a parent object with a layout algorithm object (layouter)
# some objects (shape) have an interactable arbitrary counterpart object (data)

### 2D position object
type Pos* = object
    x*: cint
    y*: cint

func pos*(x: cint, y: cint): Pos =
    Pos(x: x, y: y)

proc `+`*(a: Pos, b: Pos): Pos =
    pos(a.x + b.x, a.y + b.y)
proc `-`*(a: Pos, b: Pos): Pos =
    pos(a.x - b.x, a.y - b.y)


### Base objects for UI elements
type UIObject* = ref object of RootObj
    relative_pos*: Pos
    is_float*: bool
    is_visible_or_interactable*: bool
    sibling_index*: cint
    children*: seq[UIObject]
    parent*: Option[UIObject]
    size*: Pos
    is_hovered*: bool

type Globals* = object
    running*: bool
    width*: cint
    height*: cint
    hovered*: seq[UIObject]
    floaters*: seq[UIObject]

    font*: FontPtr

    selected_text_object*: Option[UIObject]

    text_lines*: seq[UIObject]

    debug_should_render_hovered_objects*: bool
    debug_draw_frame_counter*: bool

