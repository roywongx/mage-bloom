-- MageProbe Collector 0.2.0
-- Read-only. Never casts, never presses keys, never changes settings.
-- Goal: capture client facts that only exist in-game (auras, castIDs, CLEU, cooldowns, talents).
local ADDON = ...
MageProbeDB = MageProbeDB or {}
local DB = MageProbeDB
local VERSION = "0.2.0"

local MAX_EVENTS = 6000
local MAX_CASTS = 1500
local MAX_SNAPS = 2000

local function Safe(fn, ...)
    local ok, a, b, c, d, e, f, g, h = pcall(fn, ...)
    if ok then return a, b, c, d, e, f, g, h end
    return nil
end

local function err(msg)
    DB.errors = DB.errors or {}
    if #DB.errors < 100 then
        DB.errors[#DB.errors + 1] = tostring(msg)
    end
end

local function wall()
    return date("%Y-%m-%d %H:%M:%S")
end

local function spellInfo(id)
    local t = { id = id }
    if C_Spell and C_Spell.GetSpellInfo then
        local info = Safe(C_Spell.GetSpellInfo, id)
        if type(info) == "table" then
            t.name = info.name
            t.icon = info.iconID
            t.castTime = info.castTime
            t.minRange = info.minRange
            t.maxRange = info.maxRange
        end
    end
    if not t.name then
        local n, _, _, cast, minR, maxR = Safe(GetSpellInfo, id)
        if n then t.name, t.castTime, t.minRange, t.maxRange = n, cast, minR, maxR end
    end
    if C_Spell and C_Spell.GetSpellDescription then
        t.description = Safe(C_Spell.GetSpellDescription, id)
    end
    return t
end

local function scanAuras(unit, filter)
    local out = {}
    if not UnitExists(unit) then return out end
    for i = 1, 120 do
        local a
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            a = Safe(C_UnitAuras.GetAuraDataByIndex, unit, i, filter)
        end
        if type(a) ~= "table" then break end
        out[#out + 1] = {
            id = a.spellId, name = a.name,
            stacks = a.applications or a.charges or 0,
            duration = a.duration, expiration = a.expirationTime,
            source = a.sourceUnit, isHarmful = a.isHarmful,
        }
    end
    return out
end

local function snapshotAuras()
    DB.auras = {
        player = scanAuras("player", "HELPFUL"),
        target = scanAuras("target", "HARMFUL"),
        focus = scanAuras("focus", "HARMFUL"),
        arena1 = scanAuras("arena1", "HARMFUL"),
        arena2 = scanAuras("arena2", "HARMFUL"),
        arena3 = scanAuras("arena3", "HARMFUL"),
        at = wall(),
    }
end

local function scanTalents()
    local out = {}
    if C_Talent and C_Talent.GetTalentTabInfo then
        local n = 3
        if C_Talent.GetNumTalentTabs then n = Safe(C_Talent.GetNumTalentTabs) or 3 end
        for i = 1, n do
            local info = Safe(C_Talent.GetTalentTabInfo, i)
            if type(info) == "table" then
                out[#out + 1] = {
                    index = i, name = info.name,
                    points = info.pointsSpent or info.points or info.rank,
                    icon = info.iconTexture,
                }
            end
        end
    end
    if #out == 0 then
        for i = 1, 3 do
            local ok, name, icon, points = pcall(GetTalentTabInfo, i)
            if ok and name then out[#out + 1] = { index = i, name = name, points = points } end
        end
    end
    return out
end

local function scanSpellbook()
    local out = {}
    local sb = C_SpellBook
    if not sb then err("no C_SpellBook"); return out end
    local n = 0
    if sb.GetNumSpellBookSkillLines then n = Safe(sb.GetNumSpellBookSkillLines) or 0 end
    if n == 0 then err("no spellbook skill lines"); return out end
    for line = 1, n do
        local info = Safe(sb.GetSpellBookSkillLineInfo, line)
        if type(info) == "table" then
            local off = tonumber(info.offset or info.spellBookItemIndexOffset or 0) or 0
            local cnt = tonumber(info.numSpells or info.numSpellBookItems or 0) or 0
            for i = off + 1, off + cnt do
                local a, b = Safe(sb.GetSpellBookItemInfo, i, "spell")
                local rec = { slot = i, line = line }
                if type(a) == "table" then
                    rec.id = a.spellID or a.id
                    rec.name = a.name
                elseif type(a) == "string" then
                    rec.type = a
                    rec.id = tonumber(b)
                end
                if rec.id or rec.name then out[#out + 1] = rec end
            end
        end
    end
    return out
end

local function recordCd(id)
    if not id then return end
    local start, dur = 0, 0
    if C_Spell and C_Spell.GetSpellCooldown then
        local c = Safe(C_Spell.GetSpellCooldown, id)
        if type(c) == "table" then start, dur = c.startTime, c.duration end
    else
        start, dur = Safe(GetSpellCooldown, id)
    end
    DB.cds = DB.cds or {}
    DB.cds[tostring(id)] = { start = start, duration = dur, at = wall() }
end

local function addEvent(rec)
    DB.events = DB.events or {}
    if #DB.events >= MAX_EVENTS then return end
    rec.t = wall()
    DB.events[#DB.events + 1] = rec
end

local function addCast(rec)
    DB.casts = DB.casts or {}
    if #DB.casts >= MAX_CASTS then return end
    rec.t = wall()
    DB.casts[#DB.casts + 1] = rec
end

local function addSnap(rec)
    DB.casting = DB.casting or {}
    if #DB.casting >= MAX_SNAPS then return end
    rec.t = wall()
    DB.casting[#DB.casting + 1] = rec
end

local function dump(reason)
    DB.version = VERSION
    DB.at = wall()
    DB.build = { GetBuildInfo() }
    DB.ui = {}
    local w, h = Safe(GetPhysicalScreenSize)
    DB.ui.physical = { w = w, h = h }
    DB.ui.scale = Safe(function() return UIParent:GetScale() end)
    DB.ui.effective = Safe(function() return UIParent:GetEffectiveScale() end)
    DB.talents = scanTalents()
    DB.spellbook = scanSpellbook()
    DB.spells = DB.spells or {}
    for _, rec in ipairs(DB.spellbook) do
        if rec.id and not DB.spells[tostring(rec.id)] then
            DB.spells[tostring(rec.id)] = spellInfo(rec.id)
        end
    end
    snapshotAuras()
    DB.dumped = (DB.dumped or 0) + 1
    DB.dump_reason = reason or "manual"
    DEFAULT_CHAT_FRAME:AddMessage("|cff69ccf0MageProbe|r 已收集：" ..
        tostring(#DB.spellbook) .. " 技能 / " .. tostring(#(DB.events or {})) .. " 事件 / " ..
        tostring(#(DB.casting or {})) .. " 读条快照。输入 /reload 落盘，再运行 collect.cmd。")
end

-- ---------------- events ----------------

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("UNIT_AURA")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:RegisterEvent("PLAYER_TARGET_CHANGED")

local lastAura = 0
local dumped = false
local playerGUID = nil
local lastCastKey = nil

local INTERESTING = {
    SPELL_CAST_START = true, SPELL_CAST_SUCCESS = true, SPELL_CAST_FAILED = true,
    SPELL_AURA_APPLIED = true, SPELL_AURA_REFRESH = true, SPELL_AURA_REMOVED = true,
    SPELL_AURA_APPLIED_DOSE = true, SPELL_AURA_REMOVED_DOSE = true,
    SPELL_INTERRUPT = true, UNIT_DIED = true,
}

f:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        MageProbeDB = MageProbeDB or {}
        DB = MageProbeDB
    elseif event == "PLAYER_LOGIN" then
        playerGUID = UnitGUID("player")
        if not dumped then
            dumped = true
            C_Timer.After(4, function() dump("login") end)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        playerGUID = UnitGUID("player")
        C_Timer.After(6, snapshotAuras)
    elseif event == "UNIT_AURA" then
        if arg1 == "player" or arg1 == "target" or arg1 == "focus" or arg1 == "arena1"
            or arg1 == "arena2" or arg1 == "arena3" then
            local now = GetTime()
            if now - lastAura > 0.2 then
                lastAura = now
                snapshotAuras()
            end
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        snapshotAuras()
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        local _, sub, _, sG, sN, _, _, dG, dN, _, _, sp, spn, _, exID, exN =
            CombatLogGetCurrentEventInfo()
        if not INTERESTING[sub] then return end
        if sG ~= playerGUID and dG ~= playerGUID then return end
        addEvent({ ev = sub, id = sp, name = spn, dest = dN, destGUID = dG,
                   extra = exID, extraName = exN })
        if sub == "SPELL_CAST_SUCCESS" and sp then
            addCast({ id = sp, name = spn, target = dN })
            C_Timer.After(0.12, function() recordCd(sp) end)
        end
        if sub == "SPELL_INTERRUPT" then
            addCast({ id = sp, name = spn, target = dN, interrupted = exID, interruptedName = exN })
        end
    end
end)

-- target casting snapshots (0.2 s) + cooldown sweep
local tick = CreateFrame("Frame")
local acc = 0
tick:SetScript("OnUpdate", function(_, elapsed)
    acc = acc + elapsed
    if acc < 0.2 then return end
    acc = 0
    local guid = UnitGUID("target")
    if guid then
        local name, _, _, startMS, endMS, _, castID, notInterruptible, spellID = UnitCastingInfo("target")
        if name or spellID then
            local key = tostring(guid) .. "/" .. tostring(castID) .. "/" .. tostring(spellID)
            if key ~= lastCastKey then
                lastCastKey = key
                addSnap({ guid = guid, castID = castID, spellID = spellID,
                          name = name, remain = endMS and ((endMS / 1000) - GetTime()) or nil,
                          interruptible = not notInterruptible })
            end
        end
    end
end)

SLASH_MAGEPROBE1 = "/mp"
SlashCmdList["MAGEPROBE"] = function(msg)
    msg = tostring(msg or "")
    if msg == "" or msg == "dump" then
        dump("command")
    elseif msg == "aura" then
        snapshotAuras()
        DEFAULT_CHAT_FRAME:AddMessage("|cff69ccf0MageProbe|r 光环已采样；/reload 落盘。")
    elseif msg == "clear" then
        DB.events, DB.casts, DB.casting = {}, {}, {}
        DEFAULT_CHAT_FRAME:AddMessage("|cff69ccf0MageProbe|r 事件已清空。")
    elseif msg == "help" then
        DEFAULT_CHAT_FRAME:AddMessage("|cff69ccf0MageProbe|r /mp dump | /mp aura | /mp clear")
    end
end
