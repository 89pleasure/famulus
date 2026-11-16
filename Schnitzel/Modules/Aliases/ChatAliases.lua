-- Shows the alias instead of the character name in front of chat messages.
--
-- Uses the client's sender name filter: it changes the text between the
-- brackets only. The link behind it keeps the real name, so whispering,
-- inviting and the context menu still reach the character. The client skips
-- the filter by itself while a sender name is secret.

local _, ns = ...

local AliasService = ns.AliasService

local chatAliases = ns:NewFeature({
    id = "chatAliases",
    category = "aliases",
    default = true,
    requires = { "ChatFrameUtil.AddSenderNameFilter", "ChatFrameUtil.RemoveSenderNameFilter" },
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
        if not ns.ChatService.IsPlainText(shown) then
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

function chatAliases:OnEnable()
    ChatFrameUtil.AddSenderNameFilter(Filter)
end

function chatAliases:OnDisable()
    ChatFrameUtil.RemoveSenderNameFilter(Filter)
end
