# Godot DataBind Controls

A godot addon which facilitates data binding to enable an MVC pattern for GUI controls.
Bind and Repeat nodes can be added inside leaf `Control` nodes and will automatically bind the
control's properties to reflect an object property. Run the demo project at the top level of
this repo to see `Example.gd` and `ExampleRepeat.gd` in action.

## Detecting Changes

Instead of using a custom class as the base of all data models this version uses a global 'change detection'
mechanism. Any place that may update data that needs to be reflected in the ui should call DataBindings.detect_changes()

## Using Bind and Repeat

The `Binds` node will automatically mirror the property names of it's parent `Control` node. The user can set the properties of the `Binds` node to bind data to a `Model` instance contained in a property the `owner` (scene root).

The `Repeat` node should be added as a child of an _Instanced Child Scene_ and allows that scene to be used as a template which will be repeated for each item in it's bound `ArrayModel`. Set the `array_bind` and `target_property` properties on the `Repeat` node to bind to an `ArrayModel`.

## Binding to ItemList etc

The `BindItems` node can be added as a child of a `ItemList`, `PopupMenu` or `OptionButton` node to bind to their item list. the `item_selected` bind will sync the selected status of each item to the model in both directions. Set the `array_bind` property to the model path for the `ArrayModel` which contains your item data.

## Development

All gdscript files should conform to gdformat and pass gdlint from [godot-gdscript-toolkit](https://github.com/Scony/godot-gdscript-toolkit). See the [installation procedure](https://github.com/Scony/godot-gdscript-toolkit#installation)

Run `./update_addons.sh` to checkout submodules etc. Run `check.sh` to check whether all files are passing the format/lint checks. (see `check.sh --help` for more info)


## Icons

Icons are based on the fontawesome icon set which uses the CC BY 4.0 license:
https://fontawesome.com/license/free
