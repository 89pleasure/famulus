-- What is new: no window after an update. Once per account a card in the
-- live feed says that there is news (its button opens it), and until the
-- player has looked, a dot on the minimap button and on "About" in the window.
-- The news itself is a card at the top of the About page (UI/News.lua).
--
-- The texts (ui_news_<n>_t, ui_news_<n>) and their ICONS are written anew for
-- a release that brings news, and RELEASE names it; a release without news leaves them, and
-- whoever already looked sees nothing. Saved account-wide in FamulusDB.news:
-- { card = release, read = release }. A new install has seen it all (the
-- welcome page tells it), a build by hand ("dev") shows nothing by itself.

local _, ns = ...

local News = {}
ns.NewsService = News

News.RELEASE = "0.2.0"
-- One per piece of news, its icon (a name from UI.media): ui_news_1 … ui_news_<n>.
News.ICONS = { "flag", "people", "chat" }
News.COUNT = #News.ICONS
local DELAY = 8 -- seconds after login, so the card does not go under in the loading screen
local SECONDS = 12 -- the card stays as long as the feed's longest

local function Saved()
    local db = ns.global
    if type(db.news) ~= "table" then
        db.news = {}
    end
    return db.news
end

function News.Unread()
    return ns.global ~= nil and ns.version ~= "dev" and Saved().read ~= News.RELEASE
end

function News.MarkRead()
    if News.Unread() then
        Saved().read = News.RELEASE
        ns:Fire("NEWS_READ")
    end
end

-- What the card on About shows (UI.NewsCard), in the language of the moment.
function News.Model()
    local L, items = ns.L, {}
    for index, icon in ipairs(News.ICONS) do
        items[index] = { icon = icon, title = L["ui_news_" .. index .. "_t"], text = L["ui_news_" .. index] }
    end
    return { release = News.RELEASE, items = items }
end

local function NotGiven()
    return false
end

-- The card: whose (Famulus and the release), how many, and where to find them.
-- Its button opens the window on About; it is never "given", so the card stays.
function News.Story()
    local L = ns.L
    return {
        kind = "news",
        texture = ns.UI.media.logoRound,
        chip = { text = "Famulus " .. News.RELEASE },
        title = ns.Plural("ui_news_card", News.COUNT):format(News.COUNT),
        detail = L.ui_news_card_detail:format(L.cat_about),
        reaction = { icon = "info", given = NotGiven, give = function()
            ns:ShowNews()
        end },
    }
end

-- Shows the card (also /fam news). False if the live feed is off.
function News.ShowCard()
    local feed = ns.features.liveFeed
    local Feed = ns.UI and ns.UI.Feed
    if not (feed and feed.enabled and Feed) then
        return false
    end
    Feed.Show(News.Story(), SECONDS)
    feed:Chime()
    return true
end

-- At login: the card once, if there is news the player has not seen.
function News.Check()
    if not News.Unread() or Saved().card == News.RELEASE then
        return
    end
    C_Timer.After(DELAY, function()
        if News.Unread() and News.ShowCard() then
            Saved().card = News.RELEASE
        end
    end)
end

-- Before login: FamulusDB.seen is still missing on a new install.
ns:On("DATABASE_READY", function()
    if not ns.global.seen then
        Saved().card, Saved().read = News.RELEASE, News.RELEASE
    end
end)
ns:On("LOGIN", News.Check)
