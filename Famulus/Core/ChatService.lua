-- ChatService: plain-text checks, the chat lockdown and whispers, as
-- features and the window use them. During chat lockdown (boss fights, rated
-- PvP) the game refuses addon messages, so senders wait until it ends.
--
--   ChatService.CanWhisper() -> true if the client can open a whisper
--   ChatService.Whisper(name)
--       Opens the chat box with a whisper to them, as Blizzard's friends
--       frame does; the player writes and sends it, the addon sends nothing.

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

function ChatService.CanWhisper()
    return ChatFrameUtil ~= nil and ChatFrameUtil.SendTell ~= nil
end

function ChatService.Whisper(name)
    if ChatService.CanWhisper() and ChatService.IsPlainText(name) then
        ChatFrameUtil.SendTell(name)
    end
end
