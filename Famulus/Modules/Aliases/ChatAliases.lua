-- Shows the alias instead of the character name in chat.
--
-- In front of chat messages it uses the client's sender name filter: it
-- changes the text between the brackets only. The link behind it keeps the
-- real name, so whispering, inviting and the context menu still reach the
-- character. The client skips the filter by itself while a sender name is
-- secret.
--
-- The game's notices that someone came online or went offline are system
-- lines without a sender; the name sits in the text. A message filter on
-- CHAT_MSG_SYSTEM changes the text shown in a player link ("[Name] has come
-- online.") and the name in the offline line, which has no link. The link
-- target stays the real name here as well. The client skips message filters
-- by itself while a line is secret.

local _, ns = ...

local AliasService = ns.AliasService
local IsPlainText = ns.ChatService.IsPlainText

local chatAliases = ns:NewFeature({
    id = "chatAliases",
    category = "aliases",
    icon = "chat", -- its entry in the settings (UI.media)
    default = true,
    requires = {
        "ChatFrameUtil.AddSenderNameFilter", "ChatFrameUtil.RemoveSenderNameFilter",
        "ChatFrameUtil.AddMessageEventFilter", "ChatFrameUtil.RemoveMessageEventFilter",
    },
    options = {
        { key = "style", type = "select", default = "alias", values = { "alias", "both" } },
    },
})

-- decorated is the name as the chat is about to print it: shortened and
-- usually wrapped in the class colour. Returning nil leaves it unchanged.
local function Filter(event, decorated, _, sender)
    local alias = AliasService.Get(sender)
    if not alias or ns.IsSecret(decorated) or type(decorated) ~= "string" then
        return nil
    end
    local shown = sender
    if Ambiguate then
        shown = Ambiguate(sender, event == "CHAT_MSG_GUILD" and "guild" or "none")
        if not IsPlainText(shown) then
            shown = sender
        end
    end
    local text = AliasService.Format(alias, shown, chatAliases:Get("style"))
    local from, to = string.find(decorated, shown, 1, true)
    if from then
        return string.sub(decorated, 1, from - 1) .. text .. string.sub(decorated, to + 1)
    end
    return text
end

---------------------------------------------------------------------------
-- System lines
---------------------------------------------------------------------------

-- The text between the brackets of a player link: the name, possibly in a
-- colour. Returns it with the alias in place of the name, or nil.
local function SwapLinkText(inner, alias)
    local head, name, tail = string.match(inner, "^(|c%x%x%x%x%x%x%x%x)([^|]+)(|r)$")
    if not head then
        if string.find(inner, "|", 1, true) then
            return nil
        end
        head, name, tail = "", inner, ""
    end
    return head .. AliasService.Format(alias, name, chatAliases:Get("style")) .. tail
end

local function SwapLink(target, inner)
    local alias = AliasService.Get(string.match(target, "^[^:]+"))
    local text = alias and SwapLinkText(inner, alias)
    if text then
        return "|Hplayer:" .. target .. "|h[" .. text .. "]|h"
    end
    return nil
end

-- ERR_FRIEND_OFFLINE_S ("%s has gone offline.") as a pattern that captures
-- the name. Built once per text of the game.
local offlineText, offlinePattern
local function OfflinePattern()
    local text = ERR_FRIEND_OFFLINE_S
    if type(text) ~= "string" then
        return nil
    end
    if text ~= offlineText then
        offlineText = text
        local escaped = string.gsub(text, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0")
        local pattern, found = string.gsub(escaped, "%%%%s", "(.+)")
        offlinePattern = found == 1 and "^" .. pattern .. "$" or nil
    end
    return offlinePattern
end

-- A message filter gets the chat frame, the event and the event's
-- arguments; it returns whether to drop the line and, to change it, the
-- arguments anew. Returning false alone leaves the line as it is.
local function SystemFilter(chatFrame, _, message, ...)
    if AliasService.Count() == 0 or not IsPlainText(message) then
        return false
    end
    -- A whisper window of its own picks the online and offline lines of its
    -- partner by comparing them with the game's text; changed, they would
    -- not show there.
    if type(chatFrame) == "table" and chatFrame.privateMessageList then
        return false
    end
    local text = message
    if string.find(message, "|Hplayer:", 1, true) then
        text = string.gsub(message, "|Hplayer:([^|]*)|h%[(.-)%]|h", SwapLink)
    end
    if text == message then
        local pattern = OfflinePattern()
        local name = pattern and string.match(message, pattern)
        local alias = name and AliasService.Get(name)
        if not alias then
            return false
        end
        text = string.format(ERR_FRIEND_OFFLINE_S, AliasService.Format(alias, name, chatAliases:Get("style")))
    end
    return false, text, ...
end

function chatAliases:OnEnable()
    ChatFrameUtil.AddSenderNameFilter(Filter)
    ChatFrameUtil.AddMessageEventFilter("CHAT_MSG_SYSTEM", SystemFilter)
end

function chatAliases:OnDisable()
    ChatFrameUtil.RemoveSenderNameFilter(Filter)
    ChatFrameUtil.RemoveMessageEventFilter("CHAT_MSG_SYSTEM", SystemFilter)
end
