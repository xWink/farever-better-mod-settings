package bettermodsettings;

import haxe.Json;
import imgui.ImGui;
import sys.FileSystem;
import sys.io.File;

@:build(hlx.runtime.Mod.build())
class BetterModSettingsMod {
    static var activeEscapeMenu:Dynamic;
    static var modSettingsButton:Dynamic;
    static var nativeSettingsWindow:Dynamic;
    static var compatibleMods:Array<Dynamic> = [];

    static var propertiesType:hl.Bytes;
    static var uiElementType:hl.Bytes;
    static var h2dObjectType:hl.Bytes;
    static var titleWindowType:hl.Bytes;
    static var flowType:hl.Bytes;
    static var checkBoxType:hl.Bytes;
    static var createNewMember:hlx.runtime.ResolvedMember;
    static var getParentPropertiesMember:hlx.runtime.ResolvedMember;
    static var setOnClickMember:hlx.runtime.ResolvedMember;
    static var setMinWidthMember:hlx.runtime.ResolvedMember;
    static var setMinHeightMember:hlx.runtime.ResolvedMember;
    static var setPaddingMember:hlx.runtime.ResolvedMember;
    static var setVerticalSpacingMember:hlx.runtime.ResolvedMember;
    static var setHorizontalSpacingMember:hlx.runtime.ResolvedMember;
    static var setSelectedMember:hlx.runtime.ResolvedMember;
    static var setVisibleMember:hlx.runtime.ResolvedMember;

    static function main():Void {
        ImGui.register(HlxRuntime.moduleName(), draw);
    }

    @:hlx.postfix(ui.win.EscapeMenu.init)
    static function afterEscapeMenuInit(instance:Dynamic, result:Void):Void {
        activeEscapeMenu = instance;
        modSettingsButton = null;
        trace("[BetterModSettings] Escape menu init detected");

        try {
            if (!resolveUiMembers()) {
                trace("[BetterModSettings] Required UI members were not resolved");
                return;
            }

            var optionsButton:Dynamic = HlxRuntime.resolveField(instance, "optionsBtn");
            var optionsProperties:Dynamic = optionsButton == null
                ? null
                : HlxRuntime.resolveField(optionsButton, "dom");
            if (optionsProperties == null) {
                trace("[BetterModSettings] Options button DOM was not found");
                return;
            }

            var menuListProperties:Dynamic = HlxRuntime.callResolved(
                getParentPropertiesMember,
                [optionsProperties]
            );
            if (menuListProperties == null) {
                trace("[BetterModSettings] Escape menu list DOM was not found");
                return;
            }

            var createdProperties:Dynamic = HlxRuntime.callResolved(createNewMember, [
                "button",
                menuListProperties,
                ["Mod Settings"],
                { id: "betterModSettingsButton" }
            ]);
            if (createdProperties == null) {
                trace("[BetterModSettings] Button DOM creation returned null");
                return;
            }

            modSettingsButton = HlxRuntime.resolveField(createdProperties, "obj");
            if (modSettingsButton == null) {
                trace("[BetterModSettings] Created button object was null");
                return;
            }

            HlxRuntime.callResolved(setOnClickMember, [modSettingsButton, openSettings]);
            trace("[BetterModSettings] Mod Settings button appended successfully");
        } catch (error:Dynamic) {
            modSettingsButton = null;
            trace("[BetterModSettings] Could not add Escape menu button: " + Std.string(error));
        }
    }

    static function openSettings():Void {
        try {
            if (!resolveUiMembers() || activeEscapeMenu == null)
                return;

            var parent:Dynamic = HlxRuntime.resolveField(activeEscapeMenu, "parent");
            if (parent == null) {
                trace("[BetterModSettings] Escape menu parent was not found");
                return;
            }

            if (titleWindowType == null)
                titleWindowType = HlxRuntime.resolveType("ui.win.TitleWindow");
            if (titleWindowType == null) {
                trace("[BetterModSettings] Native TitleWindow type was not resolved");
                return;
            }

            nativeSettingsWindow = HlxRuntime.constructInstanceByName(
                titleWindowType,
                2,
                ["Mod Settings", parent]
            );
            if (nativeSettingsWindow == null) {
                trace("[BetterModSettings] Native Mod Settings window creation returned null");
                return;
            }

            var windowProperties:Dynamic = HlxRuntime.resolveField(nativeSettingsWindow, "dom");
            if (windowProperties == null) {
                trace("[BetterModSettings] Native Mod Settings window DOM was not found");
                return;
            }

            var contentAttributes:Dynamic = {
                id: "betterModSettingsContent",
                layout: "vertical"
            };
            var contentProperties:Dynamic = HlxRuntime.callResolved(createNewMember, [
                "flow",
                windowProperties,
                [],
                contentAttributes
            ]);
            if (contentProperties == null)
                return;

            sizeContent(contentProperties);
            styleFlow(contentProperties, 24, 18, 0);
            discoverCompatibleMods();
            buildSettingsContent(contentProperties);

            trace("[BetterModSettings] Native Mod Settings window opened");
        } catch (error:Dynamic) {
            nativeSettingsWindow = null;
            trace("[BetterModSettings] Could not open native settings window: " + Std.string(error));
        }
    }

