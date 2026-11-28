-- AliasService: the player's own names for other players.
--
-- An alias belongs to a character or to a Battle.net account and is only
-- ever shown to the player who set it; nothing is sent to anyone. The lists
-- are account-wide data, not settings: they live outside the profiles, so
-- "reset page" and switching profiles leave them alone.
--
--   FamulusDB.aliases = { [key] = { name = "Jaina Proudmoore", alias = "Anna" } }
--   FamulusDB.accountAliases = {
--       ["anna#1234"] = { tag = "Anna#1234", alias = "Anna", chars = { [key] = "Jaina Proudmoore" } },
--   }
--
-- The key of a character is its full name in lower case with every separator
-- turned into "-". The client hands out the same name in several spellings
-- ("First Last" on unit frames, "First-Last" in chat links), and a name typed
-- by hand should match whatever its capitals are.
--
-- An alias for an account covers every character known to belong to it. The
-- client only tells which character a Battle.net friend is playing right
-- now, so the characters are collected from the Battle.net friends list as
-- they are seen (ScanFriends) and kept. Only accounts with an alias are
-- stored. An alias set on a character itself wins over the account's.

local _, ns = ...

local AliasService = {}
ns.AliasService = AliasService

local IsPlainText = ns.ChatService.IsPlainText

local MAX_ALIAS_BYTES = 48

local list -- sorted copy for the window, rebuilt after a change
local count = 0 -- aliases of characters
local accountCount = 0 -- aliases of accounts
local owners = {} -- [character key] = entry of the account it belongs to

local function Store(create)
    local global = ns.global
    if not global then
        return nil
    end
    if type(global.aliases) ~= "table" then
        if not create then
            return nil
        end
        global.aliases = {}
    end
    return global.aliases
end

local function Accounts(create)
    local global = ns.global
    if not global then
        return nil
    end
    if type(global.accountAliases) ~= "table" then
        if not create then
            return nil
        end
        global.accountAliases = {}
    end
    return global.accountAliases
end

local function Trim(text)
    return (string.gsub(string.gsub(text, "^%s+", ""), "%s+$", ""))
end

local function Changed()
    list = nil
    ns:Fire("ALIASES_CHANGED")
end

-- First name and surname as one name. Without a surname, name is returned
-- as it is, so a full name can be passed in one piece as well.
function AliasService.FullName(name, surname)
    if not IsPlainText(name) then
        return nil
    end
    if IsPlainText(surname) then
        return name .. " " .. surname
    end
    return name
end

function AliasService.Key(name, surname)
    local full = AliasService.FullName(name, surname)
    if not full then
        return nil
    end
    full = string.gsub(Trim(full), "[%s%-]+", "-")
    if full == "" then
        return nil
    end
    return ns.Lower(full)
end

-- The BattleTag in text ("Name#1234"), without surrounding blanks, or nil.
-- No character name contains a "#", so the two cannot be mixed up.
function AliasService.BattleTag(text)
    if not IsPlainText(text) then
        return nil
    end
    return string.match(text, "^%s*([^#%s]+#%d+)%s*$")
end

local function AccountEntry(tag)
    tag = accountCount > 0 and AliasService.BattleTag(tag)
    return tag and Accounts()[ns.Lower(tag)] or nil
end

-- The alias set on exactly this character or BattleTag, or nil; what a
-- character inherits from its account is left out.
function AliasService.GetOwn(name, surname)
    local account = AccountEntry(name)
    if account then
        return account.alias
    end
    if count == 0 then
        return nil
    end
    local key = AliasService.Key(name, surname)
    local entry = key and Store()[key]
    return entry and entry.alias or nil
end

-- The BattleTag and alias of the account a character is known to belong to,
-- or nil.
function AliasService.Account(name, surname)
    if accountCount == 0 then
        return nil
    end
    local key = AliasService.Key(name, surname)
    local account = key and owners[key]
    if account then
        return account.tag, account.alias
    end
    return nil
end

