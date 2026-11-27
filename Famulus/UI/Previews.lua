-- Pictures of what a setting does, above the chosen entry of a settings tab
-- (UI/Options.lua). They are no screenshots: each is a small scene drawn
-- from the addon's own building blocks (the chronicle's book, the live
-- feed's card, the fellow travellers' tiles, the way the alias service
-- writes a name) with the samples' people. So a scene follows the switches,
-- the colour scheme and the language by itself, and a change to the addon
-- needs no new picture.
--
--   feature.preview = "feed"                  -- the entry's scene (SCENES below)
--   UI.Previews.Stage(parent, width, height)  -- the frame scenes are drawn on
--   UI.Previews.Show(stage, name)             -- false if there is no such scene
--   UI.Previews.Focus(stage, key)             -- the option pointed at, or nil
--   UI.Previews.Refresh(stage)                -- after a setting changed
--   UI.Previews.Has(name)                     -- whether there is such a scene
--
-- Scenes of the game (chat, tooltip, menu, minimap ...) stand on the
-- website's night sky; scenes of the window on its ground. A scene is built
-- the first time it is shown and kept. What moves does so by the client's
-- animations, only while the scene is visible; no Lua runs per frame.

local _, ns = ...
local UI = ns.UI
local L = ns.L

local Previews = {}
UI.Previews = Previews

local RADIUS = 8 -- the picture's corners
local PAD = 12 -- room inside the picture for what is made smaller to fit
local FAINT = 0.38 -- what is switched off
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
    -- Things that play by themselves, like the sparks, and only if wanted.
    for _, player in ipairs(scene.players) do
        player:SetPlaying(playing and player.wanted)
    end
end

local function Samples()
    return ns.ChronicleService
end

-- An entry of the samples, `minutes` ago.
local function Ago(entry, minutes)
    entry.t = time() - minutes * 60
    return entry
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

-- The window's own ground, for scenes of the window: a little darker
-- towards the bottom, with its hairline.
local function Ground(scene, width, height)
    local ground = UI.Card(scene, "window", "cardBorder", RADIUS)
    ground.fill:SetGradient("VERTICAL", "window", "sidebar", width, height)
end

-- Lays `holder` (width x height in its own units) into the scene: smaller
-- if it must, never larger, in the middle.
local function Fit(scene, holder, width, height)
    local scale = math.min(1, (scene.width - 2 * PAD) / width, (scene.height - 2 * PAD) / height)
    holder:SetScale(scale)
    holder:SetSize(width, height)
    holder:ClearAllPoints()
    holder:SetPoint("CENTER", scene, "CENTER")
    return scale
end

-- A short line on a dark pill: what the picture shows right now.
local function Caption(scene)
    local caption = CreateFrame("Frame", nil, scene)
    caption:SetHeight(22)
    caption:SetFrameLevel(scene:GetFrameLevel() + 6)
    caption.ground = UI.Round(caption, "sceneCaption", 11)
    caption.text = UI.Text(caption, 11, "textDim", "medium")
    caption.text:SetPoint("CENTER")
    caption.text:SetJustifyV("MIDDLE")
    caption.text:SetWordWrap(false)
    function caption:Set(text)
        self:SetShown(text ~= nil)
        self.text:SetText(text or "")
        self:SetWidth(math.floor(TextWidth(self.text) + 20.5))
    end
    return caption
end

-- A fine frame around a piece of text: what the setting changes.
local function Outline(parent, token)
    local outline = CreateFrame("Frame", nil, parent)
    token = token or "accent"
    local top, bottom = UI.Line(outline, token), UI.Line(outline, token)
    local left, right = UI.VLine(outline, token), UI.VLine(outline, token)
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

local function Frame(outline, from, to, x, y)
    outline:ClearAllPoints()
    outline:SetPoint("TOPLEFT", from, "TOPLEFT", -(x or 3), y or 2)
    outline:SetPoint("BOTTOMRIGHT", to or from, "BOTTOMRIGHT", x or 3, -(y or 2))
end

-- A panel of the game or the window: a ground with a hairline.
local function Panel(parent, fill, border, radius)
    local panel = CreateFrame("Frame", nil, parent)
    panel.shape = UI.Card(panel, fill, border, radius)
    return panel
end

-- A line of text in one of the game's fonts.
local function GameText(parent, object, size, token)
    local text = parent:CreateFontString(nil, "OVERLAY")
    UI.SetGameFont(text, object, size)
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    text:SetWordWrap(false)
    if token then
        UI.Ink(text, token)
    end
    return text
end

local function Centered(parent, size, token, weight)
    local text = UI.Text(parent, size, token, weight)
    text:SetJustifyH("CENTER")
    text:SetWordWrap(false)
    return text
end

-- A class's name as the client writes it, else the class itself.
local function ClassName(classFile)
    local names = LOCALIZED_CLASS_NAMES_MALE
    local name = type(names) == "table" and names[classFile]
    return type(name) == "string" and name or classFile
end

-- A line of the game's chat: up to three texts in a row (before a name, the
-- name, after it), each in its colour; one of them or all ("mark") framed.
local CHAT_LINE, CHAT_PAD = 18, 8

