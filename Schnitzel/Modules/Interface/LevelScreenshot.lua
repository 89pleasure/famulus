-- Takes a screenshot on level up.

local _, ns = ...

local levelShot = ns:NewFeature({
    id = "levelScreenshot",
    category = "interface",
    default = false,
    requires = { "Screenshot" },
})

local function TakeScreenshot()
    Screenshot()
end

function levelShot:OnEnable()
    self:RegisterEvent("PLAYER_LEVEL_UP")
end

function levelShot:PLAYER_LEVEL_UP()
    -- Wait for the level-up banner to appear.
    self:After(1.5, TakeScreenshot)
end
