-- Prints the self-test report that "/fam test" stored in the saved variables.
-- Run from the repository root after a /reload or logout in the game:
--
--   luajit tools/read_selftest.lua [--all] [path to the _forever_ folder]
--
-- Exit code 0 means no failed check, 1 means failures, 2 means no report.

local root = "/Applications/World of Warcraft/_forever_"
local verbose = false
for i = 1, #arg do
    if arg[i] == "--all" then
        verbose = true
    else
        root = arg[i]
    end
end

local function quote(path)
    return "'" .. path:gsub("'", "'\\''") .. "'"
end

local function lines(command)
    local list = {}
    local pipe = io.popen(command .. " 2>/dev/null")
    if pipe then
        for line in pipe:lines() do
            list[#list + 1] = line
        end
        pipe:close()
    end
    return list
end

-- Newest saved-variables file across all accounts.
local files = lines("ls -t " .. quote(root) .. "/WTF/Account/*/SavedVariables/Famulus.lua")
if #files == 0 then
    print("No saved variables found below " .. root .. "/WTF/Account.")
    print("Start the game with Famulus enabled, run /fam test, then /reload.")
    os.exit(2)
end

-- The file only assigns tables to globals; run it in an empty environment.
local env = {}
local chunk = assert(loadfile(files[1]))
setfenv(chunk, env)
chunk()

local db = env.FamulusDB
local report = type(db) == "table" and db.selfTest
if type(report) ~= "table" then
    print("No self-test report in " .. files[1] .. ".")
    print("Run /fam test in the game, then /reload.")
    os.exit(2)
end

local client = report.client or {}
print(string.format("Report from %s, Famulus %s", tostring(report.time), tostring(report.addonVersion)))
print(string.format("Client %s (build %s, %s), interface %s, locale %s", tostring(client.version), tostring(client.build), tostring(client.date), tostring(client.toc), tostring(client.locale)))
local idle = report.idle or {}
print(string.format("Running: %s of %s features, %s game events, %s KB memory", tostring(idle.activeFeatures), tostring(idle.totalFeatures), tostring(idle.events), tostring(idle.memoryKB or "?")))
local summary = report.summary or {}
print(string.format("Checks: %d ok, %d warnings, %d failed", summary.ok or 0, summary.warn or 0, summary.fail or 0))
print("")

for _, status in ipairs({ "fail", "warn", "ok" }) do
    if status ~= "ok" or verbose then
        for _, check in ipairs(report.checks or {}) do
            if check.status == status then
                print(string.format("[%-4s] %-10s %-40s %s", status, tostring(check.group), tostring(check.name), tostring(check.detail)))
            end
        end
    end
end

local log = db.devLog
if type(log) == "table" and #log > 0 then
    print("")
    print("Logged in developer mode (" .. #log .. "):")
    for _, entry in ipairs(log) do
        print(string.format("  %s  %s  %s", tostring(entry.time), tostring(entry.kind), tostring(entry.text)))
    end
end

-- Lua errors are written to the client logs by the default error handler.
local hits = lines("grep -l Famulus " .. quote(root) .. "/Logs/*.log")
if #hits > 0 then
    print("")
    print("Client logs that mention Famulus:")
    for _, file in ipairs(hits) do
        print("  " .. file)
    end
end

os.exit((summary.fail or 0) == 0 and 0 or 1)