-- The alias for a character: its own, else the one of its account. Safe to
-- call with secret values and cheap while no alias is stored.
function AliasService.Get(name, surname)
    if count == 0 and accountCount == 0 then
        return nil
    end
    local key = AliasService.Key(name, surname)
    if not key then
        return nil
    end
    local entry = count > 0 and Store()[key]
    if entry then
        return entry.alias
    end
    local account = owners[key]
    return account and account.alias or nil
end

-- Escape sequences would let an alias carry colours, textures or links into
-- chat lines and tooltips; an alias is plain text.
local function CleanAlias(alias)
    if not IsPlainText(alias) then
        return nil
    end
    alias = Trim(string.gsub(string.gsub(alias, "|", ""), "[%c]", " "))
    if #alias > MAX_ALIAS_BYTES then
        alias = string.sub(alias, 1, MAX_ALIAS_BYTES)
        -- Do not cut a UTF-8 character in half.
        alias = string.gsub(alias, "[\192-\255][\128-\191]*$", function(tail)
            local lead = string.byte(tail)
            local need = (lead >= 240 and 4) or (lead >= 224 and 3) or 2
            return #tail == need and tail or ""
        end)
    end
    return alias ~= "" and alias or nil
end

local function SetAccount(tag, alias)
    alias = CleanAlias(alias)
    local accounts = Accounts(alias ~= nil)
    local key = ns.Lower(tag)
    local entry = accounts and accounts[key]
    if alias then
        if entry and entry.alias == alias then
            return false
        end
        if entry then
            entry.alias = alias
        else
            accounts[key] = { tag = tag, alias = alias, chars = {} }
            accountCount = accountCount + 1
        end
        Changed()
        -- Whoever of this account is online right now is known at once.
        AliasService.ScanFriends()
    else
        if not entry then
            return false
        end
        for character in pairs(entry.chars) do
            owners[character] = nil
        end
        accounts[key] = nil
        accountCount = accountCount - 1
        if accountCount == 0 then
            ns.global.accountAliases = nil
        end
        Changed()
    end
    return true
end

-- Sets the alias of a character, or of a whole account if name is a
-- BattleTag; an empty or missing alias removes it. Returns true if the list
-- changed.
function AliasService.Set(name, alias)
    local tag = AliasService.BattleTag(name)
    if tag then
        return SetAccount(tag, alias)
    end
    local key = AliasService.Key(name)
    if not key then
        return false
    end
    alias = CleanAlias(alias)
    local store = Store(alias ~= nil)
    local entry = store and store[key]
    if alias then
        name = string.gsub(Trim(name), "%s+", " ")
        if entry and entry.alias == alias and entry.name == name then
            return false
        end
        if not entry then
            count = count + 1
        end
        store[key] = { name = name, alias = alias }
    else
        if not entry then
            return false
        end
        store[key] = nil
        count = count - 1
        if count == 0 then
            ns.global.aliases = nil
        end
    end
    Changed()
    return true
end

local function LinkQuietly(account, name)
    local key = AliasService.Key(name)
    if not key or owners[key] == account then
        return false
    end
    local previous = owners[key]
    if previous then
        previous.chars[key] = nil
    end
    account.chars[key] = string.gsub(Trim(name), "[%s%-]+", " ")
    owners[key] = account
    return true
end

-- Makes a character part of an account that has an alias. Returns true if
-- that was news.
function AliasService.Link(tag, name)
    local account = AccountEntry(tag)
    if not account or not LinkQuietly(account, name) then
        return false
    end
    Changed()
    return true
end

-- Number of aliases, for characters and accounts together.
function AliasService.Count()
    return count + accountCount
end

function AliasService.AccountCount()
    return accountCount
end

---------------------------------------------------------------------------
-- Battle.net friends list
---------------------------------------------------------------------------

