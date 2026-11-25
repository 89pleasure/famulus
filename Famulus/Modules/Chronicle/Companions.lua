-- Notices when a friend has gained a level and writes it into the chronicle.
-- Works without the friend's cooperation: the friends list tells level and
-- whereabouts of friends who are online. More than that (deaths, bosses)
-- only the friend's own client knows.

local _, ns = ...
local Chronicle = ns.ChronicleService

local companions = ns:NewFeature({
    id = "companions",
    category = "chronicle",
    icon = "people", -- its entry in the settings (UI.media)
    preview = "friends", -- its picture there (UI/Previews.lua)
    default = false,
    requires = { "C_FriendList.GetNumFriends", "C_FriendList.GetFriendInfoByIndex" },
})

function companions:OnEnable()
    self:RegisterEvent("FRIENDLIST_UPDATE")
    if C_FriendList.ShowFriends then
        C_FriendList.ShowFriends() -- asks the server for a fresh list
    end
end

function companions:FRIENDLIST_UPDATE()
    ns.SocialService.EachFriend(function(info)
        -- An offline friend comes with level 0; that is not a change.
        if not ns.IsSecret(info.connected) and info.connected and not ns.IsSecret(info.level) and (tonumber(info.level) or 0) > 0 then
            local known = Chronicle.FriendLevel(info.guid)
            if known and info.level > known then
                -- The class for the picture beside their name; the list names it in the client's language.
                Chronicle.Class(info.name, ns.SocialService.ClassFromName(info.className))
                Chronicle.Add("friendLevel", { who = info.name, level = info.level, zone = info.area })
            end
            if known ~= info.level then
                Chronicle.FriendLevel(info.guid, info.level)
            end
        end
    end)
end
