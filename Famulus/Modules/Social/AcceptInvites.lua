-- Accepts group invites from friends and guild members.

local _, ns = ...
local L = ns.L

local invites = ns:NewFeature({
    id = "acceptInvites",
    category = "social",
    default = false,
    requires = { "AcceptGroup" },
})

local function IsTrusted(guid)
    if ns.IsSecret(guid) or not guid then
        return false
    end
    if C_FriendList and C_FriendList.IsFriend and C_FriendList.IsFriend(guid) then
        return true
    end
    if IsGuildMember and IsGuildMember(guid) then
        return true
    end
    if C_BattleNet and C_BattleNet.GetAccountInfoByGUID then
        local account = C_BattleNet.GetAccountInfoByGUID(guid)
        if account and account.isFriend then
            return true
        end
    end
    return false
end

function invites:OnEnable()
    self:RegisterEvent("PARTY_INVITE_REQUEST")
end

function invites:PARTY_INVITE_REQUEST(_, name, _, _, _, _, _, inviterGUID)
    if ns:IsPaused() or not IsTrusted(inviterGUID) then
        return
    end
    AcceptGroup()
    -- Close the invite popup only once we really are in the group. Closing
    -- it earlier would make the popup decline the invitation again.
    self:RegisterEvent("GROUP_ROSTER_UPDATE")
    ns:Notify(L.msg_invite_accepted:format(ns.Label(name)))
end

function invites:GROUP_ROSTER_UPDATE()
    self:UnregisterEvent("GROUP_ROSTER_UPDATE")
    ns.PopupService.Hide("PARTY_INVITE")
end