local function ChatBox(scene, count)
    local box = CreateFrame("Frame", nil, scene)
    box:SetPoint("BOTTOMLEFT", 20, 18)
    UI.Round(box, "chatBox", 3)
    box.lines = {}
    for index = 1, count do
        local line = {}
        for part = 1, 3 do
            local text = GameText(box, "ChatFontNormal", 14)
            text:SetShadowOffset(1, -1)
            text:SetShadowColor(0, 0, 0, 1)
            -- Top to top: an empty text in front (the online notice starts
            -- with the name) has no height, and its middle would pull the
            -- name up into the line above.
            if part == 1 then
                text:SetPoint("TOPLEFT", box, "TOPLEFT", 10, -(CHAT_PAD + (index - 1) * CHAT_LINE))
            else
                text:SetPoint("TOPLEFT", line[part - 1], "TOPRIGHT")
            end
            line[part] = text
        end
        line.outline = Outline(box)
        box.lines[index] = line
    end

    -- lines: { { { text, token }, ... , mark = <part> or "all" }, ... }
    function box:Set(lines)
        local widest = 0
        for index, line in ipairs(self.lines) do
            local spec = lines[index]
            local width = 0
            for part = 1, 3 do
                local piece = spec and spec[part]
                line[part]:SetShown(spec ~= nil)
                line[part]:SetText(piece and piece[1] or "")
                if piece then
                    UI.Ink(line[part], piece[2])
                end
                width = width + TextWidth(line[part])
            end
            local mark = spec and spec.mark
            line.outline:SetShown(mark ~= nil)
            if mark then
                Frame(line.outline, line[mark == "all" and 1 or mark], line[mark == "all" and #spec or mark])
            end
            widest = math.max(widest, width)
        end
        self:SetSize(math.min(scene.width - 40, math.ceil(widest) + 20), #lines * CHAT_LINE + 2 * CHAT_PAD)
    end
    return box
end

-- A line of chat from a channel: its template (with %s for the name and
-- then the message), the name, the message, its colour; mark: frame the name.
local function Said(template, name, message, token, mark)
    local before, after = string.match(template, "^(.-)%%s(.*)$")
    after = after or ""
    return {
        { before or "", token },
        { name, token },
        { message and string.format(after, message) or after, token },
        mark = mark and 2 or nil,
    }
end

-- A short list on a card: per row a class icon or a small picture, a name,
-- a plate and, at the right, a word; a row can be struck out.
local LIST_W, LIST_ROW = 400, 34

local function List(scene, count)
    local list = CreateFrame("Frame", nil, scene)
    list:SetWidth(LIST_W)
    UI.Card(list, "card", "cardBorder", 10)
    list.rows = {}
    for index = 1, count do
        local row = CreateFrame("Frame", nil, list)
        row:SetHeight(LIST_ROW)
        row:SetPoint("TOPLEFT", 0, -(6 + (index - 1) * LIST_ROW))
        row:SetPoint("TOPRIGHT", 0, -(6 + (index - 1) * LIST_ROW))
        if index > 1 then
            local line = UI.Line(row, "divider")
            line:SetPoint("TOPLEFT", 14, 0)
            line:SetPoint("TOPRIGHT", -14, 0)
        end
        row.class = UI.ClassIcon(row, 20)
        row.class:SetPoint("LEFT", 14, 0)
        row.glyph = UI.Icon(row, "flag", 16, "textMuted")
        row.glyph:SetPoint("LEFT", 16, 0)
        row.name = UI.Text(row, 12, "text", "medium")
        row.name:SetPoint("LEFT", 44, 0)
        row.name:SetJustifyV("MIDDLE")
        row.name:SetWordWrap(false)
        row.pill = UI.Pill(row)
        row.pill:SetPoint("LEFT", row.name, "RIGHT", 10, 0)
        row.note = UI.Text(row, 11, "textMuted")
        row.note:SetPoint("RIGHT", -14, 0)
        row.note:SetJustifyH("RIGHT")
        row.note:SetJustifyV("MIDDLE")
        row.note:SetWordWrap(false)
        row.strike = UI.Line(row, "textDim")
        row.strike:SetPoint("LEFT", row.name, "LEFT", -2, 0)
        row.strike:SetPoint("RIGHT", row.name, "RIGHT", 2, 0)
        list.rows[index] = row
    end

    -- rows: { { class or glyph, name, pill, note, out }, ... }
    function list:Set(rows)
        for index, row in ipairs(self.rows) do
            local spec = rows[index]
            row:SetShown(spec ~= nil)
            if spec then
                row.class:Hide()
                if spec.class then
                    UI.SetClass(row.class, spec.class)
                end
                row.glyph:SetShown(spec.glyph ~= nil)
                if spec.glyph then
                    row.glyph:SetTexture(UI.media[spec.glyph])
                end
                row.name:SetText(spec.name)
                row.pill:Set(spec.pill, false)
                row.note:SetText(spec.note or "")
                row.out = spec.out and true or false
                row.strike:SetShown(row.out)
                row:SetAlpha(row.out and FAINT or 1)
            end
        end
        self:SetHeight(12 + #rows * LIST_ROW)
    end
    return list
end

---------------------------------------------------------------------------
-- Chronicle
---------------------------------------------------------------------------

-- The chronicle's own book, with one chapter of samples, made smaller to
-- fit. entries(): the newest first. feature: faint while it is off.
local BOOK_W = 560

local function BookScene(feature, entries)
    return {
        Build = function(scene, width, height)
            Ground(scene, width, height)
            scene.holder = CreateFrame("Frame", nil, scene)
            scene.book = UI.Book(scene.holder, BOOK_W)
            scene.book:SetPoint("TOPLEFT")
        end,
        Fill = function(scene)
            local chapter = UI.ChronicleChapter(entries())
            -- The picture is low: the chapter without its route.
            chapter.route = nil
            Fit(scene, scene.holder, BOOK_W, scene.book:SetChapters({ chapter }))
            local on = feature == nil or ns.features[feature].enabled
            scene.holder:SetAlpha(on and 1 or FAINT)
        end,
    }
end

-- Record my journey: the player's own level-up and boss.
SCENES.book = BookScene("ownJourney", function()
    return { Ago(Samples().Sample("level", true), 12), Ago(Samples().Sample("boss", true), 70) }
end)

-- Follow my friends: friends' level-ups, with their class.
SCENES.friends = BookScene("companions", function()
    local _, borin = Samples().SamplePeople()
    local other = Ago(Samples().Sample("level"), 80)
    other.who, other.level = borin, 33
    return { Ago(Samples().Sample("level"), 15), other }
end)

-- Character name behind the alias: a friend under an alias, with or
-- without the name in brackets.
SCENES.names = BookScene(nil, function()
    local boss, death = Ago(Samples().Sample("boss"), 20), Ago(Samples().Sample("death"), 75)
    boss.sampleAlias, death.sampleAlias = L.ui_preview_alias, L.ui_preview_alias
    return { boss, death }
end)

-- Share with friends: the player and a friend, and what goes between them.
local SHARE_CREST, SHARE_Y, SHARE_X = 56, 74, 120

SCENES.share = {
    Build = function(scene, width, height)
        Ground(scene, width, height)
        scene.crests, scene.names = {}, {}
        for index, x in ipairs({ SHARE_X, width - SHARE_X }) do
            local crest = UI.Crest(scene, SHARE_CREST)
            crest:SetPoint("CENTER", scene, "TOPLEFT", x, -SHARE_Y)
            local name = Centered(scene, 12, "textDim", "medium")
            name:SetPoint("TOP", crest, "BOTTOM", 0, -8)
            scene.crests[index], scene.names[index] = crest, name
        end
        -- Two ways between them, each a row of dots, and what travels on it:
        -- the player's news out, the friend's in.
        scene.from = SHARE_X + SHARE_CREST / 2 + 14
        scene.to = width - SHARE_X - SHARE_CREST / 2 - 14
        scene.pills = {}
        for index, y in ipairs({ SHARE_Y - 14, SHARE_Y + 14 }) do
            for x = scene.from, scene.to, 8 do
                Spot(scene, "circle", "accentLine", 2, x, y, 3)
            end
            local pill = UI.Pill(scene)
            pill:SetFrameLevel(scene:GetFrameLevel() + 4)
            local group = pill:CreateAnimationGroup()
            group:SetLooping("REPEAT")
            local show = group:CreateAnimation("Alpha")
            show:SetFromAlpha(0)
            show:SetToAlpha(1)
            show:SetDuration(0.3)
            show:SetOrder(1)
            pill.move = group:CreateAnimation("Translation")
            pill.move:SetDuration(2.4)
            pill.move:SetSmoothing("IN_OUT")
            pill.move:SetOrder(2)
            local hide = group:CreateAnimation("Alpha")
            hide:SetFromAlpha(1)
            hide:SetToAlpha(0)
            hide:SetDuration(0.3)
            hide:SetOrder(3)
            pill.y = y
            scene.animations[#scene.animations + 1] = group
            scene.pills[index] = pill
        end
        scene.caption = Caption(scene)
        scene.caption:SetPoint("BOTTOM", 0, 12)
    end,

    Fill = function(scene)
        local Chronicle = Samples()
        local on = ns.features.sharing.enabled
        local me, mira = Chronicle.Character(), Chronicle.SamplePeople()
        scene.crests[1]:SetPerson(me or L.ui_preview_you, me and Chronicle.Class(me))
        scene.crests[2]:SetPerson(mira, Chronicle.SampleClass(mira))
        scene.names[1]:SetText(L.ui_preview_you)
        scene.names[2]:SetText(mira)
        for index, pill in ipairs(scene.pills) do
            pill:Set(index == 1 and L.c_p_level:format(40) or L.ui_preview_share_back, index == 1)
            local travel = scene.to - scene.from - pill:GetWidth()
            pill:ClearAllPoints()
            pill:SetPoint("LEFT", scene, "TOPLEFT", index == 1 and scene.from or scene.to - pill:GetWidth(), -pill.y)
            pill.move:SetOffset(index == 1 and travel or -travel, 0)
            pill:SetShown(on)
        end
        for _, crest in ipairs(scene.crests) do
            crest:SetAlpha(on and 1 or FAINT)
        end
        scene.caption:Set(L.ui_preview_share_who)
    end,
}

-- Live feed: its cards at the top of the screen, as the feed draws them.
-- Without a focus two friends' events and how long a card stays; pointed at
-- a kind of event, a card of that kind, faint while the kind is off; at
-- "own", one of the player's own.
local FEED_TOP, FEED_GAP = 16, 10

local function FeedStory(kind, own)
    local Chronicle = Samples()
    if kind == "reaction" then
        local mira = Chronicle.SamplePeople()
        return ns.features.liveFeed.ReactionStory(Chronicle.Sample("level", true), mira, "cheer")
    end
    local entry = Chronicle.Sample(kind, own)
    if not entry then
        return nil
    end
    local story = UI.FeedStory(entry)
    -- A friend's card brings the button to react while reactions are on,
    -- as in the feed (Modules/Chronicle/LiveFeed.lua); here it does nothing.
    local reaction = not own and Chronicle.ReactionsOn() and Chronicle.Reaction(entry)
    if reaction then
        story.reaction = {
            icon = reaction,
            given = function()
                return false
            end,
            give = function() end,
        }
    end
    return story
end

local function IsKind(feature, key)
    for _, kind in ipairs(feature.KINDS) do
        if kind == key then
            return true
        end
    end
    return false
end

-- How long the feed's cards stay, in seconds (the live feed's choice).
local function FeedSeconds()
    local feature = ns.features.liveFeed
    return feature.SECONDS[feature:Get("duration")] or feature.SECONDS.normal
end

-- "Visible for 7 seconds", in the form the number wants.
local function SecondsText()
    local seconds = FeedSeconds()
    return ns.Plural("ui_preview_feed_seconds", seconds):format(seconds)
end

-- Two of the feed's cards at the top of the night sky, and a caption.
local function FeedCards(scene, width, height)
    World(scene, width, height)
    scene.cards = {}
    for index = 1, 2 do
        local card = UI.Feed.Card(scene)
        -- A picture: its button to react catches no mouse.
        card.react:EnableMouse(false)
        -- The line along its foot that shows how long it stays runs out
        -- here again and again.
        card.barGroup:SetLooping("REPEAT")
        scene.animations[#scene.animations + 1] = card.barGroup
        scene.cards[index] = card
    end
    scene.caption = Caption(scene)
end

-- Whether the last three stay, and the caption that says so.
local function Keeping()
    local feature = ns.features.liveFeed
    return feature.enabled and feature:Get("keep") == true
end

local function KeepText()
    local seconds = FeedSeconds()
    return ns.Plural("ui_preview_feed_keep", seconds):format(seconds)
end

-- Fills the cards with up to two stories, faint if they would not come,
-- the caption below them. The older card is a slim row, as on screen; rest:
-- it rests, as one kept past its time does.
local function LayFeed(scene, stories, faint, caption, rest)
    local seconds = FeedSeconds()
    local widest, y = 0, FEED_TOP
    for index, card in ipairs(scene.cards) do
        local story = stories[index]
        card:SetShown(story ~= nil)
        if story then
            UI.Feed.Fill(card, story, index > 1)
            widest = math.max(widest, card:GetWidth())
            local resting = rest and index > 1
            card:SetAlpha(faint and FAINT or 1)
            card.body:SetAlpha(resting and UI.Feed.REST or 1)
            card.bar:SetShown(not faint and not resting)
            card.barRun:SetDuration(seconds)
        end
    end
    -- Left edges in line, as on screen; the stack in the middle.
    local left = math.floor((scene.width - widest) / 2)
    for index, card in ipairs(scene.cards) do
        if stories[index] then
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", scene, "TOPLEFT", left, -y)
            y = y + card:GetHeight() + FEED_GAP
        end
    end
    scene.caption:Set(caption)
    scene.caption:ClearAllPoints()
    scene.caption:SetPoint("TOP", scene, "TOP", 0, -(y + 2))
end

SCENES.feed = {
    Build = FeedCards,

    Fill = function(scene, focus)
        local feature = ns.features.liveFeed
        if focus and IsKind(feature, focus) then
            local on = feature.enabled and feature:Get(focus) == true
            LayFeed(scene, { FeedStory(focus) }, not on, on and L.ui_preview_feed_shown or L.ui_preview_feed_hidden)
        elseif focus == "own" then
            local on = feature.enabled and feature:Get("own") == true
            LayFeed(scene, { FeedStory("ability", true) }, not on, on and L.ui_preview_feed_own_on or L.ui_preview_feed_own_off)
        else
            -- Kept, the older card rests below the new one.
            local keep = Keeping()
            LayFeed(scene, { FeedStory("level"), FeedStory("boss") }, not feature.enabled,
                not feature.enabled and L.ui_preview_feed_off or keep and KeepText() or SecondsText(), keep)
        end
    end,
}

---------------------------------------------------------------------------
-- Fellow travellers
---------------------------------------------------------------------------

-- Remember fellow travellers: the closest companions' tiles, as in the
-- overview. Pointed at "raids": which groups count; at "friendsOnly":
-- whom it remembers.
local TILE_W, TILE_GAP = 200, 12

SCENES.fellows = {
    Build = function(scene, width, height)
        Ground(scene, width, height)
        scene.holder = CreateFrame("Frame", nil, scene)
        scene.tiles = {}
        for index = 1, 3 do
            local tile = UI.FellowTile(scene.holder)
            tile:SetWidth(TILE_W)
            tile:SetPoint("TOPLEFT", (index - 1) * (TILE_W + TILE_GAP), 0)
            scene.tiles[index] = tile
        end
        scene.list = List(scene, 4)
        scene.list:SetPoint("TOP", 0, -PAD)
    end,

    Fill = function(scene, focus)
        local feature = ns.features.rememberFellows
        local Fellows = ns.FellowService
        local listed = focus == "raids" or focus == "friendsOnly"
        scene.holder:SetShown(not listed)
        scene.list:SetShown(listed)
        if focus == "raids" then
            local on = feature:Get("raids") == true
            scene.list:Set({
                { glyph = "swords", name = L.ui_preview_zone_dungeon, pill = L.ui_preview_fellows_dungeon, note = L.ui_preview_fellows_counts },
                { glyph = "skull", name = L.ui_preview_zone_raid, pill = L.ui_preview_fellows_raid,
                    note = on and L.ui_preview_fellows_counts or L.ui_preview_fellows_not, out = not on },
                { glyph = "flag", name = L.ui_preview_zone_bg, pill = L.ui_preview_fellows_bg, note = L.ui_preview_fellows_never, out = true },
            })
        elseif focus == "friendsOnly" then
            local only = feature:Get("friendsOnly") == true
            local rows = {}
            for index, circle in ipairs({ "friend", "guild", "bnet", "random" }) do
                local person = Fellows.SamplePerson(index)
                local out = only and circle == "random"
                rows[index] = { class = person.class, name = person.name, pill = L["ui_preview_fellows_" .. circle],
                    note = out and L.ui_preview_fellows_skipped or nil, out = out }
            end
            scene.list:Set(rows)
        else
            for index, tile in ipairs(scene.tiles) do
                UI.FillFellowTile(tile, UI.FellowSample(Fellows.SamplePerson(index)), index)
            end
            Fit(scene, scene.holder, 3 * TILE_W + 2 * TILE_GAP, UI.FELLOW_TILE_H)
        end
        local alpha = feature.enabled and 1 or FAINT
        scene.holder:SetAlpha(alpha)
        scene.list:SetAlpha(alpha)
    end,
}

-- Tidy up: who goes, who stays.
SCENES.tidy = {
    Build = function(scene, width, height)
        Ground(scene, width, height)
        scene.list = List(scene, 4)
        scene.list:SetPoint("TOP", 0, -PAD)
        scene.caption = Caption(scene)
        scene.caption:SetPoint("BOTTOM", 0, 10)
    end,

    Fill = function(scene)
        local Fellows = ns.FellowService
        local rows = {}
        for _, each in ipairs({ { 1, "friend" }, { 2, "guild" }, { 4, "neither" }, { 5, "neither" } }) do
            local person = Fellows.SamplePerson(each[1])
            rows[#rows + 1] = { class = person.class, name = person.name, pill = L["ui_preview_fellows_" .. each[2]], out = each[2] == "neither" }
        end
        scene.list:Set(rows)
        scene.caption:Set(L.ui_preview_tidy)
    end,
}

-- Who is nearby: its cards on the feed's place, made by the feature itself
-- (nearbyFriends.Story): friends where the player arrives, and one who
-- came. Pointed at "guild": with or without the guild; at "cities": a card
-- in a city, faint while it would not come.
local function NearbyPerson(index, from)
    local person = ns.FellowService.SamplePerson(index)
    return { name = person.name, class = person.class, level = person.level, from = from }
end

SCENES.nearby = {
    Build = FeedCards,

    Fill = function(scene, focus)
        local feature = ns.features.nearbyFriends
        local Story = feature.Story
        local zone = Samples().Sample("zone").zone
        local on, guild = feature.enabled, feature:Get("guild") == true
        local here = { NearbyPerson(1, "friend") }
        if guild then
            here[2] = NearbyPerson(4, "guild")
        end
        if focus == "cities" then
            local cities = feature:Get("cities") == true
            LayFeed(scene, { Story({ NearbyPerson(1, "friend") }, L.ui_preview_city, true) }, not (on and cities),
                cities and L.ui_preview_nearby_cities or L.ui_preview_nearby_rest)
        elseif focus == "guild" then
            LayFeed(scene, { Story(here, zone, false) }, not on, guild and L.ui_preview_nearby_guild or L.ui_preview_nearby_friends)
        else
            local came = guild and NearbyPerson(2, "guild") or NearbyPerson(3, "battlenet")
            LayFeed(scene, { Story(here, zone, false), Story({ came }, zone, true) }, not on,
                on and SecondsText() or L.ui_preview_feed_off)
        end
    end,
}

---------------------------------------------------------------------------
-- Aliases
---------------------------------------------------------------------------

-- Aliases in chat: a few lines of chat; one friend there under their alias,
-- written as the feature writes it, also in the notice that they came
-- online. Switched off, the chat shows their name.
SCENES.chat = {
    Build = function(scene, width, height)
        World(scene, width, height)
        scene.box = ChatBox(scene, 4)
        scene.lines = scene.box.lines
    end,

    Fill = function(scene)
        local feature = ns.features.chatAliases
        local mira, borin, lysa = Samples().SamplePeople()
        local aliased = feature.enabled
        local name = aliased and ns.AliasService.Format(L.ui_preview_alias, borin, feature:Get("style")) or borin
        scene.box:Set({
            Said(L.ui_preview_chat_guild, mira, L.ui_preview_chat_1, "chatGuild"),
            Said(L.ui_preview_chat_guild, name, L.ui_preview_chat_2, "chatGuild", aliased),
            Said(L.ui_preview_chat_party, lysa, L.ui_preview_chat_3, "chatParty"),
            Said(L.ui_preview_chat_online, name, nil, "chatSystem", aliased),
        })
    end,
}

-- Alias in the tooltip: the game's tooltip of a friend, with the line the
-- feature adds below it.
SCENES.tooltip = {
    Build = function(scene, width, height)
        World(scene, width, height)
        local tip = Panel(scene, "tooltipFill", "tooltipBorder", 4)
        tip:SetPoint("TOPLEFT", 150, -36)
        tip.title = GameText(tip, "GameTooltipHeaderText", 14)
        tip.guild = GameText(tip, "GameTooltipText", 12, "tooltipGuild")
        tip.level = GameText(tip, "GameTooltipText", 12, "chatWhite")
        tip.label = GameText(tip, "GameTooltipText", 12, "tooltipLabel")
        tip.alias = GameText(tip, "GameTooltipText", 12, "chatWhite")
        tip.outline = Outline(tip)
        scene.tip = tip
    end,

    Fill = function(scene)
        local tip = scene.tip
        local aliased = ns.features.tooltipAliases.enabled
        local _, borin = Samples().SamplePeople()
        tip.title:SetText(borin)
        UI.Ink(tip.title, "gameClassWARRIOR")
        tip.guild:SetText("<" .. L.ui_preview_guild .. ">")
        tip.level:SetText(L.ui_preview_tooltip_level)
        tip.label:SetText(L.tt_alias)
        tip.alias:SetText(L.ui_preview_alias)
        local y = 9
        for _, text in ipairs({ tip.title, tip.guild, tip.level, tip.label }) do
            text:ClearAllPoints()
            text:SetPoint("TOPLEFT", tip, "TOPLEFT", 10, -y)
            y = y + (text == tip.title and 18 or 15)
        end
        tip.alias:ClearAllPoints()
        tip.alias:SetPoint("TOPRIGHT", tip, "TOPRIGHT", -10, -(y - 15))
        for _, part in ipairs({ tip.label, tip.alias, tip.outline }) do
            part:SetShown(aliased)
        end
        Frame(tip.outline, tip.label, tip.alias, 4, 3)
        local wide = math.max(TextWidth(tip.title), TextWidth(tip.guild), TextWidth(tip.level),
            aliased and TextWidth(tip.label) + 24 + TextWidth(tip.alias) or 0)
        tip:SetSize(math.ceil(wide) + 20, (aliased and y or y - 15) + 7)
    end,
}

-- Alias in the menu: the game's menu of a player, with the feature's entry.
SCENES.menu = {
    Build = function(scene, width, height)
        World(scene, width, height)
        local menu = Panel(scene, "tooltipFill", "tooltipBorder", 4)
        menu:SetPoint("TOPLEFT", 170, -22)
        menu.title = GameText(menu, "GameFontNormal", 13, "menuTitle")
        menu.entries = {}
        for index = 1, 4 do
            menu.entries[index] = GameText(menu, "GameFontHighlight", 12, "chatWhite")
        end
        menu.divider = UI.Line(menu, "guildyBorder")
        menu.outline = Outline(menu)
        scene.menu = menu
    end,

    Fill = function(scene)
        local menu = scene.menu
        local aliased = ns.features.aliasMenu.enabled
        local _, borin = Samples().SamplePeople()
        menu.title:SetText(borin)
        menu.title:ClearAllPoints()
        menu.title:SetPoint("TOPLEFT", 12, -10)
        local texts = { L.ui_preview_menu_whisper, L.ui_preview_menu_invite }
        if aliased then
            texts[#texts + 1] = L.menu_alias_set
        end
        texts[#texts + 1] = L.ui_preview_menu_cancel
        local y, wide = 32, TextWidth(menu.title)
        for index, entry in ipairs(menu.entries) do
            local text = texts[index]
            entry:SetShown(text ~= nil)
            if text then
                -- The game's own entries, a line, then the addons' ones.
                if index == 3 then
                    menu.divider:ClearAllPoints()
                    menu.divider:SetPoint("TOPLEFT", 10, -(y + 2))
                    menu.divider:SetPoint("TOPRIGHT", -10, -(y + 2))
                    y = y + 7
                end
                entry:SetText(text)
                entry:ClearAllPoints()
                entry:SetPoint("TOPLEFT", 14, -y)
                wide = math.max(wide, TextWidth(entry))
                y = y + 19
            end
        end
        menu.outline:SetShown(aliased)
        if aliased then
            Frame(menu.outline, menu.entries[3], nil, 5, 3)
        end
        menu:SetSize(math.max(150, math.ceil(wide) + 30), y + 6)
    end,
}

-- An alias for a Battle.net account: the friend in the game's friends list,
-- under the alias, with the characters it covers.
SCENES.bnet = {
    Build = function(scene, width, height)
        World(scene, width, height)
        local card = Panel(scene, "bnetFill", "bnetBorder", 6)
        card:SetSize(330, 104)
        card:SetPoint("CENTER", -40, 6)
        card.icon = UI.Icon(card, "circle", 28, "bnetBlue")
        card.icon:SetPoint("TOPLEFT", 14, -14)
        card.name = GameText(card, "GameFontNormal", 14, "bnetBlue")
        card.name:SetPoint("TOPLEFT", 52, -14)
        card.sub = GameText(card, "GameFontHighlightSmall", 11, "bnetGrey")
        card.sub:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -4)
        card.outline = Outline(card)
        card.chips = {}
        for index = 1, 3 do
            local chip = CreateFrame("Frame", nil, card)
            chip:SetHeight(20)
            UI.Round(chip, "bnetChip", 10)
            chip.text = GameText(chip, "GameFontHighlightSmall", 11, "chatWhite")
            chip.text:SetPoint("LEFT", 9, 0)
            chip.text:SetJustifyV("MIDDLE")
            card.chips[index] = chip
        end
        card.note = UI.Text(card, 11, "accent", "medium")
        card.note:SetPoint("BOTTOMLEFT", 14, 12)
        scene.card = card
    end,

    Fill = function(scene)
        local card = scene.card
        local aliased = ns.features.accountAliases.enabled
        local _, borin = Samples().SamplePeople()
        card.name:SetText(aliased and L.ui_preview_alias or L.ui_preview_bnet_account)
        card.sub:SetText(L.ui_preview_bnet_tag)
        card.outline:SetShown(aliased)
        Frame(card.outline, card.name)
        local x = 14
        for index, name in ipairs({ borin, L.ui_preview_alt1, L.ui_preview_alt2 }) do
            local chip = card.chips[index]
            chip.text:SetText(name)
            chip:SetWidth(math.floor(TextWidth(chip.text) + 18.5))
            chip:ClearAllPoints()
            chip:SetPoint("TOPLEFT", card, "TOPLEFT", x, -52)
            x = x + chip:GetWidth() + 6
        end
        card.note:SetText(aliased and L.ui_preview_bnet_note or "")
    end,
}

-- Aliases in Guildy: its list of the guild, a friend there under the alias.
SCENES.guildy = {
    Build = function(scene, width, height)
        World(scene, width, height)
        local list = Panel(scene, "guildyFill", "guildyBorder", 6)
        list:SetPoint("CENTER", -40, 0)
        list.head = GameText(list, "GameFontNormal", 12, "guildyHead")
        list.head:SetPoint("TOPLEFT", 12, -9)
        list.online = GameText(list, "GameFontHighlightSmall", 11, "bnetGrey")
        list.online:SetPoint("TOPRIGHT", -12, -10)
        local line = UI.Line(list, "guildyBorder")
        line:SetPoint("TOPLEFT", 0, -28)
        line:SetPoint("TOPRIGHT", 0, -28)
        list.rows = {}
        for index = 1, 4 do
            local y = -(34 + (index - 1) * 21)
            local row = {
                name = GameText(list, "GameFontHighlight", 12),
                level = GameText(list, "GameFontHighlight", 12, "chatWhite"),
                class = GameText(list, "GameFontHighlight", 12, "bnetGrey"),
            }
            row.name:SetPoint("TOPLEFT", 12, y)
            row.level:SetPoint("TOPRIGHT", list, "TOPRIGHT", -110, y)
            row.class:SetPoint("TOPLEFT", list, "TOPRIGHT", -96, y)
            list.rows[index] = row
        end
        list.outline = Outline(list)
        scene.list = list
    end,

    Fill = function(scene)
        local list = scene.list
        local feature = ns.features.guildyAliases
        local aliased = feature.enabled
        list.head:SetText("Guildy  ·  " .. L.ui_preview_guild)
        list.online:SetText(L.ui_preview_guildy_online:format(12))
        local wide = 0
        for index, which in ipairs({ 2, 1, 3, 4 }) do
            local person = ns.FellowService.SamplePerson(which)
            local row = list.rows[index]
            local name = person.name
            if index == 1 and aliased then
                name = ns.AliasService.Format(L.ui_preview_alias, person.name, feature:Get("style"))
            end
            row.name:SetText(name)
            UI.Ink(row.name, "gameClass" .. person.class)
            row.level:SetText(tostring(person.level))
            row.class:SetText(ClassName(person.class))
            wide = math.max(wide, TextWidth(row.name))
        end
        list.outline:SetShown(aliased)
        Frame(list.outline, list.rows[1].name)
        list:SetSize(math.max(300, math.ceil(wide) + 150), 34 + 4 * 21 + 6)
    end,
}

---------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------

local AREA_ICONS = { chronicle = "flag", fellows = "people", aliases = "tag" }
local NAV_ROW = 36

-- The master switches: the main features in the sidebar, as the window
-- shows them; a switched-off one greyed out with "OFF".
SCENES.areas = {
    Build = function(scene, width, height)
        Ground(scene, width, height)
        local panel = Panel(scene, "sidebar", "cardBorder", 10)
        panel:SetSize(250, #ns.categories * NAV_ROW + 16)
        panel:SetPoint("TOP", 0, -PAD - 4)
        panel.rows = {}
        for index, category in ipairs(ns.categories) do
            local row = CreateFrame("Frame", nil, panel)
            row:SetHeight(NAV_ROW)
            row:SetPoint("TOPLEFT", 8, -(8 + (index - 1) * NAV_ROW))
            row:SetPoint("TOPRIGHT", -8, -(8 + (index - 1) * NAV_ROW))
            row.icon = UI.Icon(row, AREA_ICONS[category] or "sparkle", 16, "textMuted")
            row.icon:SetPoint("LEFT", 12, 0)
            row.label = UI.Text(row, 13, "textDim", "medium")
            row.label:SetPoint("LEFT", 38, 0)
            row.label:SetJustifyV("MIDDLE")
            row.badge = UI.Pill(row)
            row.badge:SetPoint("RIGHT", -6, 0)
            row.category = category
            panel.rows[index] = row
        end
        scene.panel = panel
        scene.caption = Caption(scene)
        scene.caption:SetPoint("BOTTOM", 0, 10)
    end,

    Fill = function(scene)
        for _, row in ipairs(scene.panel.rows) do
            local on = ns:IsCategoryEnabled(row.category)
            row.label:SetText(L["area_" .. row.category])
            row.label:SetAlpha(on and 1 or 0.45)
            row.icon:SetAlpha(on and 1 or 0.45)
            row.badge:Set(L.ui_category_off, false)
            row.badge:SetShown(not on)
        end
        scene.caption:Set(L.ui_preview_areas)
    end,
}

-- Language: every language Famulus speaks, the one shown chosen, and the
-- window's tagline in it. The names stand in rows, as many as fit.
local PILL_H, PILL_GAP = 24, 6

SCENES.lang = {
    Build = function(scene, width, height)
        Ground(scene, width, height)
        scene.pills = {}
        for index, code in ipairs(ns:GetLocaleCodes()) do
            local pill = Panel(scene, "card", "cardBorder", PILL_H / 2)
            pill:SetHeight(PILL_H)
            pill.code = code
            pill.label = Centered(pill, 11, "textMuted", "medium")
            pill.label:SetPoint("CENTER")
            scene.pills[index] = pill
        end
        local card = Panel(scene, "card", "accentLine", 10)
        card:SetSize(300, 66)
        card.small = UI.Text(card, 11, "accent", "medium")
        card.small:SetPoint("TOPLEFT", 14, -12)
        card.tagline = UI.Text(card, 15, "text", "semibold")
        card.tagline:SetPoint("TOPLEFT", card.small, "BOTTOMLEFT", 0, -8)
        card.tagline:SetWidth(272)
        card.tagline:SetWordWrap(false)
        scene.card = card
        scene.caption = Caption(scene)
        scene.caption:SetPoint("BOTTOM", 0, 14)
    end,

    Fill = function(scene)
        local shown = ns:GetLocaleCode()
        local auto = ns:GetOption("general", "language") == "auto"
        -- Measured here, not when built: a font answers only once it is loaded.
        local rows, row = {}, { width = 0 }
        for _, pill in ipairs(scene.pills) do
            local chosen = pill.code == shown
            pill.label:SetText(ns.locales[pill.code].lang_name or pill.code)
            UI.Ink(pill.label, chosen and "accent" or "textMuted")
            pill.shape.border:SetColor(chosen and "accentLine" or "cardBorder")
            pill.width = math.floor(TextWidth(pill.label) + 20.5)
            pill:SetWidth(pill.width)
            local wider = row.width + (#row > 0 and PILL_GAP or 0) + pill.width
            if #row > 0 and wider > scene.width - 2 * PAD then
                rows[#rows + 1] = row
                row, wider = { width = 0 }, pill.width
            end
            row[#row + 1], row.width = pill, wider
        end
        rows[#rows + 1] = row
        local y = 18
        for _, each in ipairs(rows) do
            local x = math.floor((scene.width - each.width) / 2)
            for _, pill in ipairs(each) do
                pill:ClearAllPoints()
                pill:SetPoint("TOPLEFT", x, -y)
                x = x + pill.width + PILL_GAP
            end
            y = y + PILL_H + PILL_GAP
        end
        local strings = ns.locales[shown]
        local name = strings.lang_name or shown
        scene.card:ClearAllPoints()
        scene.card:SetPoint("TOP", 0, -(y + 8))
        scene.card.small:SetText(auto and (name .. "  ·  " .. L.ui_preview_lang_auto) or name)
        scene.card.tagline:SetText(strings.ui_tagline or L.ui_tagline)
        scene.caption:Set(L.ui_preview_lang_now)
    end,
}

-- Time and date format: every format on a card with an example, two to a
-- row, the one in effect in the accent (as for the language).
local FORMAT_W, FORMAT_GAP = 220, 20

local function FormatCards(scene, width, count, height, top)
    scene.cards = {}
    for index = 1, count do
        local column, row = (index - 1) % 2, math.floor((index - 1) / 2)
        local card = Panel(scene, "card", "cardBorder", 10)
        card:SetSize(FORMAT_W, height)
        card:SetPoint("TOPLEFT", width / 2 - FORMAT_W - FORMAT_GAP / 2 + column * (FORMAT_W + FORMAT_GAP), -(top + row * (height + 10)))
        card.small = UI.Text(card, 11, "textMuted", "medium")
        card.small:SetPoint("TOPLEFT", 14, -12)
        card.example = UI.Text(card, 15, "text", "semibold")
        card.example:SetPoint("TOPLEFT", card.small, "BOTTOMLEFT", 0, -7)
        card.example:SetWidth(FORMAT_W - 28)
        card.example:SetWordWrap(false)
        scene.cards[index] = card
    end
    scene.caption = Caption(scene)
    scene.caption:SetPoint("BOTTOM", 0, 14)
end

local function MarkFormat(card, chosen)
    UI.Ink(card.small, chosen and "accent" or "textMuted")
    card.shape.border:SetColor(chosen and "accentLine" or "cardBorder")
end

-- An evening of play today, from 19:05 to 21:40.
local function Evening(hour, minute)
    local today = date("*t")
    return time({ year = today.year, month = today.month, day = today.day, hour = hour, min = minute })
end

SCENES.time = {
    Build = function(scene, width, height)
        Ground(scene, width, height)
        FormatCards(scene, width, #ns.TIME_FORMATS, 74, 40)
    end,

    Fill = function(scene)
        local twelve = ns:GetOption("general", "timeFormat") == "12h"
        local from, to = Evening(19, 5), Evening(21, 40)
        for index, format in ipairs(ns.TIME_FORMATS) do
            local card = scene.cards[index]
            card.small:SetText(L["ui_preview_time_" .. format])
            card.example:SetText(L.c_ch_span:format(ns.FormatTime(from, format), ns.FormatTime(to, format)))
            MarkFormat(card, (format == "12h") == twelve)
        end
        scene.caption:Set(L.ui_preview_dates_where)
    end,
}

SCENES.date = {
    Build = function(scene, width, height)
        Ground(scene, width, height)
        FormatCards(scene, width, #ns.DATE_FORMATS, 56, 22)
    end,

    Fill = function(scene)
        local auto = ns:GetOption("general", "dateFormat") == "auto"
        local shown = ns.DatePattern()
        local year, month, day = string.match(date("%Y-%m-%d"), "^(%d+)-(%d+)-(%d+)$")
        local letters = { y = L.ui_preview_date_y, m = L.ui_preview_date_m, d = L.ui_preview_date_d }
        for index, pattern in ipairs(ns.DATE_FORMATS) do
            local card = scene.cards[index]
            local chosen = pattern == shown
            local order = string.gsub(pattern, "{(%a)}", letters)
            card.small:SetText(chosen and auto and (order .. "  ·  " .. L.ui_preview_date_auto) or order)
            card.example:SetText(ns.FormatDate(year, month, day, pattern))
            MarkFormat(card, chosen)
        end
        scene.caption:Set(L.ui_preview_dates_where)
    end,
}

-- Feedback in chat: the addon's own line among the chat, as it writes it.
SCENES.chatfam = {
    Build = function(scene, width, height)
        World(scene, width, height)
        scene.box = ChatBox(scene, 4)
        scene.lines = scene.box.lines
    end,

    Fill = function(scene)
        local mira, borin, lysa = Samples().SamplePeople()
        local lines = {
            Said(L.ui_preview_chat_guild, mira, L.ui_preview_chat_1, "chatGuild"),
            Said(L.ui_preview_chat_party, lysa, L.ui_preview_chat_3, "chatParty"),
        }
        if ns:GetOption("general", "chatOutput") then
            lines[#lines + 1] = { { "Famulus", "chatFamulus" }, { ": " .. L.msg_alias_removed:format(borin), "chatWhite" }, mark = "all" }
        end
        lines[#lines + 1] = Said(L.ui_preview_chat_guild, borin, L.ui_preview_chat_2, "chatGuild")
        scene.box:Set(lines)
    end,
}

-- Minimap button: the minimap with the addon's button where the player put
-- it, drawn as UI/MinimapButton.lua draws it.
local MAP = 124

SCENES.minimap = {
    Build = function(scene, width, height)
        World(scene, width, height)
        local cx, cy = width / 2, height / 2
        Spot(scene, "ring", "minimapRim", MAP + 14, cx, cy, 6)
        local map = CreateFrame("Frame", nil, scene)
        map:SetSize(MAP, MAP)
        map:SetPoint("CENTER", scene, "TOPLEFT", cx, -cy)
        local ground = UI.Icon(map, "circle", MAP, "minimapGround", "BACKGROUND")
        ground:SetPoint("CENTER")
        for _, spot in ipairs({ { "minimapLand", 70, -22, 14 }, { "minimapLand", 56, 26, -18 }, { "minimapWater", 48, 20, 30 } }) do
            local land = UI.Icon(map, "shadow", spot[2], spot[1], "BORDER")
            land:SetPoint("CENTER", spot[3], spot[4])
        end
        local me = UI.Icon(map, "circle", 6, "chatWhite", "ARTWORK")
        me:SetPoint("CENTER")
        -- The button: a disc in the ground of the window with the round logo.
        local button = CreateFrame("Frame", nil, scene)
        button:SetSize(28, 28)
        button:SetFrameLevel(map:GetFrameLevel() + 2)
        local rim = UI.Icon(button, "circle", 28, "sidebar", "BACKGROUND")
        rim:SetAllPoints()
        local logo = button:CreateTexture(nil, "ARTWORK")
        logo:SetTexture(UI.media.logoRound)
        logo:SetPoint("TOPLEFT", 3, -3)
        logo:SetPoint("BOTTOMRIGHT", -3, 3)
        button.halo = UI.Halo(scene, button, 56, "accentGlow", "BORDER")
        scene.map, scene.button = map, button
        scene.caption = Caption(scene)
        scene.caption:SetPoint("BOTTOM", 0, 8)
    end,

    Fill = function(scene)
        local on = ns:GetOption("general", "minimapButton") == true
        local angle = math.rad(tonumber(ns:GetOption("general", "minimapAngle")) or 215)
        local radius = MAP / 2 + 8
        scene.button:ClearAllPoints()
        scene.button:SetPoint("CENTER", scene.map, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
        scene.button:SetShown(on)
        scene.button.halo:SetShown(on)
        scene.caption:Set(not on and L.ui_preview_minimap_off or nil)
    end,
}

-- Settings for this character only: which characters share the settings.
SCENES.profile = {
    Build = function(scene, width, height)
        Ground(scene, width, height)
        scene.boxes = {}
        for index = 1, 2 do
            local box = Panel(scene, "card", "cardBorder", 10)
            box:SetSize(220, 92)
            box:SetPoint("TOPLEFT", width / 2 - 230 + (index - 1) * 240, -46)
            box.label = UI.Text(box, 11, "textMuted", "medium")
            box.label:SetPoint("TOPLEFT", 14, -12)
            box.empty = UI.Text(box, 12, "textMuted")
            box.empty:SetPoint("TOPLEFT", 14, -40)
            box.pills = { UI.Pill(box), UI.Pill(box), UI.Pill(box) }
            scene.boxes[index] = box
        end
    end,

    Fill = function(scene)
        local own = ns:GetOption("general", "charProfile") == true
        local me = UnitName and UnitName("player") or L.ui_preview_you
        local all, only = scene.boxes[1], scene.boxes[2]
        all.label:SetText(L.ui_preview_profile_all)
        only.label:SetText(L.ui_preview_profile_only:format(me))
        only.shape.border:SetColor(own and "accentLine" or "cardBorder")
        local names = { { all, own and {} or { me }, { L.ui_preview_alt1, L.ui_preview_alt2 } }, { only, own and { me } or {}, {} } }
        for _, each in ipairs(names) do
            local box, lit, rest = each[1], each[2], each[3]
            local x, count = 14, 0
            for _, pill in ipairs(box.pills) do
                pill:Hide()
            end
            for _, group in ipairs({ { lit, true }, { rest, false } }) do
                for _, name in ipairs(group[1]) do
                    count = count + 1
                    local pill = box.pills[count]
                    pill:Set(name, group[2])
                    pill:ClearAllPoints()
                    pill:SetPoint("TOPLEFT", box, "TOPLEFT", x, -38)
                    pill:Show()
                    x = x + pill:GetWidth() + 6
                end
            end
            box.empty:SetShown(count == 0)
            box.empty:SetText(L.ui_preview_profile_none)
        end
    end,
}

-- Colour scheme: each scheme as a small window, the chosen one in its accent.
local SCHEME_W, SCHEME_H, SCHEME_GAP = 66, 86, 14

SCENES.accent = {
    Build = function(scene, width, height)
        Ground(scene, width, height)
        scene.schemes = {}
        local left = (width - #UI.accents * SCHEME_W - (#UI.accents - 1) * SCHEME_GAP) / 2
        for index, id in ipairs(UI.accents) do
            local window = Panel(scene, "schemeWindow_" .. id, "cardBorder", 8)
            window:SetSize(SCHEME_W, SCHEME_H)
            window:SetPoint("TOPLEFT", left + (index - 1) * (SCHEME_W + SCHEME_GAP), -(height - SCHEME_H) / 2)
            local bar = CreateFrame("Frame", nil, window)
            bar:SetSize(SCHEME_W * 0.62, 7)
            bar:SetPoint("TOPLEFT", 9, -11)
            UI.Round(bar, "schemeAccent_" .. id, 3):SetGradient("HORIZONTAL", "schemeAccent_" .. id, "schemeAccent2_" .. id, SCHEME_W * 0.62, 7)
            for line, share in ipairs({ 0.8, 0.55 }) do
                local track = CreateFrame("Frame", nil, window)
                track:SetSize((SCHEME_W - 18) * share, 6)
                track:SetPoint("TOPLEFT", 9, -(24 + line * 11))
                UI.Round(track, "schemeTrack_" .. id, 3)
            end
            local card = CreateFrame("Frame", nil, window)
            card:SetSize(SCHEME_W - 18, 20)
            card:SetPoint("BOTTOMLEFT", 9, 9)
            UI.Round(card, "schemeCard_" .. id, 4)
            window.id = id
            scene.schemes[index] = window
        end
    end,

    Fill = function(scene)
        local chosen = ns:GetOption("general", "accent")
        for _, window in ipairs(scene.schemes) do
            window.shape.border:SetColor(window.id == chosen and "schemeAccent_" .. window.id or "cardBorder")
        end
    end,
}

-- Embers: the window's sparks, rising while they are on.
SCENES.embers = {
    Build = function(scene, width, height)
        Ground(scene, width, height)
        scene.embers = UI.Embers(scene, 24, 0, width, height, 9341)
        scene.players[#scene.players + 1] = scene.embers
        scene.caption = Caption(scene)
        scene.caption:SetPoint("CENTER")
    end,

    Fill = function(scene)
        local on = ns:GetOption("general", "embers") == true
        scene.embers.wanted = on
        if not on then
            scene.embers:SetPlaying(false)
        end
        scene.caption:Set(not on and L.ui_preview_embers_off or nil)
    end,
}

-- Window size: the window at a few sizes, the chosen one in the accent.
local SIZES = { 80, 100, 120, 140 }

SCENES.scale = {
    Build = function(scene, width, height)
        Ground(scene, width, height)
        scene.frames = {}
        for index = 1, #SIZES + 1 do
            local frame = CreateFrame("Frame", nil, scene)
            frame.fill = UI.Round(frame, "accentSoft", 6)
            frame.outline = Outline(frame, "controlBorder")
            frame.outline:SetAllPoints()
            frame.outlineOn = Outline(frame, "accent")
            frame.outlineOn:SetAllPoints()
            frame.label = UI.Text(frame, 11, "textMuted", "medium")
            frame.label:SetPoint("BOTTOMRIGHT", -6, 5)
            scene.frames[index] = frame
        end
    end,

    Fill = function(scene)
        local chosen = tonumber(ns:GetOption("general", "windowScale")) or 100
        local list = {}
        for _, percent in ipairs(SIZES) do
            list[#list + 1] = percent
        end
        local listed = false
        for _, percent in ipairs(list) do
            listed = listed or percent == chosen
        end
        if not listed then
            list[#list + 1] = chosen
        end
        table.sort(list, function(a, b)
            return a > b
        end)
        for index, frame in ipairs(scene.frames) do
            local percent = list[index]
            frame:SetShown(percent ~= nil)
            if percent then
                local wide = math.floor(1.25 * percent + 0.5)
                local on = percent == chosen
                frame:SetSize(wide, math.floor(wide / 1.6 + 0.5))
                frame:ClearAllPoints()
                frame:SetPoint("BOTTOM", scene, "BOTTOM", 0, 26)
                frame:SetFrameLevel(scene:GetFrameLevel() + 1 + index)
                frame.fill:SetShown(on)
                frame.outline:SetShown(not on)
                frame.outlineOn:SetShown(on)
                frame.label:SetText(percent .. "%")
                UI.Ink(frame.label, on and "accent" or "textMuted")
            end
        end
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
        scene.animations, scene.players = {}, {}
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
