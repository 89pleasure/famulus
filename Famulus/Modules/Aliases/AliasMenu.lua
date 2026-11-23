-- "Set alias" in the context menu of players (unit frames, chat names,
-- friends list, guild roster) and of Battle.net friends.
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

-- Menus that are opened for a player character, and the two for a
-- Battle.net friend: theirs names an account, not a character.
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
    "MENU_UNIT_BN_FRIEND",
    "MENU_UNIT_BN_FRIEND_OFFLINE",
}

-- The full character name the menu was opened for, or nil.
local function TargetName(contextData)
    if contextData.bnetIDAccount then
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

-- The BattleTag the menu is about, or nil: the one a Battle.net friend's
-- menu names, else the account the character is known to belong to, else
-- the friend who is online on that character right now.
local function TargetTag(contextData, name)
    local tag = contextData.battleTag
    if tag == nil and type(contextData.accountInfo) == "table" then
        tag = contextData.accountInfo.battleTag
    end
    tag = AliasService.BattleTag(tag)
    if tag or not name then
        return tag
    end
    return AliasService.Account(name) or AliasService.FindBattleTag(name)
end

local function Remove(target)
    if AliasService.Set(target, nil) then
        ns:Notify(L.msg_alias_removed:format(target))
    end
end

local function AddEntries(_, rootDescription, contextData)
    if type(contextData) ~= "table" then
        return
    end
    local name = TargetName(contextData)
    local tag = TargetTag(contextData, name)
    if not name and not tag then
        return
    end
    local own = name and AliasService.GetOwn(name)
    local shared = tag and AliasService.GetOwn(tag)
    rootDescription:CreateDivider()
    if name then
        rootDescription:CreateButton(own and L.menu_alias_change or L.menu_alias_set, function()
            ns:EditAlias(name)
        end)
    end
    if tag then
        rootDescription:CreateButton(shared and L.menu_alias_account_change or L.menu_alias_account_set, function()
            ns:EditAlias(tag)
        end)
    end
    if own then
        rootDescription:CreateButton(L.menu_alias_remove, function()
            Remove(name)
        end)
    end
    if shared then
        rootDescription:CreateButton(L.menu_alias_account_remove, function()
            Remove(tag)
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