    static function draw():Void {}

    static function sizeContent(contentProperties:Dynamic):Void {
        try {
            if (flowType == null)
                flowType = HlxRuntime.resolveType("h2d.Flow");
            if (flowType == null)
                return;
            if (setMinWidthMember == null)
                setMinWidthMember = HlxRuntime.resolveMember(flowType, "set_minWidth");
            if (setMinHeightMember == null)
                setMinHeightMember = HlxRuntime.resolveMember(flowType, "set_minHeight");

            var content:Dynamic = HlxRuntime.resolveField(contentProperties, "obj");
            if (content == null)
                return;
            if (setMinWidthMember != null)
                HlxRuntime.callResolved(setMinWidthMember, [content, 900]);
            if (setMinHeightMember != null)
                HlxRuntime.callResolved(setMinHeightMember, [content, 540]);
        } catch (error:Dynamic) {
            trace("[BetterModSettings] Could not size native window: " + Std.string(error));
        }
    }

    static function discoverCompatibleMods():Void {
        compatibleMods = [];
        var modsPath = "hlx/mods";
        try {
            if (!FileSystem.exists(modsPath) || !FileSystem.isDirectory(modsPath))
                return;

            for (folder in FileSystem.readDirectory(modsPath)) {
                var folderPath = modsPath + "/" + folder;
                var formatPath = folderPath + "/configFormats.json";
                if (!FileSystem.isDirectory(folderPath)
                    || !FileSystem.exists(formatPath))
                    continue;

                try {
                    var format:Dynamic = Json.parse(File.getContent(formatPath));
                    var configFile = stringField(format, "configFile", "config.json");
                    if (!isSafeConfigFileName(configFile)) {
                        trace("[BetterModSettings] Skipping " + folder + ": invalid configFile");
                        continue;
                    }
                    var settingsPath = folderPath + "/" + configFile;
                    if (!FileSystem.exists(settingsPath))
                        continue;
                    var values:Dynamic = Json.parse(File.getContent(settingsPath));
                    var definitions:Array<Dynamic> = cast Reflect.field(format, "configs");
                    if (definitions == null)
                        continue;
                    compatibleMods.push({
                        name: stringField(format, "displayName", folder),
                        settingsPath: settingsPath,
                        definitions: definitions,
                        values: values
                    });
                } catch (error:Dynamic) {
                    trace("[BetterModSettings] Skipping " + folder + ": " + Std.string(error));
                }
            }

            compatibleMods.sort(function(a:Dynamic, b:Dynamic):Int {
                var left = Std.string(Reflect.field(a, "name")).toLowerCase();
                var right = Std.string(Reflect.field(b, "name")).toLowerCase();
                return left < right ? -1 : (left > right ? 1 : 0);
            });
            trace("[BetterModSettings] Found " + compatibleMods.length + " compatible mod(s)");
        } catch (error:Dynamic) {
            trace("[BetterModSettings] Mod discovery failed: " + Std.string(error));
        }
    }

