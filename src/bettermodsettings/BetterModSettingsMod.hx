package bettermodsettings;

import haxe.Json;
import sys.FileSystem;
import sys.io.File;

@:build(hlx.runtime.Mod.build())
class BetterModSettingsMod {
    static var activeEscapeMenu:Dynamic;
    static var modSettingsButton:Dynamic;
    static var nativeSettingsWindow:Dynamic;
    static var compatibleMods:Array<Dynamic> = [];
    static var capturingKeybind:Dynamic;

    static var propertiesType:hl.Bytes;
    static var uiElementType:hl.Bytes;
    static var h2dObjectType:hl.Bytes;
    static var titleWindowType:hl.Bytes;
    static var flowType:hl.Bytes;
    static var flowPropertiesType:hl.Bytes;
    static var checkBoxType:hl.Bytes;
    static var buttonType:hl.Bytes;
    static var textType:hl.Bytes;
    static var hxdKeyType:hl.Bytes;
    static var createNewMember:hlx.runtime.ResolvedMember;
    static var getParentPropertiesMember:hlx.runtime.ResolvedMember;
    static var setOnClickMember:hlx.runtime.ResolvedMember;
    static var setMinWidthMember:hlx.runtime.ResolvedMember;
    static var setMinHeightMember:hlx.runtime.ResolvedMember;
    static var setMaxWidthMember:hlx.runtime.ResolvedMember;
    static var setMaxHeightMember:hlx.runtime.ResolvedMember;
    static var setPaddingMember:hlx.runtime.ResolvedMember;
    static var setPaddingLeftMember:hlx.runtime.ResolvedMember;
    static var setPaddingRightMember:hlx.runtime.ResolvedMember;
    static var setVerticalSpacingMember:hlx.runtime.ResolvedMember;
    static var setHorizontalSpacingMember:hlx.runtime.ResolvedMember;
    static var setSelectedMember:hlx.runtime.ResolvedMember;
    static var setButtonTextMember:hlx.runtime.ResolvedMember;
    static var setTitleTextMember:hlx.runtime.ResolvedMember;
    static var setUiSelectedMember:hlx.runtime.ResolvedMember;
    static var isKeyPressedMember:hlx.runtime.ResolvedMember;
    static var getKeyNameMember:hlx.runtime.ResolvedMember;
    static var setVisibleMember:hlx.runtime.ResolvedMember;
    static var initStyleMember:hlx.runtime.ResolvedMember;
    static var getFlowPropertiesMember:hlx.runtime.ResolvedMember;
    static var setFlowAbsoluteMember:hlx.runtime.ResolvedMember;

    static function main():Void {}

