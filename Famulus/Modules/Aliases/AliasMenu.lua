-- "Set alias" in the context menu of players (unit frames, chat names,
-- friends list, guild roster).
--
-- Menu.ModifyMenu is the client's own way for addons to add entries; it does
-- not taint the entries around ours. The entries only open Famulus's
-- window or change Famulus's list.

local _, ns = ...
local L = ns.L

local AliasService = ns.AliasService

local aliasMenu = ns:NewFeature({
    id = "aliasMenu",
    category = "aliases",
    default = true,
    requires = { "Menu.ModifyMenu" },
})

-- Menus that are opened for a player character. Battle.net friends are left
-- out: their menu names an account, not a character.
aliasMenu.TAGS = {
    "MENU_UNIT_PLAYER",
    "MENU_UNIT_ENEMY_PLAYER",
    "MENU_UNIT_PARTY",
    "MENU_UNIT_RAID_PLAYER",
    "MENU_UNIT_RAID",
    "MENU_UNIT_TARGET",
    "MENU_UNIT_FOCUS",
    "MENU_UNIT_FRIEND",
    "MENU_UNIT_FRIEND_OFFLINE",
    "MENU_UNIT_RECENT_ALLY",
    "MENU_UNIT_RECENT_ALLY_OFFLINE",
    "MENU_UNIT_CHAT_ROSTER",
    "MENU_UNIT_GUILD",
    "MENU_UNIT_GUILD_OFFLINE",
    "MENU_UNIT_COMMUNITIES_WOW_MEMBER",
    "MENU_UNIT_COMMUNITIES_GUILD_MEMBER",
}

-- The full character name the menu was opened for, or nil.
local function TargetName(contextData)
    if type(contextData) ~= "table" or contextData.bnetIDAccount then
        return nil
    end
    local unit = contextData.unit
    if unit then
        -- Target and focus menus also open for creatures.
        if ns.IsSecret(unit) or not UnitIsPlayer then
            return nil
        end
        local isPlayer = UnitIsPlayer(unit)
        if ns.IsSecret(isPlayer) or not isPlayer then
            return nil
        end
    end
    return AliasService.FullName(contextData.name, contextData.surname)
end

local function AddEntries(_, rootDescription, contextData)
    local name = TargetName(contextData)
    if not name then
        return
    end
    local alias = AliasService.Get(name)
    rootDescription:CreateDivider()
    rootDescription:CreateButton(alias and L.menu_alias_change or L.menu_alias_set, function()
        ns:EditAlias(name)
    end)
    if alias then
        rootDescription:CreateButton(L.menu_alias_remove, function()
            if AliasService.Set(name, nil) then
                ns:Notify(L.msg_alias_removed:format(name))
            end
        end)
    end
end

function aliasMenu:OnEnable()
    self:Once("hooks", function()
        local callback = self:Guard(AddEntries)
        for _, tag in ipairs(self.TAGS) do
            Menu.ModifyMenu(tag, callback)
        end
    end)
end
