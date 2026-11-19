-- Notices when a friend has gained a level and writes it into the chronicle.
-- Works without the friend's cooperation: the friends list tells level and
-- whereabouts of friends who are online. More than that (deaths, bosses)
-- only the friend's own client knows.

local _, ns = ...
local Chronicle = ns.ChronicleService

local companions = ns:NewFeature({
    id = "companions",
    category = "chronicle",
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
    for i = 1, C_FriendList.GetNumFriends() or 0 do
        local info = C_FriendList.GetFriendInfoByIndex(i)
        -- An offline friend comes with level 0; that is not a change.
        if info and info.connected and not ns.IsSecret(info.level) and (tonumber(info.level) or 0) > 0 then
            local known = Chronicle.FriendLevel(info.guid)
            if known and info.level > known then
                Chronicle.Add("friendLevel", { who = info.name, level = info.level, zone = info.area })
            end
            if known ~= info.level then
                Chronicle.FriendLevel(info.guid, info.level)
            end
        end
    end
end
