[Türkçe](../../../tr/lumina/blueprint/index.md)

# Blueprints

Blueprints are Lumina's visual scripting system. A Blueprint is a node graph stored in a `.lmas` asset; the same graph runs in the editor through a virtual machine and ships in games as generated Dart code, and both paths share one node library and one function library so they behave the same.

## How Blueprints work

All Blueprint code lives in `lib/src/blueprint/`, exported together by `blueprint.dart`.

- **Documents**: a Blueprint class is a `.lmas` asset whose payload is a `LuminaBlueprintDocument`: a component tree, variables, the event graph, functions, macros, event dispatchers and timelines. Interfaces, enums, save-game classes, montages, Level Blueprints, Widget Blueprints and Animation Blueprints have their own document types.
- **Node library**: `LuminaBlueprintNodeLibrary` is the one node catalog that the editor palette, the VM and the code generator all read. Each node spec declares its pins and how it takes part in execution.
- **Function library**: the behaviour of every pure and impure node is written once in `LuminaBlueprintFunctionLibrary`.
- **Two ways to run**:
  - In the editor (Play-In-Editor), the VM (`LuminaBlueprintClass`, `LuminaBlueprintInterpreter`) runs graphs node by node.
  - In a shipped game, the code generator turns each Blueprint into a Dart class that calls the function library's static methods directly.
  - Both share the `LuminaBlueprintRuntime` mixin, the component mapping and the function library, so a Blueprint behaves the same either way.
- **Dart functions as nodes**: `@BlueprintCallable` (an impure node with exec pins) and `@BlueprintPure` (a pure node, evaluated when an output is pulled) mark public top-level or static functions. The editor's scanner reads them from source, derives the pins from the parameters and the return type, and generates the registration the VM uses, because Flutter has no run-time reflection. `LuminaBlueprintFunctionRegistry` holds these project nodes.
- **Validation**: the validator produces the compiler-results rows (`LuminaBlueprintDiagnostic`) that the Blueprint editor shows.

The editor side lives in `lumina_ui`: see the [Blueprint editor](../../lumina_ui/sub-editors/blueprint.md).

## Reference pages

| Page | Covers |
|---|---|
| [Blueprint documents and assets](model.md) | Pins, nodes, wires, graphs, functions, macros, interfaces, enums, save-game and montage assets, validation. |
| [Blueprint runtime, VM and node library](runtime.md) | The node catalog, the interpreter, Blueprint actors, level and widget Blueprints, delegates. |
| [Blueprint function library](function-library.md) | The behaviour of every pure and impure node, shared by the VM and generated code. |
| [Animation Blueprints](animation.md) | Animation Blueprint documents, state machines, blend spaces, aim offsets and their instances. |

---

[Previous: Save games](../save.md) | [Up: lumina (engine core)](../index.md) | [Next: Blueprint documents and assets](model.md)
