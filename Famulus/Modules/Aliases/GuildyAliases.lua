-- Shows aliases in the addon Guildy: its chat, member list and every other
-- place it draws a character name.
--
-- Guildy builds its chat lines itself, so the chat feature's sender name
-- filter never reaches them. Guildy offers a name formatter instead
-- (GuildyAPI.RegisterNameFormatter): it asks for the text to show and keeps
-- the real name for links, whispers and invites. The feature only exists
-- while Guildy is loaded; without it the window does not list it.

local _, ns = ...

local AliasService = ns.AliasService

local OWNER = "Famulus"

local guildyAliases = ns:NewFeature({
    id = "guildyAliases",
    category = "aliases",
    icon = "shield", -- its entry in the settings (UI.media)
    preview = "guildy", -- its picture there (UI/Previews.lua)
    default = true,
    addon = "Guildy",
    requires = {
        "GuildyAPI.RegisterNameFormatter",
        "GuildyAPI.UnregisterNameFormatter",
        "GuildyAPI.Refresh",
    },
    options = {
        { key = "style", type = "select", default = "alias", values = { "alias", "both" } },
    },
})

-- Guildy passes the name as it shows it ("First Last") and never a secret
-- value; AliasService.Get refuses anything else by itself. nil keeps the name.
local function Format(name)
    local alias = AliasService.Get(name)
    if alias then
        return AliasService.Format(alias, name, guildyAliases:Get("style"))
    end
    return nil
end

local function Refresh()
    if guildyAliases.enabled then
        GuildyAPI.Refresh()
    end
end

function guildyAliases:OnEnable()
    GuildyAPI.RegisterNameFormatter(OWNER, Format)
end

function guildyAliases:OnDisable()
    GuildyAPI.UnregisterNameFormatter(OWNER)
end

function guildyAliases:OnOptionChanged()
    Refresh()
end

ns:On("ALIASES_CHANGED", Refresh)