    @:hlx.postfix(GameApp.update)
    static function afterGameAppUpdate(instance:Dynamic, dt:Float, result:Void):Void {
        capturePressedKey();
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

            setNativeWindowTitle(windowProperties);

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
            styleFlow(contentProperties, 0, 18, 0);
            discoverCompatibleMods();
            buildSettingsContent(contentProperties);

            trace("[BetterModSettings] Native Mod Settings window opened");
        } catch (error:Dynamic) {
            nativeSettingsWindow = null;
            trace("[BetterModSettings] Could not open native settings window: " + Std.string(error));
        }
    }

    static function setNativeWindowTitle(windowProperties:Dynamic):Void {
        var originalContentRoot:Dynamic = null;
        try {
            originalContentRoot = HlxRuntime.resolveField(windowProperties, "contentRoot");
            var windowObject:Dynamic = HlxRuntime.resolveField(windowProperties, "obj");
            if (windowObject == null)
                return;

            // Create #title as a real direct child of TitleWindow, then mark it
            // absolute through FlowProperties. Unlike addChildAt, this never
            // reparents a DOMKit-managed object after creation.
            HlxRuntime.setField(windowProperties, "contentRoot", windowObject);
            var titleProperties:Dynamic = HlxRuntime.callResolved(createNewMember, [
                "text",
                windowProperties,
                ["Mod Settings"],
                { id: "title" }
            ]);
            var titleObject:Dynamic = titleProperties == null
                ? null
                : HlxRuntime.resolveField(titleProperties, "obj");

            if (flowType == null)
                flowType = HlxRuntime.resolveType("h2d.Flow");
            if (flowType != null && getFlowPropertiesMember == null)
                getFlowPropertiesMember = HlxRuntime.resolveMember(flowType, "getProperties");
            if (flowPropertiesType == null)
                flowPropertiesType = HlxRuntime.resolveType("h2d.FlowProperties");
            if (flowPropertiesType != null && setFlowAbsoluteMember == null)
                setFlowAbsoluteMember = HlxRuntime.resolveMember(flowPropertiesType, "set_isAbsolute");
            if (titleObject != null && getFlowPropertiesMember != null
                && setFlowAbsoluteMember != null) {
                var flowProperties:Dynamic = HlxRuntime.callResolved(
                    getFlowPropertiesMember,
                    [windowObject, titleObject]
                );
                if (flowProperties != null)
                    HlxRuntime.callResolved(setFlowAbsoluteMember, [flowProperties, true]);
            }
        } catch (error:Dynamic) {
            trace("[BetterModSettings] Could not create native window title: " + Std.string(error));
        }
        if (originalContentRoot != null) {
            try {
                HlxRuntime.setField(windowProperties, "contentRoot", originalContentRoot);
            } catch (error:Dynamic) {
                trace("[BetterModSettings] Could not restore window content root: " + Std.string(error));
            }
        }
    }

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
            if (setMaxWidthMember == null)
                setMaxWidthMember = HlxRuntime.resolveMember(flowType, "set_maxWidth");
            if (setMaxHeightMember == null)
                setMaxHeightMember = HlxRuntime.resolveMember(flowType, "set_maxHeight");

            var content:Dynamic = HlxRuntime.resolveField(contentProperties, "obj");
            if (content == null)
                return;
            if (setMinWidthMember != null)
                HlxRuntime.callResolved(setMinWidthMember, [content, 900]);
            if (setMinHeightMember != null)
                HlxRuntime.callResolved(setMinHeightMember, [content, 540]);
            if (setMaxWidthMember != null)
                HlxRuntime.callResolved(setMaxWidthMember, [content, 900]);
            if (setMaxHeightMember != null)
                HlxRuntime.callResolved(setMaxHeightMember, [content, 540]);
        } catch (error:Dynamic) {
            trace("[BetterModSettings] Could not size native window: " + Std.string(error));
        }
    }

    static function sizeBody(bodyProperties:Dynamic):Void {
        try {
            if (flowType == null)
                flowType = HlxRuntime.resolveType("h2d.Flow");
            if (flowType == null)
                return;
            if (setMinWidthMember == null)
                setMinWidthMember = HlxRuntime.resolveMember(flowType, "set_minWidth");
            if (setMaxWidthMember == null)
                setMaxWidthMember = HlxRuntime.resolveMember(flowType, "set_maxWidth");
            if (setMinHeightMember == null)
                setMinHeightMember = HlxRuntime.resolveMember(flowType, "set_minHeight");
            if (setMaxHeightMember == null)
                setMaxHeightMember = HlxRuntime.resolveMember(flowType, "set_maxHeight");
            var body:Dynamic = HlxRuntime.resolveField(bodyProperties, "obj");
            if (body == null)
                return;
            if (setMinWidthMember != null)
                HlxRuntime.callResolved(setMinWidthMember, [body, 900]);
            if (setMaxWidthMember != null)
                HlxRuntime.callResolved(setMaxWidthMember, [body, 900]);
            if (setMinHeightMember != null)
                HlxRuntime.callResolved(setMinHeightMember, [body, 460]);
            if (setMaxHeightMember != null)
                HlxRuntime.callResolved(setMaxHeightMember, [body, 460]);

            // Flow dimensions are later overwritten by DOMKit's component CSS.
            // Inline styles participate in that same cascade and survive reflow.
            if (propertiesType == null)
                propertiesType = HlxRuntime.resolveType("domkit.Properties");
            if (propertiesType != null && initStyleMember == null)
                initStyleMember = HlxRuntime.resolveMember(propertiesType, "initStyle");
            if (initStyleMember != null) {
                HlxRuntime.callResolved(initStyleMember, [bodyProperties, "height", 460]);
                HlxRuntime.callResolved(initStyleMember, [bodyProperties, "min-height", 460]);
                HlxRuntime.callResolved(initStyleMember, [bodyProperties, "max-height", 460]);
            }
        } catch (error:Dynamic) {
            trace("[BetterModSettings] Could not size settings body: " + Std.string(error));
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
        styleFlow(tabs, 12, 0, 10);
        setHorizontalPadding(tabs, 64);

        // This must be the native OptionsContent component, not a generic flow
        // carrying the same CSS classes. Its component identity is what activates
        // the game's Options body background and OptionLine typography.
        var bodyProperties:Dynamic = HlxRuntime.callResolved(createNewMember, [
            "options-content",
            contentProperties,
            [0],
            { id: "modSettingsBody" }
        ]);
        if (bodyProperties == null)
            bodyProperties = contentProperties;
        sizeBody(bodyProperties);
        var settingsParentProperties = prepareNativeOptionsBody(bodyProperties);

        var panels:Array<Dynamic> = [];
        var tabButtons:Array<Dynamic> = [];
        for (index in 0...compatibleMods.length) {
            var mod:Dynamic = compatibleMods[index];
            var tab:Dynamic = HlxRuntime.callResolved(createNewMember, [
                "button",
                tabs,
                [Std.string(Reflect.field(mod, "name"))],
                { id: "modTab" + index }
            ]);
            var tabButton:Dynamic = tab == null ? null : HlxRuntime.resolveField(tab, "obj");
            tabButtons.push(tabButton);
            if (tabButton != null) {
                var selectedIndex = index;
                HlxRuntime.callResolved(setOnClickMember, [tabButton, function():Void {
                    showPanel(panels, tabButtons, selectedIndex);
                }]);
            }

            var panelAttributes:Dynamic = {
                id: "modPanel" + index,
                layout: "vertical"
            };

            var panelProperties:Dynamic = HlxRuntime.callResolved(createNewMember, [
                "block", settingsParentProperties, [], panelAttributes
            ]);
            var panel:Dynamic = panelProperties == null
                ? null
                : HlxRuntime.resolveField(panelProperties, "obj");
            panels.push(panel);
            if (panelProperties != null) {
                styleFlow(panelProperties, 4, 14, 0);
                setHorizontalPadding(panelProperties, 64);
                sizeSettingsPanel(panelProperties);
                buildModSettings(panelProperties, mod);
            }
        }
        showPanel(panels, tabButtons, 0);
    }

    static function sizeSettingsPanel(panelProperties:Dynamic):Void {
        try {
            if (flowType == null)
                flowType = HlxRuntime.resolveType("h2d.Flow");
            if (flowType == null)
                return;
            if (setMinHeightMember == null)
                setMinHeightMember = HlxRuntime.resolveMember(flowType, "set_minHeight");
            if (setMaxHeightMember == null)
                setMaxHeightMember = HlxRuntime.resolveMember(flowType, "set_maxHeight");
            var panel:Dynamic = HlxRuntime.resolveField(panelProperties, "obj");
            if (panel == null)
                return;
            if (setMinHeightMember != null)
                HlxRuntime.callResolved(setMinHeightMember, [panel, 460]);
            if (setMaxHeightMember != null)
                HlxRuntime.callResolved(setMaxHeightMember, [panel, 460]);

            if (propertiesType == null)
                propertiesType = HlxRuntime.resolveType("domkit.Properties");
            if (propertiesType != null && initStyleMember == null)
                initStyleMember = HlxRuntime.resolveMember(propertiesType, "initStyle");
            if (initStyleMember != null) {
                HlxRuntime.callResolved(initStyleMember, [panelProperties, "height", 460]);
                HlxRuntime.callResolved(initStyleMember, [panelProperties, "min-height", 460]);
                HlxRuntime.callResolved(initStyleMember, [panelProperties, "max-height", 460]);
            }
        } catch (error:Dynamic) {
            trace("[BetterModSettings] Could not size settings panel: " + Std.string(error));
        }
    }

    static function prepareNativeOptionsBody(bodyProperties:Dynamic):Dynamic {
        try {
            var body:Dynamic = HlxRuntime.resolveField(bodyProperties, "obj");
            if (body == null)
                return bodyProperties;
            if (h2dObjectType == null)
                h2dObjectType = HlxRuntime.resolveType("h2d.Object");
            if (h2dObjectType != null && setVisibleMember == null)
                setVisibleMember = HlxRuntime.resolveMember(h2dObjectType, "set_visible");

            // Keep OptionsList and its Block visible: the native stylesheet targets
            // this exact ancestry when styling the body and OptionLine labels.
            var inputList:Dynamic = HlxRuntime.resolveField(body, "inputList");
            if (inputList != null && setVisibleMember != null)
                HlxRuntime.callResolved(setVisibleMember, [inputList, false]);

            var optionsList:Dynamic = HlxRuntime.resolveField(body, "optionsList");
            if (optionsList == null)
                return bodyProperties;
            // HashLink keeps OptionsList.lines as ArrayObj, which cannot be
            // safely iterated as Haxe Array<Dynamic>. Hide the generated Block
            // wholesale and create our own native Block under the same OptionsList.
            var nativeContainer:Dynamic = HlxRuntime.resolveField(optionsList, "container");
            if (nativeContainer != null && setVisibleMember != null)
                HlxRuntime.callResolved(setVisibleMember, [nativeContainer, false]);

            var applyButton:Dynamic = HlxRuntime.resolveField(optionsList, "applyBtn");
            if (applyButton != null && setVisibleMember != null)
                HlxRuntime.callResolved(setVisibleMember, [applyButton, false]);

            var optionsListProperties:Dynamic = HlxRuntime.resolveField(optionsList, "dom");
            return optionsListProperties == null
                ? bodyProperties
                : optionsListProperties;
        } catch (error:Dynamic) {
            trace("[BetterModSettings] Could not prepare native options body: " + Std.string(error));
            return bodyProperties;
        }
    }

    static function showPanel(
        panels:Array<Dynamic>,
        tabButtons:Array<Dynamic>,
        selectedIndex:Int
    ):Void {
        if (h2dObjectType == null)
            h2dObjectType = HlxRuntime.resolveType("h2d.Object");
        if (h2dObjectType != null && setVisibleMember == null)
            setVisibleMember = HlxRuntime.resolveMember(h2dObjectType, "set_visible");
        if (setVisibleMember == null)
            return;
        if (uiElementType != null && setUiSelectedMember == null)
            setUiSelectedMember = HlxRuntime.resolveMember(uiElementType, "set_selected");

        for (index in 0...panels.length) {
            if (panels[index] != null)
                HlxRuntime.callResolved(setVisibleMember, [panels[index], index == selectedIndex]);
            if (index < tabButtons.length && tabButtons[index] != null
                && setUiSelectedMember != null)
                HlxRuntime.callResolved(setUiSelectedMember, [
                    tabButtons[index],
                    index == selectedIndex
                ]);
        }
    }

    static function buildModSettings(parentProperties:Dynamic, mod:Dynamic):Void {
        var definitions:Array<Dynamic> = cast Reflect.field(mod, "definitions");
        for (index in 0...definitions.length) {
            var definition = definitions[index];
            var key = stringField(definition, "key", "");
            var type = stringField(definition, "type", "");
            var label = stringField(definition, "label", key);
            if (key.length == 0)
                continue;

            var settingParent = createOptionRow(parentProperties, label, index);

            if (type == "checkbox") {
                var checked = boolValue(Reflect.field(mod, "values"), key, false);
                var checkProperties:Dynamic = HlxRuntime.callResolved(createNewMember, [
                    "check-box",
                    settingParent,
                    [""],
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
            } else if (type == "keybinding") {
                var keyCode = intValue(Reflect.field(mod, "values"), key, 0);
                var keyProperties:Dynamic = HlxRuntime.callResolved(createNewMember, [
                    "button",
                    settingParent,
                    [keyName(keyCode)],
                    { id: "setting" + index }
                ]);
                var keyButton:Dynamic = keyProperties == null
                    ? null
                    : HlxRuntime.resolveField(keyProperties, "obj");
                if (keyButton != null) {
                    var targetMod = mod;
                    var targetKey = key;
                    HlxRuntime.callResolved(setOnClickMember, [keyButton, function():Void {
                        beginKeyCapture(targetMod, targetKey, keyButton);
                    }]);
                }
            }
        }
    }

    static function createOptionRow(
        parentProperties:Dynamic,
        label:String,
        index:Int
    ):Dynamic {
        try {
            var optionInfo:Dynamic = {
                id: "BetterModSettings" + index,
                name: label,
                props: { hideRelease: false }
            };
            var lineProperties:Dynamic = HlxRuntime.callResolved(createNewMember, [
                "option-line",
                parentProperties,
                [optionInfo],
                { id: "settingRow" + index }
            ]);
            if (lineProperties == null)
                return parentProperties;
            setFlowHorizontalSpacing(lineProperties, 12);
            var line:Dynamic = HlxRuntime.resolveField(lineProperties, "obj");
            var container:Dynamic = line == null ? null : HlxRuntime.resolveField(line, "container");
            var containerProperties:Dynamic = container == null
                ? null
                : HlxRuntime.resolveField(container, "dom");
            return containerProperties == null ? parentProperties : containerProperties;
        } catch (error:Dynamic) {
            trace("[BetterModSettings] Could not create native option row: " + Std.string(error));
            return parentProperties;
        }
    }

    static function beginKeyCapture(mod:Dynamic, key:String, button:Dynamic):Void {
        capturingKeybind = { mod: mod, key: key, button: button };
        setKeyButtonText(button, "Press a key...");
    }

    static function capturePressedKey():Void {
        if (capturingKeybind == null)
            return;
        if (hxdKeyType == null)
            hxdKeyType = HlxRuntime.resolveType("hxd.Key");
        if (hxdKeyType == null)
            return;
        if (isKeyPressedMember == null)
            isKeyPressedMember = HlxRuntime.resolveStaticMember(hxdKeyType, "isPressed");
        if (isKeyPressedMember == null)
            return;

        for (keyCode in 1...512) {
            var pressed:Dynamic = HlxRuntime.callResolved(isKeyPressedMember, [keyCode]);
            if (pressed != true)
                continue;
            var capture = capturingKeybind;
            capturingKeybind = null;
            if (keyCode == 27) {
                var values:Dynamic = Reflect.field(Reflect.field(capture, "mod"), "values");
                setKeyButtonText(
                    Reflect.field(capture, "button"),
                    keyName(intValue(values, Std.string(Reflect.field(capture, "key")), 0))
                );
                return;
            }
            saveSetting(
                Reflect.field(capture, "mod"),
                Std.string(Reflect.field(capture, "key")),
                keyCode
            );
            setKeyButtonText(Reflect.field(capture, "button"), keyName(keyCode));
            return;
        }
    }

    static function setKeyButtonText(button:Dynamic, text:String):Void {
        if (buttonType == null)
            buttonType = HlxRuntime.resolveType("ui.comp.Button");
        if (buttonType != null && setButtonTextMember == null)
            setButtonTextMember = HlxRuntime.resolveMember(buttonType, "setText");
        if (setButtonTextMember != null)
            HlxRuntime.callResolved(setButtonTextMember, [button, text]);
    }

    static function keyName(keyCode:Int):String {
        if (keyCode <= 0)
            return "Not set";
        if (hxdKeyType == null)
            hxdKeyType = HlxRuntime.resolveType("hxd.Key");
        if (hxdKeyType != null && getKeyNameMember == null)
            getKeyNameMember = HlxRuntime.resolveStaticMember(hxdKeyType, "getKeyName");
        if (getKeyNameMember != null) {
            var name:Dynamic = HlxRuntime.callResolved(getKeyNameMember, [keyCode]);
            if (name != null && Std.string(name).length > 0)
                return Std.string(name);
        }
        return "Key " + keyCode;
    }

    static function setFlowHorizontalSpacing(properties:Dynamic, spacing:Int):Void {
        if (properties == null)
            return;
        try {
            if (flowType == null)
                flowType = HlxRuntime.resolveType("h2d.Flow");
            if (flowType != null && setHorizontalSpacingMember == null)
                setHorizontalSpacingMember = HlxRuntime.resolveMember(flowType, "set_horizontalSpacing");
            var flow:Dynamic = HlxRuntime.resolveField(properties, "obj");
            if (flow != null && setHorizontalSpacingMember != null)
                HlxRuntime.callResolved(setHorizontalSpacingMember, [flow, spacing]);
        } catch (error:Dynamic) {
            trace("[BetterModSettings] Could not space native option row: " + Std.string(error));
        }
    }

    static function setHorizontalPadding(properties:Dynamic, padding:Int):Void {
        if (properties == null)
            return;
        try {
            if (flowType == null)
                flowType = HlxRuntime.resolveType("h2d.Flow");
            if (flowType == null)
                return;
            if (setPaddingLeftMember == null)
                setPaddingLeftMember = HlxRuntime.resolveMember(flowType, "set_paddingLeft");
            if (setPaddingRightMember == null)
                setPaddingRightMember = HlxRuntime.resolveMember(flowType, "set_paddingRight");
            var flow:Dynamic = HlxRuntime.resolveField(properties, "obj");
            if (flow == null)
                return;
            if (setPaddingLeftMember != null)
                HlxRuntime.callResolved(setPaddingLeftMember, [flow, padding]);
            if (setPaddingRightMember != null)
                HlxRuntime.callResolved(setPaddingRightMember, [flow, padding]);
        } catch (error:Dynamic) {
            trace("[BetterModSettings] Could not inset settings panel: " + Std.string(error));
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

    static function intValue(object:Dynamic, key:String, fallback:Int):Int {
        if (object == null || !Reflect.hasField(object, key))
            return fallback;
        var value:Dynamic = Reflect.field(object, key);
        return value == null ? fallback : cast value;
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
