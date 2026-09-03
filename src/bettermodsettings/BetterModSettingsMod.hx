package bettermodsettings;

import imgui.ImGui;
import imgui.ref.BoolRef;

@:build(hlx.runtime.Mod.build())
class BetterModSettingsMod {
    static var windowOpen = new BoolRef(false);
    static var modSettingsButton:Dynamic;

    static var propertiesType:hl.Bytes;
    static var uiElementType:hl.Bytes;
    static var h2dObjectType:hl.Bytes;
    static var createNewMember:hlx.runtime.ResolvedMember;
    static var getParentPropertiesMember:hlx.runtime.ResolvedMember;
    static var setOnClickMember:hlx.runtime.ResolvedMember;
    static var getChildIndexMember:hlx.runtime.ResolvedMember;
    static var addChildAtMember:hlx.runtime.ResolvedMember;

    static function main():Void {
        ImGui.register(HlxRuntime.moduleName(), draw);
    }

    @:hlx.postfix(ui.win.EscapeMenu.init)
    static function afterEscapeMenuInit(instance:Dynamic, result:Void):Void {
        modSettingsButton = null;

        try {
            if (!resolveUiMembers())
                return;

            var optionsButton:Dynamic = HlxRuntime.resolveField(instance, "optionsBtn");
            var optionsProperties:Dynamic = optionsButton == null
                ? null
                : HlxRuntime.resolveField(optionsButton, "dom");
            if (optionsProperties == null)
                return;

            var menuListProperties:Dynamic = HlxRuntime.callResolved(
                getParentPropertiesMember,
                [optionsProperties]
            );
            if (menuListProperties == null)
                return;

            var createdProperties:Dynamic = HlxRuntime.callResolved(createNewMember, [
                "button",
                menuListProperties,
                ["Mod Settings"],
                { id: "betterModSettingsButton" }
            ]);
            if (createdProperties == null)
                return;

            modSettingsButton = HlxRuntime.resolveField(createdProperties, "obj");
            if (modSettingsButton == null)
                return;

            HlxRuntime.callResolved(setOnClickMember, [modSettingsButton, openSettings]);

            var menuList:Dynamic = HlxRuntime.resolveField(menuListProperties, "obj");
            if (menuList != null) {
                var optionsIndex:Dynamic = HlxRuntime.callResolved(
                    getChildIndexMember,
                    [menuList, optionsButton]
                );
                if (optionsIndex != null && cast optionsIndex >= 0) {
                    HlxRuntime.callResolved(
                        addChildAtMember,
                        [menuList, modSettingsButton, cast optionsIndex + 1]
                    );
                }
            }
        } catch (error:Dynamic) {
            modSettingsButton = null;
            trace("[BetterModSettings] Could not add Escape menu button: " + Std.string(error));
        }
    }

    static function openSettings():Void {
        windowOpen.set(true);
    }

    static function draw():Void {
        if (!windowOpen.get())
            return;

        if (!ImGui.begin("Mod Settings", windowOpen)) {
            ImGui.end();
            return;
        }

        ImGui.text("Better Mod Settings");
        ImGui.separator();
        ImGui.text("Compatible mod settings will appear here.");
        ImGui.end();
    }

    static function resolveUiMembers():Bool {
        if (propertiesType == null)
            propertiesType = HlxRuntime.resolveType("domkit.Properties");
        if (uiElementType == null)
            uiElementType = HlxRuntime.resolveType("ui.UIElement");
        if (h2dObjectType == null)
            h2dObjectType = HlxRuntime.resolveType("h2d.Object");
        if (propertiesType == null || uiElementType == null || h2dObjectType == null)
            return false;

        if (createNewMember == null)
            createNewMember = HlxRuntime.resolveStaticMember(propertiesType, "createNew");
        if (getParentPropertiesMember == null)
            getParentPropertiesMember = HlxRuntime.resolveMember(propertiesType, "get_parent");
        if (setOnClickMember == null)
            setOnClickMember = HlxRuntime.resolveMember(uiElementType, "set_onClick");
        if (getChildIndexMember == null)
            getChildIndexMember = HlxRuntime.resolveMember(h2dObjectType, "getChildIndex");
        if (addChildAtMember == null)
            addChildAtMember = HlxRuntime.resolveMember(h2dObjectType, "addChildAt");

        return createNewMember != null
            && getParentPropertiesMember != null
            && setOnClickMember != null
            && getChildIndexMember != null
            && addChildAtMember != null;
    }
}

