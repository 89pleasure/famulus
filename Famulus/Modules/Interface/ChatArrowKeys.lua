-- Arrow keys in the chat input without Alt, plus a sent-line history.
--
-- The client's own sent-line history does not answer in WoW Forever (seen in
-- game, and noted the same way by OneForAll and FlareUI), so Up and Down
-- step through a list of our own. It lives in memory only, like the game's.

local _, ns = ...

local arrowKeys = ns:NewFeature({
    id = "chatArrowKeys",
    category = "interface",
    default = true,
})

local SENT_MAX = 30
local sentLines = {} -- newest last

-- State per chat edit box is kept here, never as fields on Blizzard's frames.
local touchedEditBoxes = {} -- boxes whose Alt mode we switched
local historyPos = setmetatable({}, { __mode = "k" }) -- 0 = not browsing
local drafts = setmetatable({}, { __mode = "k" }) -- text typed before browsing
local lastSentAt = setmetatable({}, { __mode = "k" })

local IsPlainText = ns.ChatService.IsPlainText
-- During chat lockdown the game refuses text an addon put into the box.
local InChatLockdown = ns.ChatService.InLockdown

-- Commands such as /cast or /target only run from a real key press; put back
-- into the box by addon code they would be blocked. Without IsSecureCmd every
-- command is treated as secure.
local function IsSecureCommand(command)
    if not IsSecureCmd then
        return true
    end
    local ok, secure = pcall(IsSecureCmd, command)
    return not ok or secure and true or false
end

-- The line as typed with its target, e.g. "/w Name text" or "/2 text", so a
-- recalled line goes where it went the first time.
local function WithTarget(editBox, text)
    return ns.ChatService.TargetPrefix(editBox) .. text
end

local function ResetBrowsing(editBox)
    historyPos[editBox], drafts[editBox] = 0, nil
end

-- Remembers the line that is about to be sent. Called on Enter and when the
-- game announces the send; the time check keeps it to once per line.
local function RememberLine(editBox)
    local now = GetTime()
    if lastSentAt[editBox] == now then
        return
    end
    lastSentAt[editBox] = now
    ResetBrowsing(editBox)

    local text = editBox:GetText()
    if not IsPlainText(text) or not text:find("%S") then
        return
    end
    local command = text:match("^(/%S+)")
    if command then
        if IsSecureCommand(command) then
            return
        end
    else
        text = WithTarget(editBox, text)
    end
    if sentLines[#sentLines] ~= text then
        sentLines[#sentLines + 1] = text
        if #sentLines > SENT_MAX then
            table.remove(sentLines, 1)
        end
    end
    -- Keep the client's own list empty so it cannot compete with ours.
    if editBox.ClearHistory then
        C_Timer.After(0, function()
            pcall(editBox.ClearHistory, editBox)
        end)
    end
end

local function Browse(editBox, key)
    if #sentLines == 0 then
        return
    end
    local pos = historyPos[editBox] or 0
    if key == "UP" then
        if pos == 0 then
            local typed = editBox:GetText()
            drafts[editBox] = IsPlainText(typed) and typed or nil
        end
        pos = math.min(pos + 1, #sentLines)
    elseif pos == 0 then
        return
    else
        pos = pos - 1
    end
    historyPos[editBox] = pos
    local text = pos == 0 and (drafts[editBox] or "") or sentLines[#sentLines - pos + 1]
    editBox:SetText(text)
    editBox:SetCursorPosition(#text)
end

local function OnKeyDown(editBox, key)
    -- The name list under a half-typed whisper uses Enter and the arrows itself.
    local picking = AutoCompleteBox and AutoCompleteBox:IsShown() and AutoCompleteBox.parent == editBox
    if picking then
        return
    end
    if key == "ENTER" or key == "NUMPADENTER" then
        RememberLine(editBox)
    elseif (key == "UP" or key == "DOWN") and not IsControlKeyDown() and not InChatLockdown() then
        Browse(editBox, key)
    end
end

local function SetUpEditBox(editBox)
    if not (editBox and editBox.SetAltArrowKeyMode) then
        return
    end
    touchedEditBoxes[editBox] = true
    editBox:SetAltArrowKeyMode(false)
    arrowKeys:HookScript(editBox, "OnKeyDown", OnKeyDown)
end

-- Focus also covers chat windows created after login (whisper tabs) and
-- anything that put the Alt mode back in the meantime.
function arrowKeys:OnEditBoxFocusGained(editBox)
    SetUpEditBox(editBox)
end

function arrowKeys:OnEditBoxFocusLost(editBox)
    if editBox then
        ResetBrowsing(editBox)
    end
end

function arrowKeys:OnEditBoxPreSendText(editBox)
    if editBox then
        RememberLine(editBox)
    end
end

function arrowKeys:OnEnable()
    for i = 1, NUM_CHAT_WINDOWS or 10 do
        SetUpEditBox(_G["ChatFrame" .. i .. "EditBox"])
    end
    self:RegisterCallback("ChatFrame.OnEditBoxFocusGained", "OnEditBoxFocusGained")
    self:RegisterCallback("ChatFrame.OnEditBoxFocusLost", "OnEditBoxFocusLost")
    self:RegisterCallback("ChatFrame.OnEditBoxPreSendText", "OnEditBoxPreSendText")
end

function arrowKeys:OnDisable()
    for editBox in pairs(touchedEditBoxes) do
        editBox:SetAltArrowKeyMode(true)
    end
    wipe(touchedEditBoxes)
    wipe(historyPos)
    wipe(drafts)
end
