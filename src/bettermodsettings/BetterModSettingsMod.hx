package bettermodsettings;

import imgui.ImGui;

@:build(hlx.runtime.Mod.build())
class BetterModSettingsMod {
    static var activeEscapeMenu:Dynamic;
    static var modSettingsButton:Dynamic;
    static var nativeSettingsWindow:Dynamic;

    static var propertiesType:hl.Bytes;
    static var uiElementType:hl.Bytes;
    static var titleWindowType:hl.Bytes;
    static var createNewMember:hlx.runtime.ResolvedMember;
    static var getParentPropertiesMember:hlx.runtime.ResolvedMember;
    static var setOnClickMember:hlx.runtime.ResolvedMember;

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

            var contentAttributes:Dynamic = { id: "betterModSettingsContent" };
            Reflect.setField(contentAttributes, "class", "content");
            var contentProperties:Dynamic = HlxRuntime.callResolved(createNewMember, [
                "flow",
                windowProperties,
                [],
                contentAttributes
            ]);
            if (contentProperties != null) {
                HlxRuntime.callResolved(createNewMember, [
                    "text",
                    contentProperties,
                    ["Compatible mod settings will appear here."],
                    { id: "betterModSettingsPlaceholder" }
                ]);
            }

            trace("[BetterModSettings] Native Mod Settings window opened");
        } catch (error:Dynamic) {
            nativeSettingsWindow = null;
            trace("[BetterModSettings] Could not open native settings window: " + Std.string(error));
        }
    }

    static function draw():Void {}

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
