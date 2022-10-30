import std/options

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
type UIChild* = object
    relative_pos*: Pos
    is_float*: bool
    is_visible_or_interactable*: bool
    itself*: UIObject
    sibling_index*: cint

type UIObject* = ref object of RootObj
    children*: seq[UIChild]
    parent*: Option[UIObject]
    size*: Pos

type Globals* = object
  running*: bool
  width*: cint
  height*: cint

