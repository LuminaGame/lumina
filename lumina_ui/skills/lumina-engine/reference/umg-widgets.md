# Widget Blueprints (UI): elements, Create Widget, Get Element, text, interfaces

## The asset

- `create_asset` with `type` `widget` and `name` `WBP_HUD` makes a Widget Blueprint (`contents/widgets/`). It has
  a **designer tree** of elements and its **own graph** (Self is `Widget:WBP_HUD`), edited with the Blueprint
  tools with `asset` = the widget.
- Element types (`list_widget_types`): panels `canvasPanel`, `overlay`, `verticalBox`, `horizontalBox`,
  `gridPanel`, `scrollBox`, `sizeBox`, `border`, `container`, `widgetSwitcher`; controls `text`, `button`,
  `image`, `progressBar`, `slider`, `checkBox`, `editableText`, `comboBox`. A `button` takes no child: put a
  `text` beside it in a panel or style the button itself.
- Every element has a **designer name** (unique, a Dart identifier such as `ScoreText`): graphs find elements by
  that name. Tools accept an element's id, name or field name.

## Designing (MCP)

`get_widget_tree` → `add_widget` (`asset`, `type`, `parent`, `name`, `props`) → `set_widget_slot` (`anchor_preset`,
`position`, `size`, `alignment`, `padding`, `z_order`) → `set_widget_properties` (text, colours, font size, …) →
`set_widget_is_variable` (panels are not variables by default) → **`save_widget`** → `compile_widget`.
Take `asset_editor_screenshot` to see the designer. There are no property bindings: text changes at run time
go through a graph.

## Showing a widget (from the player's pawn, the Level Blueprint or an actor)

1. `create_widget` with `literals` `{"class": "WBP_HUD"}` (output `return_value`, typed `Widget:WBP_HUD`).
2. `add_to_viewport` with its `target` wired from Create Widget (`z_order` optional). `remove_from_parent` hides it.
3. Keep the reference: a variable of type `Widget:WBP_HUD` set from `return_value` (`variable_set`).

## Changing an element from outside the widget

- `get_widget_element` with `literals` `{"class": "WBP_HUD", "element": "ScoreText"}`, its `target` wired from the
  widget reference. Its output is the element, typed by its kind (`WidgetElement:text`).
- `set_element_text` (`target` = that element, `in_text`), `set_element_percent` (progress bar),
  `set_element_visibility` (`in_visibility` `Visible` / `Collapsed`), `set_element_color`.
- If `get_widget_element` comes out untyped (`WidgetElement`), the widget was changed after the node was added:
  `save_widget`, then add the node again. `cast_to` with `class` `WidgetElement:text` also types it. Never use
  class names such as `TextBlock`, `Widget:Text` or `Element:text`: they are refused.

## Inside the widget's own graph

- Events: `event_widget_construct`, `event_widget_tick`, `event_widget_destruct`, `event_widget_pre_construct`.
- `get_widget_variable` with `literals` `{"element": "ScoreText"}` (an element with Is Variable on) → the element;
  then `set_element_text` as above. Without `element` the compile says "Get Widget names no widget".
- Buttons: `bind_widget_event` (`widget` `RestartButton`, `event` `OnClicked`; also `OnHovered`, `OnUnhovered`;
  text inputs `OnValueChanged`, `OnTextCommitted`) creates the event node and returns its `node_id` and exec pin.

## Talking to a widget: interfaces and dispatchers

- A **Blueprint Interface**: `create_asset` `type` `actor`, `blueprint_kind` `interface` (`contents/interfaces/`),
  `add_interface_function`, `set_interface_function_params`, `save_interface`; `implement_blueprint_interface` on
  the widget; in the widget graph `event_interface_function` (`literals` `interface`, `function`); the caller uses
  `interface_message` with the same literals and `target` = the widget reference from Create Widget.
- **Dispatchers**: `add_blueprint_dispatcher` + `set_blueprint_dispatcher_parameters` on the widget, `call_dispatcher`
  in its graph, `bind_event_to_dispatcher` (`target` = the widget reference) in the listener.
- Both work on the widget object Create Widget returned; keep that reference instead of creating a second widget.

## Checking it

Play, let it run 1.5 s, screenshot (`play-testing`). A widget that never appears: was `add_to_viewport` reached
(put a `print_string` after it), is the creating graph's event running (input events fire only on the possessed
pawn), is the element's slot inside the screen?
