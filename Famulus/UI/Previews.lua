-- Pictures of what a setting does, above the chosen entry of a settings tab
-- (UI/Options.lua). They are no screenshots: each is a small scene drawn
-- from the addon's own building blocks (the live feed's card, the way the
-- alias service writes a name) with the chronicle's sample people. So a
-- scene follows the switches, the colour scheme and the language by itself,
-- and a change to the addon needs no new picture.
--
--   feature.preview = "feed"                  -- the feature's scene (SCENES below)
--   UI.Previews.Stage(parent, width, height)  -- the frame scenes are drawn on
--   UI.Previews.Show(stage, name)             -- false if there is no such scene
--   UI.Previews.Focus(stage, key)             -- the option pointed at, or nil
--   UI.Previews.Refresh(stage)                -- after a setting changed
--   UI.Previews.Has(name)                     -- whether there is such a scene
--
-- A scene is built the first time it is shown and kept. What moves does so
-- by the client's animations, only while the scene is visible; no Lua runs
-- per frame.

local _, ns = ...
local UI = ns.UI
local L = ns.L

local Previews = {}
UI.Previews = Previews

local RADIUS = 8 -- the picture's corners
local SCENES = {}

-- Width a text would take on one line.
local function TextWidth(text)
    return (text.GetUnboundedStringWidth or text.GetStringWidth)(text) or 0
end

local function Animate(scene, playing)
    for _, group in ipairs(scene.animations) do
        if playing then
            group:Play()
        else
            group:Stop()
        end
    end
end

---------------------------------------------------------------------------
-- Pieces of a scene
---------------------------------------------------------------------------

-- A soft spot of a colour (shadow.tga), centred on a point of the scene.
local function Soft(scene, token, width, height, point, x, y, sublevel)
    local spot = scene:CreateTexture(nil, "BACKGROUND", nil, sublevel)
    spot:SetTexture(UI.media.shadow)
    spot:SetSize(width, height)
    spot:SetPoint("CENTER", scene, point, x, y)
    UI.Tint(spot, token)
    return spot
end

-- The game world at night, behind what the game shows on screen: a sky
-- that darkens towards the land, the moon with its glow, low hills. Haze
-- and hills fade out before the rounded corners, which the stage's square
-- clipping would otherwise show.
local function World(scene, width, height)
    local sky = UI.Round(scene, "sceneSky", RADIUS)
    sky:SetGradient("VERTICAL", "sceneSky", "sceneLand", width, height)
    Soft(scene, "sceneHaze", 300, 180, "TOPRIGHT", -150, -70, 2)
    Soft(scene, "sceneHill", 320, 140, "BOTTOMLEFT", width * 0.3, -20, 3)
    Soft(scene, "sceneHill", 300, 120, "BOTTOMRIGHT", -width * 0.3, -26, 3)
    Soft(scene, "sceneMoonGlow", 96, 96, "TOPRIGHT", -78, -40, 4)
    local moon = scene:CreateTexture(nil, "BACKGROUND", nil, 5)
    moon:SetTexture(UI.media.circle)
    moon:SetSize(30, 30)
    moon:SetPoint("CENTER", scene, "TOPRIGHT", -78, -40)
    UI.Tint(moon, "sceneMoon")
end

-- A short line on a dark pill: what the picture shows right now.
local function Caption(scene)
    local caption = CreateFrame("Frame", nil, scene)
    caption:SetHeight(22)
    caption.ground = UI.Round(caption, "sceneCaption", 11)
    caption.text = UI.Text(caption, 11, "textDim", "medium")
    caption.text:SetPoint("CENTER")
    caption.text:SetJustifyV("MIDDLE")
    caption.text:SetWordWrap(false)
    function caption:Set(text)
        self.text:SetText(text)
        self:SetWidth(math.floor(TextWidth(self.text) + 20.5))
    end
    return caption
end

-- A fine frame in the accent around a piece of text: what the setting changes.
local function Outline(parent)
    local outline = CreateFrame("Frame", nil, parent)
    local top, bottom = UI.Line(outline, "accent"), UI.Line(outline, "accent")
    local left, right = UI.VLine(outline, "accent"), UI.VLine(outline, "accent")
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")
    bottom:SetPoint("BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT")
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    return outline
end

