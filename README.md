# Better Mod Settings

Adds a **Mod Settings** button to Farever's Escape menu and presents compatible mods' settings in a native game window.

## Mod compatibility

A compatible mod includes a `configFormats.json` file in its own mod folder. The descriptor identifies the mod's existing settings file, so adopting Better Mod Settings does not require renaming or migrating configuration:

```json
{
  "schemaVersion": 1,
  "displayName": "Example Mod",
  "configFile": "config.json",
  "configs": [
    {
      "key": "enabled",
      "type": "checkbox",
      "label": "Enabled"
    }
  ]
}
```

`configFile` must be a filename within the same mod folder. If omitted, it defaults to `config.json` for compatibility with the original format.

## Building

Requires [HLX Core](https://github.com/hlx-framework/hlx-core) and the Farever `hl-imgui` library.

```sh
haxe compile.hxml
```
