-- ChatService: the chat input box, as features use it.
--
-- Text is only ever put into the box for the player to send; nothing is sent
-- by the addon. During chat lockdown (boss fights, rated PvP) the game
-- refuses text an addon put into the box, so nothing is inserted then.

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

-- The slash command that sends to the box's current target, with a trailing
-- space: "/y ", "/w Name ", "/2 ". Text typed after it goes where the box was
-- set to send, because the game turns the prefix back into the chat type.
-- Reads the box's attributes only. Returns "" when the target is unknown.
function ChatService.TargetPrefix(editBox)
    local chatType = editBox and editBox:GetAttribute("chatType")
    if not ChatService.IsPlainText(chatType) then
        return ""
    end
    if chatType == "WHISPER" then
        local target = editBox:GetAttribute("tellTarget")
        local slash = _G.SLASH_WHISPER1
        if ChatService.IsPlainText(target) and ChatService.IsPlainText(slash) then
            return slash .. " " .. target .. " "
        end
        return ""
    elseif chatType == "CHANNEL" then
        local channel = editBox:GetAttribute("channelTarget")
        if not ns.IsSecret(channel) and channel and channel ~= "" then
            return "/" .. tostring(channel) .. " "
        end
        return ""
    end
    local slash = _G["SLASH_" .. chatType .. "1"]
    return ChatService.IsPlainText(slash) and (slash .. " ") or ""
end

-- Puts text into the chat input at the cursor; opens the input if it is
-- closed. A newly opened input starts with prefix (see TargetPrefix), so it
-- sends where a just-closed input would have. Returns true if the text went in.
function ChatService.InsertText(text, prefix)
    if not ChatService.IsPlainText(text) or ChatService.InLockdown() then
        return false
    end
    local util = ChatFrameUtil
    if not util then
        return false
    end
    if util.InsertLink and util.InsertLink(text) then
        return true
    end
    if util.OpenChat then
        util.OpenChat((prefix or "") .. text)
        return true
    end
    return false
end