---------------------------------------------------------------------------
-- Live feed: its cards at the top of the screen, as the feed draws them.
-- Without a focus two friends' events and how long a card stays; pointed at
-- a kind of event, a card of that kind, faint while the kind is off.
---------------------------------------------------------------------------

local FEED_TOP, FEED_GAP = 16, 10

local function FeedStory(kind)
    local Chronicle = ns.ChronicleService
    if kind == "reaction" then
        local mira = Chronicle.SamplePeople()
        return ns.features.liveFeed.ReactionStory(Chronicle.Sample("level", true), mira, "cheer")
    end
    local entry = Chronicle.Sample(kind)
    return entry and UI.ChronicleStory(entry) or nil
end

local function IsKind(feature, key)
    for _, kind in ipairs(feature.KINDS) do
        if kind == key then
            return true
        end
    end
    return false
end

SCENES.feed = {
    Build = function(scene, width, height)
        World(scene, width, height)
        scene.cards = {}
        for index = 1, 2 do
            local card = UI.Feed.Card(scene)
            -- How long it stays: a line along its foot that runs out.
            local bar = card:CreateTexture(nil, "OVERLAY")
            bar:SetHeight(2)
            bar:SetPoint("BOTTOMLEFT", 10, 2)
            bar:SetPoint("BOTTOMRIGHT", -10, 2)
            UI.Shade(bar, "HORIZONTAL", "accent", "accent2")
            local group = bar:CreateAnimationGroup()
            group:SetLooping("REPEAT")
            local run = group:CreateAnimation("Scale")
            run:SetScaleFrom(1, 1)
            run:SetScaleTo(0.001, 1)
            run:SetOrigin("LEFT", 0, 0)
            card.bar, card.run = bar, run
            scene.animations[#scene.animations + 1] = group
            scene.cards[index] = card
        end
        scene.caption = Caption(scene)
    end,

    Fill = function(scene, focus)
        local feature = ns.features.liveFeed
        local seconds = feature.SECONDS[feature:Get("duration")] or feature.SECONDS.normal
        local stories, faint, caption
        if focus and IsKind(feature, focus) then
            local on = feature.enabled and feature:Get(focus) == true
            stories, faint = { FeedStory(focus) }, not on
            caption = on and L.ui_preview_feed_shown or L.ui_preview_feed_hidden
        else
            stories, faint = { FeedStory("level"), FeedStory("boss") }, not feature.enabled
            caption = feature.enabled and L.ui_preview_feed_seconds:format(seconds) or L.ui_preview_feed_off
        end

        local widest, y = 0, FEED_TOP
        for index, card in ipairs(scene.cards) do
            local story = stories[index]
            card:SetShown(story ~= nil)
            if story then
                UI.Feed.Fill(card, story)
                widest = math.max(widest, card:GetWidth())
                card:SetAlpha(faint and 0.38 or 1)
                card.bar:SetShown(not faint)
                card.run:SetDuration(seconds)
            end
        end
        -- Left edges in line, as on screen; the stack in the middle.
        local left = math.floor((scene.width - widest) / 2)
        for index, card in ipairs(scene.cards) do
            if stories[index] then
                card:ClearAllPoints()
                card:SetPoint("TOPLEFT", scene, "TOPLEFT", left, -y)
                y = y + UI.Feed.HEIGHT + FEED_GAP
            end
        end
        scene.caption:Set(caption)
        scene.caption:ClearAllPoints()
        scene.caption:SetPoint("TOP", scene, "TOP", 0, -(y + 2))
    end,
}

---------------------------------------------------------------------------
-- Aliases in chat: a few lines of chat; one friend there under their alias,
-- written as the feature writes it, also in the notice that they came online.
-- Switched off, the chat shows their name.
---------------------------------------------------------------------------

local CHAT_LINE, CHAT_PAD = 18, 8

SCENES.chat = {
    Build = function(scene, width, height)
        World(scene, width, height)
        local box = CreateFrame("Frame", nil, scene)
        box:SetPoint("BOTTOMLEFT", 20, 18)
        box:SetHeight(4 * CHAT_LINE + 2 * CHAT_PAD)
        UI.Round(box, "chatBox", 3)
        scene.box = box
        -- A line is three texts in a row: before the name, the name, after it.
        scene.lines = {}
        for index = 1, 4 do
            local line = {}
            for part = 1, 3 do
                local text = box:CreateFontString(nil, "OVERLAY")
                UI.SetChatFont(text, 14)
                text:SetShadowOffset(1, -1)
                text:SetShadowColor(0, 0, 0, 1)
                text:SetWordWrap(false)
                if part == 1 then
                    text:SetPoint("TOPLEFT", box, "TOPLEFT", 10, -(CHAT_PAD + (index - 1) * CHAT_LINE))
                else
                    text:SetPoint("LEFT", line[part - 1], "RIGHT")
                end
                line[part] = text
            end
            line.outline = Outline(box)
            line.outline:SetPoint("TOPLEFT", line[2], "TOPLEFT", -3, 2)
            line.outline:SetPoint("BOTTOMRIGHT", line[2], "BOTTOMRIGHT", 3, -2)
            scene.lines[index] = line
        end
    end,

    Fill = function(scene)
        local feature = ns.features.chatAliases
        local mira, borin, lysa = ns.ChronicleService.SamplePeople()
        local aliased = feature.enabled
        local name = aliased and ns.AliasService.Format(L.ui_preview_alias, borin, feature:Get("style")) or borin
        -- { the line, with %s for the name and then the message; name; message; colour; alias? }
        local lines = {
            { L.ui_preview_chat_guild, mira, L.ui_preview_chat_1, "chatGuild" },
            { L.ui_preview_chat_guild, name, L.ui_preview_chat_2, "chatGuild", aliased },
            { L.ui_preview_chat_party, lysa, L.ui_preview_chat_3, "chatParty" },
            { L.ui_preview_chat_online, name, nil, "chatSystem", aliased },
        }
        local widest = 0
        for index, spec in ipairs(lines) do
            local line = scene.lines[index]
            local before, after = string.match(spec[1], "^(.-)%%s(.*)$")
            line[1]:SetText(before or "")
            line[2]:SetText(spec[2])
            line[3]:SetText(spec[3] and string.format(after or "", spec[3]) or after or "")
            for part = 1, 3 do
                UI.Ink(line[part], spec[4])
            end
            line.outline:SetShown(spec[5] and true or false)
            widest = math.max(widest, TextWidth(line[1]) + TextWidth(line[2]) + TextWidth(line[3]))
        end
        scene.box:SetWidth(math.min(scene.width - 40, math.ceil(widest) + 20))
    end,
}

---------------------------------------------------------------------------
-- Stage
---------------------------------------------------------------------------

function Previews.Stage(parent, width, height)
    local stage = CreateFrame("Frame", nil, parent)
    stage:SetSize(width, height)
    -- Nothing of a scene reaches beyond the picture.
    stage:SetClipsChildren(true)
    stage.width, stage.height = width, height
    stage.scenes = {}
    stage:Hide()
    return stage
end

local function Draw(stage)
    local scene = stage.current and stage.scenes[stage.current]
    if not scene then
        return
    end
    SCENES[stage.current].Fill(scene, stage.focus)
    -- From the start again, with what may be a new duration.
    if scene:IsVisible() then
        Animate(scene, false)
        Animate(scene, true)
    end
end

-- Shows the scene of that name, built the first time; hides the stage if
-- there is none.
function Previews.Show(stage, name)
    local definition = name and SCENES[name]
    for key, scene in pairs(stage.scenes) do
        if key ~= name then
            scene:Hide()
        end
    end
    stage.current, stage.focus = definition and name or nil, nil
    if not definition then
        stage:Hide()
        return false
    end
    local scene = stage.scenes[name]
    if not scene then
        scene = CreateFrame("Frame", nil, stage)
        scene:SetAllPoints(stage)
        scene.width, scene.height = stage.width, stage.height
        scene.animations = {}
        definition.Build(scene, stage.width, stage.height)
        -- What moves stops with the window, and goes on when it is back.
        scene:SetScript("OnShow", function(self)
            Animate(self, true)
        end)
        scene:SetScript("OnHide", function(self)
            Animate(self, false)
        end)
        stage.scenes[name] = scene
    end
    stage:Show()
    scene:Show()
    Draw(stage)
    return true
end

-- The option pointed at (its key), or nil; the scene may show it.
function Previews.Focus(stage, key)
    if stage.current and stage.focus ~= key then
        stage.focus = key
        Draw(stage)
    end
end

function Previews.Refresh(stage)
    Draw(stage)
end

function Previews.Has(name)
    return SCENES[name] ~= nil
end