    static function buildSettingsContent(contentProperties:Dynamic):Void {
        if (compatibleMods.length == 0) {
            createText(contentProperties, "No compatible mods were found.", "noCompatibleMods");
            return;
        }

        var tabsAttributes:Dynamic = { id: "modTabs" };
        Reflect.setField(tabsAttributes, "class", "two-buttons");
        var tabs:Dynamic = HlxRuntime.callResolved(createNewMember, [
            "flow", contentProperties, [], tabsAttributes
        ]);
        styleFlow(tabs, 0, 0, 10);

        var panels:Array<Dynamic> = [];
        for (index in 0...compatibleMods.length) {
            var mod:Dynamic = compatibleMods[index];
            var tab:Dynamic = HlxRuntime.callResolved(createNewMember, [
                "button",
                tabs,
                [Std.string(Reflect.field(mod, "name"))],
                { id: "modTab" + index }
            ]);
            var tabButton:Dynamic = tab == null ? null : HlxRuntime.resolveField(tab, "obj");
            if (tabButton != null) {
                var selectedIndex = index;
                HlxRuntime.callResolved(setOnClickMember, [tabButton, function():Void {
                    showPanel(panels, selectedIndex);
                }]);
            }

            var panelAttributes:Dynamic = {
                id: "modPanel" + index,
                layout: "vertical"
            };
            var panelProperties:Dynamic = HlxRuntime.callResolved(createNewMember, [
                "flow", contentProperties, [], panelAttributes
            ]);
            var panel:Dynamic = panelProperties == null
                ? null
                : HlxRuntime.resolveField(panelProperties, "obj");
            panels.push(panel);
            if (panelProperties != null) {
                styleFlow(panelProperties, 4, 14, 0);
                buildModSettings(panelProperties, mod);
            }
        }
        showPanel(panels, 0);
    }

    static function showPanel(panels:Array<Dynamic>, selectedIndex:Int):Void {
        if (h2dObjectType == null)
            h2dObjectType = HlxRuntime.resolveType("h2d.Object");
        if (h2dObjectType != null && setVisibleMember == null)
            setVisibleMember = HlxRuntime.resolveMember(h2dObjectType, "set_visible");
        if (setVisibleMember == null)
            return;

        for (index in 0...panels.length) {
            if (panels[index] != null)
                HlxRuntime.callResolved(setVisibleMember, [panels[index], index == selectedIndex]);
        }
    }

    static function buildModSettings(parentProperties:Dynamic, mod:Dynamic):Void {
        createText(parentProperties, Std.string(Reflect.field(mod, "name")), "selectedModTitle");
        var definitions:Array<Dynamic> = cast Reflect.field(mod, "definitions");
        for (index in 0...definitions.length) {
            var definition = definitions[index];
            var key = stringField(definition, "key", "");
            var type = stringField(definition, "type", "");
            var label = stringField(definition, "label", key);
            if (key.length == 0)
                continue;

            var rowProperties:Dynamic = HlxRuntime.callResolved(createNewMember, [
                "flow",
                parentProperties,
                [],
                { id: "settingRow" + index, layout: "vertical" }
            ]);
            var settingParent = rowProperties == null ? parentProperties : rowProperties;
            styleFlow(rowProperties, 0, 6, 0);

            if (type == "checkbox") {
                var checked = boolValue(Reflect.field(mod, "values"), key, false);
                var checkProperties:Dynamic = HlxRuntime.callResolved(createNewMember, [
                    "check-box",
                    settingParent,
                    [label],
                    { id: "setting" + index }
                ]);
                var check:Dynamic = checkProperties == null
                    ? null
                    : HlxRuntime.resolveField(checkProperties, "obj");
                if (check != null) {
                    setCheckboxValue(check, checked);
                    var targetMod = mod;
                    var targetKey = key;
                    HlxRuntime.setField(check, "onValueChange", function(value:Bool):Void {
                        saveSetting(targetMod, targetKey, value);
                    });
                }
            } else if (type == "slider") {
                createText(settingParent, label, "settingLabel" + index);
                var min = numberField(definition, "min", 0.0);
                var max = numberField(definition, "max", 100.0);
                var step = numberField(definition, "step", 1.0);
                var value = numberValue(Reflect.field(mod, "values"), key, min);
                var sliderProperties:Dynamic = HlxRuntime.callResolved(createNewMember, [
                    "slider",
                    settingParent,
                    [min, max, step, value],
                    { id: "setting" + index }
                ]);
                var slider:Dynamic = sliderProperties == null
                    ? null
                    : HlxRuntime.resolveField(sliderProperties, "obj");
                if (slider != null) {
                    var targetMod = mod;
                    var targetKey = key;
                    HlxRuntime.setField(slider, "onChange", function(newValue:Float):Void {
                        saveSetting(targetMod, targetKey, newValue);
                    });
                }
            }
        }
    }