-- Calls visit(battleTag, characterName) for every character of this game a
-- Battle.net friend is online on; one friend if index is given, else all.
-- visit may return true to stop. The list itself is read by SocialService.
local function EachFriendCharacter(index, visit)
    local project = WOW_PROJECT_ID
    ns.SocialService.EachBattleNetFriend(function(battleTag, games)
        local tag = AliasService.BattleTag(battleTag)
        if not tag then
            return false
        end
        for _, game in ipairs(games) do
            local theirs = game.wowProjectID
            if not ns.IsSecret(theirs) and (project == nil or theirs == project)
                and IsPlainText(game.characterName) and visit(tag, game.characterName) == true then
                return true
            end
        end
        return false
    end, index)
end

-- Reads the Battle.net friends list and remembers the characters of every
-- account that has an alias. index: only this friend.
function AliasService.ScanFriends(index)
    if accountCount == 0 then
        return
    end
    local news = false
    EachFriendCharacter(index, function(tag, character)
        local account = AccountEntry(tag)
        if account then
            if account.tag ~= tag then
                account.tag = tag -- typed by hand; take the client's capitals
                news = true
            end
            if LinkQuietly(account, character) then
                news = true
            end
        end
    end)
    if news then
        Changed()
    end
end

-- The BattleTag of the Battle.net friend who is online on this character
-- right now, or nil. Walks the friends list: for a click, not for every
-- chat line.
function AliasService.FindBattleTag(name, surname)
    local key = AliasService.Key(name, surname)
    if not key then
        return nil
    end
    local found
    EachFriendCharacter(nil, function(tag, character)
        if AliasService.Key(character) == key then
            found = tag
            return true
        end
    end)
    return found
end

---------------------------------------------------------------------------
-- The list for the window
---------------------------------------------------------------------------

-- All aliases as an array, sorted by alias. A character's entry is
-- { name, alias }; an account's is { name = <BattleTag>, alias,
-- account = true, chars = <sorted names> }. Either name can be passed to Set
-- and GetOwn. The array is shared; callers must not change it.
function AliasService.List()
    if not list then
        list = {}
        local store = Store()
        if store then
            for _, entry in pairs(store) do
                list[#list + 1] = entry
            end
        end
        local accounts = Accounts()
        if accounts then
            for _, entry in pairs(accounts) do
                local chars = {}
                for _, character in pairs(entry.chars) do
                    chars[#chars + 1] = character
                end
                table.sort(chars)
                list[#list + 1] = { name = entry.tag, alias = entry.alias, account = true, chars = chars }
            end
        end
        table.sort(list, function(a, b)
            local left, right = ns.Lower(a.alias), ns.Lower(b.alias)
            if left ~= right then
                return left < right
            end
            return a.name < b.name
        end)
    end
    return list
end

-- How an alias is written where it replaces a name: alone, or with the
-- character's name behind it.
function AliasService.Format(alias, name, style)
    if style == "both" then
        return alias .. " (" .. name .. ")"
    end
    return alias
end

ns:On("DATABASE_READY", function()
    count, accountCount, list = 0, 0, nil
    wipe(owners)
    -- The saved file can be edited by hand; drop what is not an alias.
    local store = Store()
    if store then
        for key, entry in pairs(store) do
            if type(key) == "string" and type(entry) == "table" and type(entry.name) == "string" and type(entry.alias) == "string" then
                count = count + 1
            else
                store[key] = nil
            end
        end
        if count == 0 then
            ns.global.aliases = nil
        end
    end
    local accounts = Accounts()
    if accounts then
        for key, entry in pairs(accounts) do
            local tag = type(entry) == "table" and type(entry.alias) == "string" and AliasService.BattleTag(entry.tag)
            if type(key) == "string" and tag and ns.Lower(tag) == key then
                accountCount = accountCount + 1
                if type(entry.chars) ~= "table" then
                    entry.chars = {}
                end
                for character, name in pairs(entry.chars) do
                    if type(character) == "string" and type(name) == "string" and not owners[character] then
                        owners[character] = entry
                    else
                        entry.chars[character] = nil
                    end
                end
            else
                accounts[key] = nil
            end
        end
        if accountCount == 0 then
            ns.global.accountAliases = nil
        end
    end
end)
