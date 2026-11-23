-- ChatService: plain-text checks and the chat lockdown, as features use them.
-- During chat lockdown (boss fights, rated PvP) the game refuses addon
-- messages, so senders wait until it ends.

local _, ns = ...

local ChatService = {}
ns.ChatService = ChatService

function ChatService.IsPlainText(value)
    return not ns.IsSecret(value) and type(value) == "string" and value ~= ""
end

function ChatService.InLockdown()
    if not (C_ChatInfo and C_ChatInfo.InChatMessagingLockdown) then
        return false
    end
    local ok, locked = pcall(C_ChatInfo.InChatMessagingLockdown)
    return ok and not ns.IsSecret(locked) and locked and true or false
end