    static function styleFlow(
        properties:Dynamic,
        padding:Int,
        verticalSpacing:Int,
        horizontalSpacing:Int
    ):Void {
        if (properties == null)
            return;
        try {
            if (flowType == null)
                flowType = HlxRuntime.resolveType("h2d.Flow");
            if (flowType == null)
                return;
            if (setPaddingMember == null)
                setPaddingMember = HlxRuntime.resolveMember(flowType, "set_padding");
            if (setVerticalSpacingMember == null)
                setVerticalSpacingMember = HlxRuntime.resolveMember(flowType, "set_verticalSpacing");
            if (setHorizontalSpacingMember == null)
                setHorizontalSpacingMember = HlxRuntime.resolveMember(flowType, "set_horizontalSpacing");

            var flow:Dynamic = HlxRuntime.resolveField(properties, "obj");
            if (flow == null)
                return;
            if (setPaddingMember != null)
                HlxRuntime.callResolved(setPaddingMember, [flow, padding]);
            if (setVerticalSpacingMember != null)
                HlxRuntime.callResolved(setVerticalSpacingMember, [flow, verticalSpacing]);
            if (setHorizontalSpacingMember != null)
                HlxRuntime.callResolved(setHorizontalSpacingMember, [flow, horizontalSpacing]);
        } catch (error:Dynamic) {
            trace("[BetterModSettings] Could not style settings flow: " + Std.string(error));
        }
    }

    static function createText(parentProperties:Dynamic, text:String, id:String):Void {
        HlxRuntime.callResolved(createNewMember, [
            "text", parentProperties, [text], { id: id }
        ]);
    }

    static function setCheckboxValue(check:Dynamic, value:Bool):Void {
        if (checkBoxType == null)
            checkBoxType = HlxRuntime.resolveType("ui.comp.CheckBox");
        if (checkBoxType != null && setSelectedMember == null)
            setSelectedMember = HlxRuntime.resolveMember(checkBoxType, "set_selected");
        if (setSelectedMember != null)
            HlxRuntime.callResolved(setSelectedMember, [check, value]);
        else
            HlxRuntime.setField(check, "selected", value);
    }

    static function saveSetting(mod:Dynamic, key:String, value:Dynamic):Void {
        try {
            var settingsPath = Std.string(Reflect.field(mod, "settingsPath"));
            var values:Dynamic = Json.parse(File.getContent(settingsPath));
            Reflect.setField(values, key, value);
            Reflect.setField(mod, "values", values);
            File.saveContent(
                settingsPath,
                Json.stringify(values, null, "  ")
            );
            trace("[BetterModSettings] Saved " + key);
        } catch (error:Dynamic) {
            trace("[BetterModSettings] Could not save " + key + ": " + Std.string(error));
        }
    }

    static function stringField(object:Dynamic, key:String, fallback:String):String {
        if (object == null || !Reflect.hasField(object, key))
            return fallback;
        var value:Dynamic = Reflect.field(object, key);
        return value == null ? fallback : Std.string(value);
    }

    static function isSafeConfigFileName(fileName:String):Bool {
        return fileName.length > 0
            && fileName.indexOf("/") < 0
            && fileName.indexOf("\\") < 0
            && fileName.indexOf("..") < 0;
    }

    static function numberField(object:Dynamic, key:String, fallback:Float):Float {
        if (object == null || !Reflect.hasField(object, key))
            return fallback;
        var value:Dynamic = Reflect.field(object, key);
        return value == null ? fallback : cast value;
    }

    static function boolValue(object:Dynamic, key:String, fallback:Bool):Bool {
        if (object == null || !Reflect.hasField(object, key))
            return fallback;
        return Reflect.field(object, key) == true;
    }

    static function numberValue(object:Dynamic, key:String, fallback:Float):Float {
        if (object == null || !Reflect.hasField(object, key))
            return fallback;
        var value:Dynamic = Reflect.field(object, key);
        return value == null ? fallback : cast value;
    }

    static function resolveUiMembers():Bool {
        if (propertiesType == null)
            propertiesType = HlxRuntime.resolveType("domkit.Properties");
        if (uiElementType == null)
            uiElementType = HlxRuntime.resolveType("ui.UIElement");
        if (propertiesType == null || uiElementType == null)
            return false;

        if (createNewMember == null)
            createNewMember = HlxRuntime.resolveStaticMember(propertiesType, "createNew");
        if (getParentPropertiesMember == null)
            getParentPropertiesMember = HlxRuntime.resolveMember(propertiesType, "get_parent");
        if (setOnClickMember == null)
            setOnClickMember = HlxRuntime.resolveMember(uiElementType, "set_onClick");
        return createNewMember != null
            && getParentPropertiesMember != null
            && setOnClickMember != null;
    }
}
