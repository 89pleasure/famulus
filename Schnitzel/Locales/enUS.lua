-- English (reference locale). Every key used anywhere must exist here.
-- Naming: cat_<category>, f_<feature>, o_<feature>_<option>, g_<general
-- option>, msg_<chat message>, ui_<window text>. "_desc" is the help text.

local _, ns = ...
local L = ns:NewLocale("enUS")

-- Categories
L.cat_general = "Settings"
L.cat_general_desc = "Settings for the addon itself, not for the game."
L.cat_vendor = "Vendors"
L.cat_vendor_desc = "Chores that happen whenever you talk to a merchant."
L.cat_quests = "Quests"
L.cat_quests_desc = "Fewer clicks when picking up and handing in quests."
L.cat_loot = "Loot & Items"
L.cat_loot_desc = "Looting and item handling without the extra confirmations."
L.cat_social = "Social"
L.cat_social_desc = "Invitations and requests from other players."
L.cat_tooltip = "Tooltips"
L.cat_tooltip_desc = "What tooltips show and where they appear."
L.cat_interface = "Interface"
L.cat_interface_desc = "Small comfort tweaks for map, chat and camera."
L.cat_about = "About"
L.cat_about_desc = "Version, commands and what is currently running."

-- General options
L.g_chatOutput = "Chat feedback"
L.g_chatOutput_desc = "Print one short line when Schnitzel did something for you, such as repairing or selling junk."
L.g_pauseModifier = "Pause key"
L.g_pauseModifier_desc = "Hold this key to skip every automation once, for example to read a quest before accepting it."
L.g_language = "Language"
L.g_language_desc = "Language of Schnitzel's texts. Changes apply at once."
L.g_minimapButton = "Minimap button"
L.g_minimapButton_desc = "Show a button on the minimap that opens this window. /sz always works."
L.g_windowScale = "Window size"
L.g_windowScale_desc = "Size of this window, independent of the game's interface scale."
L.g_charProfile = "Settings for this character only"
L.g_charProfile_desc = "Keep a separate set of settings for this character. It starts as a copy of your account-wide settings."

L.mod_SHIFT = "Shift"
L.mod_CTRL = "Ctrl"
L.mod_ALT = "Alt"
L.mod_NONE = "None"
L.lang_auto = "Game client"

-- Vendors
L.f_autoRepair = "Repair automatically"
L.f_autoRepair_desc = "Repairs all your gear when you open a merchant that can repair."
L.o_autoRepair_guildFunds = "Use guild funds first"
L.o_autoRepair_guildFunds_desc = "Pay from the guild bank when your rank allows it, otherwise from your own gold."
L.f_sellJunk = "Sell junk"
L.f_sellJunk_desc = "Sells all grey items when you open a merchant."

-- Quests
L.f_autoAccept = "Accept quests automatically"
L.f_autoAccept_desc = "Accepts quests as soon as an NPC offers them."
L.o_autoAccept_skipTrivial = "Ignore low-level quests"
L.o_autoAccept_skipTrivial_desc = "Do not accept grey quests that give no experience."
L.f_autoTurnIn = "Turn in quests automatically"
L.f_autoTurnIn_desc = "Hands in completed quests. Stops whenever you have to choose a reward, and never completes repeatable quests or quests that cost gold."

-- Loot & items
L.f_autoLoot = "Auto loot"
L.f_autoLoot_desc = "The same switch as auto loot in the game's options, right at hand."
L.f_confirmBoP = "Confirm bind-on-pickup loot"
L.f_confirmBoP_desc = "Skips the \"this item will bind to you\" question while you are not in a group."
L.f_easyDelete = "Easier item deletion"
L.f_easyDelete_desc = "Fills in the confirmation word when you destroy a valuable item. You still have to click the button."

-- Social
L.f_acceptInvites = "Accept invites from friends"
L.f_acceptInvites_desc = "Joins groups automatically when the invitation comes from a friend or a guild member."
L.f_declineDuels = "Decline duels"
L.f_declineDuels_desc = "Turns down every duel request."

-- Tooltips
L.f_tooltipIDs = "Show item and spell IDs"
L.f_tooltipIDs_desc = "Adds the numeric ID to item and spell tooltips."
L.f_tooltipCursor = "Tooltip at the cursor"
L.f_tooltipCursor_desc = "Shows tooltips next to the mouse pointer instead of the bottom right corner."

-- Interface
L.f_mapCoords = "Coordinates on the world map"
L.f_mapCoords_desc = "Shows your position and the cursor position on the world map."
L.f_chatArrowKeys = "Arrow keys in chat"
L.f_chatArrowKeys_desc = "Move the text cursor with the arrow keys without holding Alt. Up and Down bring back the messages you sent since login."
L.f_cameraZoom = "Maximum camera distance"
L.f_cameraZoom_desc = "Lets you zoom the camera out as far as the game allows."
L.f_hideErrors = "Hide combat error spam"
L.f_hideErrors_desc = "Hides red messages such as \"Not enough rage\" or \"Ability is not ready yet\". Other errors stay visible."
L.f_levelScreenshot = "Screenshot on level up"
L.f_levelScreenshot_desc = "Takes a screenshot every time you gain a level."

-- Chat messages
L.msg_welcome = "loaded. Type /sz to open the settings."
L.msg_repair = "Repaired for %s."
L.msg_repair_guild = "Repaired for %s (guild funds)."
L.msg_repair_nomoney = "Not enough gold to repair (%s needed)."
L.msg_junk_sold = "Sold %d junk items for %s."
L.msg_junk_sold_one = "Sold 1 junk item for %s."
L.msg_invite_accepted = "Accepted the invite from %s."
L.msg_duel_declined = "Declined a duel from %s."
L.msg_feature_error = "\"%s\" was switched off because of an error."
L.msg_status = "%d of %d features active, %d game events registered."
L.msg_selftest = "Self-test: %d ok, %d warnings, %d failed. /reload writes the report to disk."
L.msg_dev_on = "Developer mode on: the self-test runs after every login and blocked actions are logged."
L.msg_dev_off = "Developer mode off."

-- Tooltip and map labels
L.tt_item_id = "Item ID"
L.tt_spell_id = "Spell ID"
L.map_player = "Player"
L.map_cursor = "Cursor"

-- Window
L.ui_tagline = "Quality of Life"
L.ui_search = "Search settings"
L.ui_search_title = "Search"
L.ui_search_results = "%d matching settings"
L.ui_search_none = "No setting matches \"%s\"."
L.ui_reset_page = "Reset page"
L.ui_reset_confirm = "Really reset?"
L.ui_close = "Close"
L.ui_open_settings = "Open Schnitzel settings"
L.ui_unavailable = "Not available in this game version."
L.ui_failed = "Switched off because of an error. Use /reload to try again."
L.ui_active_count = "%d of %d active"
L.ui_category_on = "ON"
L.ui_category_off = "OFF"
L.ui_minimap_hint_click = "Click to open the settings"
L.ui_minimap_hint_drag = "Drag to move this button"

-- About page
L.about_version = "Version"
L.about_status = "Running"
L.about_status_value = "%d of %d features, %d game events"
L.about_commands = "Commands"
L.about_commands_value = "/sz  ·  /schnitzel  ·  /sz status  ·  /sz test"
L.about_idea = "Idea"
L.about_idea_value = "Everything is optional. A feature that is switched off does not listen to the game at all, so it costs nothing."
