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

-- A round spot centred on a point of the scene, measured from its top
-- left: a disc (circle.tga) or a soft glow (shadow.tga).
local function Spot(scene, media, token, size, x, y, sublevel)
    local spot = scene:CreateTexture(nil, "BACKGROUND", nil, sublevel)
    spot:SetTexture(UI.media[media])
    spot:SetSize(size, size)
    spot:SetPoint("CENTER", scene, "TOPLEFT", x, -y)
    UI.Tint(spot, token)
    return spot
end

-- Own little generator, as for the sparks: the stars stand in the same
-- places every time.
local function Random(seed)
    local state = seed
    return function()
        state = (state * 16807) % 2147483647
        return state / 2147483647
    end
end

local STARS, STAR_SEED, TWINKLE = 46, 4111, 5
-- The moons stand beside the feed's cards, which take the middle at the top.
local MOON = { x = -62, y = 62, r = 26 } -- x from the right edge
local SMALL_MOON = { x = 58, y = 32, r = 5 } -- x from the left edge

-- The night sky of the website (website/scene.js): a sky that lightens
-- towards the horizon, stars, some of which twinkle, and Azeroth's two
-- moons, a large one lit from the top left in a wide glow and a small blue
-- one. Everything stays clear of the rounded corners, which the stage's
-- square clipping would otherwise show.
local function World(scene, width, height)
    local sky = UI.Round(scene, "skyTop", RADIUS)
    sky:SetGradient("VERTICAL", "skyTop", "skyLow", width, height)

    local random = Random(STAR_SEED)
    for _ = 1, STARS do
        -- More of them high up, as on the website.
        local x = 8 + random() * (width - 16)
        local y = 8 + random() ^ 1.5 * (height * 0.8)
        local star = Spot(scene, "circle", "star", 1 + random() * random() * 2, x, y, 1)
        UI.SetLevel(star, 0.15 + random() * 0.6)
        if random() < 0.2 then
            -- Fades almost out and back, each in its own rhythm.
            local group = star:CreateAnimationGroup()
            group:SetLooping("REPEAT")
            for order, ends in ipairs({ { 1, 0.15 }, { 0.15, 1 } }) do
                local fade = group:CreateAnimation("Alpha")
                fade:SetFromAlpha(ends[1])
                fade:SetToAlpha(ends[2])
                fade:SetDuration(TWINKLE / 2 + random() * 2)
                fade:SetSmoothing("IN_OUT")
                fade:SetOrder(order)
            end
            scene.animations[#scene.animations + 1] = group
        end
    end

    local mx, my, r = width + MOON.x, MOON.y, MOON.r
    Spot(scene, "shadow", "moonHalo", r * 6.4, mx, my, 2)
    Spot(scene, "shadow", "moonGlow", r * 3.2, mx, my, 2)
    local sx, sy, sr = SMALL_MOON.x, SMALL_MOON.y, SMALL_MOON.r
    Spot(scene, "shadow", "moonBlueHalo", sr * 5.2, sx, sy, 2)
    Spot(scene, "circle", "moonBlue", sr * 2, sx, sy, 3)
    -- The large moon: its rim, brighter towards the top left, a white core.
    Spot(scene, "circle", "moonRim", r * 2, mx, my, 4)
    Spot(scene, "shadow", "moonMid", r * 1.5, mx - r * 0.18, my - r * 0.2, 5)
    Spot(scene, "shadow", "moonCore", r * 0.9, mx - r * 0.24, my - r * 0.26, 6)
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
            -- The line along its foot that shows how long it stays runs out
            -- here again and again.
            card.barGroup:SetLooping("REPEAT")
            scene.animations[#scene.animations + 1] = card.barGroup
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
                card.barRun:SetDuration(seconds)
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
                -- Top to top: an empty text in front (the online notice
                -- starts with the name) has no height, and its middle
                -- would pull the name up into the line above.
                if part == 1 then
                    text:SetPoint("TOPLEFT", box, "TOPLEFT", 10, -(CHAT_PAD + (index - 1) * CHAT_LINE))
                else
                    text:SetPoint("TOPLEFT", line[part - 1], "TOPRIGHT")
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
