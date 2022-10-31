import std/options
import sdl2

import sdl_stuff

import globals
import ui_objects

import std/tables

{.experimental: "codeReordering".}

## UI Part
type MyTextForNode* = ref object of UIObject
    text: Option[string]
    terminal: TreeNode

proc getText(obj: MyTextForNode, globals: Globals): string =
    case obj.terminal.terminal_kind:
    of WorkingOn:
        obj.text.get()
    of IdentifierTerminal:
        let identifier_node = obj.terminal.parent.get()
        let identifier_id: IdentifierID = identifier_node.identifier_id
        let identifier_text: string = globals.identifier_texts[identifier_id]
        identifier_text
    of IntLiteral:
        obj.text.get()
func calculateSize*(obj: MyTextForNode, globals: Globals): Pos =
    pos(10 * cast[cint](obj.getText(globals).len()), 20)
method draw*(obj: MyTextForNode, globals: Globals, position: Pos, renderer: RendererPtr) =
    case obj.terminal.terminal_kind:
    of WorkingOn:
        drawText(renderer, globals.font, cstring(obj.getText(globals)), color(140, 240, 140, 255), position.x, position.y)
    of IdentifierTerminal:
        drawText(renderer, globals.font, cstring(obj.getText(globals)), color(240, 140, 240, 255), position.x, position.y)
    of IntLiteral:
        drawText(renderer, globals.font, cstring(obj.getText(globals)), color(240, 140, 140, 255), position.x, position.y)
method onClick*(obj: MyTextForNode): bool = discard
method onMouseEnter*(obj: MyTextForNode) = discard
method onMouseExit*(obj: MyTextForNode) = discard
method onChildSizeChange*(parent: MyTextForNode, child: UIObject) = discard

## Tree part
type TerminalKind* = enum
    WorkingOn
    IdentifierTerminal
    IntLiteral

type TreeNodeKind* = enum
    FunctionCall
    Terminal
    IdentifierNode
    TopLevelStatementList
    FunctionDefinition

type TreeNode* = ref object
    tree_node_id*: TreeNodeID
    parent*: Option[TreeNode]
    case kind*: TreeNodeKind:
    of FunctionCall:
        function_value*: TreeNode
        parameters*: seq[TreeNode]
    of Terminal:
        text_object*: MyTextForNode
        case terminal_kind*: TerminalKind:
        of WorkingOn:
            working_on_kind: TreeNodeKind
        else:
            discard
    of IdentifierNode:
        identifier_id*: IdentifierID
        identifier_terminal*: TreeNode
    of TopLevelStatementList:
        top_level_statements*: seq[TreeNode]
    of FunctionDefinition:
        function_definition_identifier: TreeNode

## Initilization functions
proc getNewTreeNodeID*(globals: var Globals): TreeNodeID =
    globals.current_tree_node_id = cast[TreeNodeID](cast[cint](globals.current_tree_node_id) + 1)
    return globals.current_tree_node_id
proc getNewIdentifierNodeID*(globals: var Globals, text: string): IdentifierID =
    globals.current_identifier_id = cast[IdentifierID](cast[cint](globals.current_identifier_id) + 1)
    globals.identifier_texts[globals.current_identifier_id] = text
    return globals.current_identifier_id
proc initIdentifier*(globals: var Globals, identifier_id: IdentifierID): TreeNode =
    let terminalTextObject = MyTextForNode(
        is_visible_or_interactable: true,
        terminal: result, # This is set wrong now but is set later
    )
    let terminalTreeNode = TreeNode(
        tree_node_id: getNewTreeNodeID(globals),
        parent: none[TreeNode](),
        kind: Terminal,
        terminal_kind: IdentifierTerminal,
        text_object: terminalTextObject,
    )
    terminalTextObject.terminal = terminalTreeNode # This is later
    result = TreeNode(
        tree_node_id: getNewTreeNodeID(globals),
        kind: IdentifierNode,
        identifier_id: identifier_id,
        identifier_terminal: terminalTreeNode,
    )
    terminalTreeNode.parent = some(result)
proc initFunctionCall*(globals: var Globals, function_value: TreeNode, parameters: seq[TreeNode]): TreeNode =
    result = TreeNode(
        tree_node_id: getNewTreeNodeID(globals),
        kind: FunctionCall,
        function_value: function_value,
        parameters: parameters,
    )
    function_value.parent = some(result)
    for child in parameters:
        child.parent = some(result)
proc initTopLevelStatementList*(globals: var Globals, top_level_statements: seq[TreeNode]): TreeNode =
    result = TreeNode(
        tree_node_id: getNewTreeNodeID(globals),
        kind: TopLevelStatementList,
        top_level_statements: top_level_statements,
    )
    for child in top_level_statements:
        child.parent = some(result)
proc initFunctionDefinition*(globals: var Globals, function_definition_identifier: TreeNode): TreeNode =
    result = TreeNode(
        tree_node_id: getNewTreeNodeID(globals),
        kind: FunctionDefinition,
        function_definition_identifier: function_definition_identifier,
    )
    function_definition_identifier.parent = some(result)

## Example tree.
proc initTestTree*(globals: var Globals): TreeNode =
    initTopLevelStatementList(globals, @[
        initFunctionCall(globals, initIdentifier(globals, getNewIdentifierNodeID(globals, "print")), @[]),
        initFunctionDefinition(globals, initIdentifier(globals, getNewIdentifierNodeID(globals, "launch my rockets, Carl!"))),
    ])

proc treeToHorizontalHorizontalLayouts*(tree: TreeNode): seq[MyHorizontalLayout] =
    result = @[]
    privateTreeToHorizontalHorizontalLayouts(tree, result)

proc privateTreeToHorizontalHorizontalLayouts(tree: TreeNode, lines: var seq[MyHorizontalLayout]) =
    case tree.kind:
    of FunctionCall:
        privateTreeToHorizontalHorizontalLayouts(tree.function_value, lines)
        lines[^1].addChild(MyKeywordText(
            text: "(",
            is_visible_or_interactable: true,
        ))
        lines[^1].addChild(MyKeywordText(
            text: ")",
            is_visible_or_interactable: true,
        ))
    of Terminal:
        lines[^1].addChild(tree.text_object)
    of IdentifierNode:
        privateTreeToHorizontalHorizontalLayouts(tree.identifier_terminal, lines)
    of TopLevelStatementList:
        for child in tree.top_level_statements:
            lines.add(MyHorizontalLayout(
                relative_pos: pos(500, 100 + 20 * cast[cint](lines.len())),
                is_visible_or_interactable: true,
                is_float: true,
            ))
            privateTreeToHorizontalHorizontalLayouts(child, lines)
    of FunctionDefinition:
        lines[^1].addChild(MyKeywordText(
            text: "func",
            is_visible_or_interactable: true,
        ))
        lines[^1].addChild(MyKeywordText(
            text: " ",
            is_visible_or_interactable: true,
        ))
        privateTreeToHorizontalHorizontalLayouts(tree.function_definition_identifier, lines)
        lines[^1].addChild(MyKeywordText(
            text: "(",
            is_visible_or_interactable: true,
        ))
        lines[^1].addChild(MyKeywordText(
            text: ")",
            is_visible_or_interactable: true,
        ))
        lines[^1].addChild(MyKeywordText(
            text: " ",
            is_visible_or_interactable: true,
        ))
        lines[^1].addChild(MyKeywordText(
            text: "=",
            is_visible_or_interactable: true,
        ))
