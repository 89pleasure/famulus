-- Keeps the characters of Battle.net friends who have an alias up to date.
--
-- An alias for a BattleTag covers every character of that account, but the
-- client only tells which character a friend is playing right now. This
-- feature watches the Battle.net friends list and hands what it sees to the
-- AliasService, which remembers it.
--
-- It listens to the game only while at least one account has an alias;
-- without one it costs nothing. Switched off, account aliases still apply
-- to the characters that are already known.

local _, ns = ...

local AliasService = ns.AliasService

local accountAliases = ns:NewFeature({
    id = "accountAliases",
    category = "aliases",
    icon = "link", -- its entry in the settings (UI.media)
    preview = "bnet", -- its picture there (UI/Previews.lua)
    default = true,
    requires = {
        "BNGetNumFriends",
        "C_BattleNet.GetFriendAccountInfo",
        "C_BattleNet.GetFriendNumGameAccounts",
        "C_BattleNet.GetFriendGameAccountInfo",
    },
})

accountAliases.EVENTS = { "BN_FRIEND_INFO_CHANGED", "BN_FRIEND_ACCOUNT_ONLINE", "BN_CONNECTED" }

local watching = false

-- BN_FRIEND_INFO_CHANGED names the friend by their place in the list; the
-- other events do not, so the whole list is read.
local function OnFriends(_, event, index)
    if event ~= "BN_FRIEND_INFO_CHANGED" or ns.IsSecret(index) or type(index) ~= "number" then
        index = nil
    end
    AliasService.ScanFriends(index)
end

local function Watch(self)
    local wanted = AliasService.AccountCount() > 0
    if wanted == watching then
        return
    end
    watching = wanted
    for _, event in ipairs(self.EVENTS) do
        if wanted then
            self:RegisterEvent(event, OnFriends)
        else
            self:UnregisterEvent(event)
        end
    end
    if wanted then
        AliasService.ScanFriends()
    end
end

function accountAliases:OnEnable()
    Watch(self)
end

function accountAliases:OnDisable()
    watching = false
end

ns:On("ALIASES_CHANGED", function()
    if accountAliases.enabled then
        Watch(accountAliases)
    end
end)
