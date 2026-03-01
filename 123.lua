-- // Wait for Game Load // --
local ALLOWED_PLACE_IDS = {
    [77747658251236]  = true,
    [123955125827131] = true,
    [99684056491472]  = true,
    [75159314259063]  = true,
    [96767841099256]  = true,
}

if not ALLOWED_PLACE_IDS[game.PlaceId] then
    game:GetService("Players").LocalPlayer:Kick("Game not Supported Loser")
end

if not game:IsLoaded() then game.Loaded:Wait() end
game:GetService("Players").LocalPlayer.Idled:Connect(function()
    local vu = game:GetService("VirtualUser")
    vu:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
    task.wait(1)
    vu:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
end)
getgenv().SecureMode = true
local RunService        = game:GetService("RunService")
local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local TweenService      = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer.Character then LocalPlayer.CharacterAdded:Wait() end

-- ─── Place ID Detection ───────────────────────────────────────────────────────
local CURRENT_PLACE_ID = game.PlaceId

local MAIN_PLACE_ID         = 77747658251236
local DOUBLE_DUNGEON_ID     = 123955125827131
local RUNE_DUNGEON_ID       = 99684056491472
local SHADOW_DUNGEON_ID     = 75159314259063
local BOSS_RUSH_ID          = 96767841099256

local DUNGEON_PLACE_IDS = {
    [DOUBLE_DUNGEON_ID] = true,
    [RUNE_DUNGEON_ID]   = true,
    [SHADOW_DUNGEON_ID] = true,
}

local IS_IN_DUNGEON = DUNGEON_PLACE_IDS[CURRENT_PLACE_ID] == true

-- ─── Core Remotes ─────────────────────────────────────────────────────────────
local HitRemote     = ReplicatedStorage:WaitForChild("CombatSystem"):WaitForChild("Remotes"):WaitForChild("RequestHit")
local AbilityRemote = ReplicatedStorage:WaitForChild("AbilitySystem"):WaitForChild("Remotes"):WaitForChild("RequestAbility")
local QuestAccept   = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("QuestAccept")
local QuestAbandon  = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("QuestAbandon")

local RemoteCache = {}
local function FireRemote(name, ...)
    if not RemoteCache[name] then
        RemoteCache[name] = ReplicatedStorage:FindFirstChild(name, true)
    end
    local r = RemoteCache[name]
    if r then
        local args = {...}
        if r:IsA("RemoteEvent") then
            r:FireServer(unpack(args))
        elseif r:IsA("RemoteFunction") then
            pcall(function() r:InvokeServer(unpack(args)) end)
        end
    end
end

-- ─── Load UI ─────────────────────────────────────────────────────────────────
local Starlight   = loadstring(game:HttpGet("https://raw.nebulasoftworks.xyz/starlight"))()
local NebulaIcons = loadstring(game:HttpGet("https://raw.nebulasoftworks.xyz/nebula-icon-library-loader"))()

-- ═══════════════════════════════════════════════════════════════════════════════
-- FRUIT POWER AUTO-DETECT via FruitPowerRemote hook
-- ═══════════════════════════════════════════════════════════════════════════════
local DetectedFruitPower = "Light"  -- fallback default

task.spawn(function()
    local ok, remote = pcall(function()
        return ReplicatedStorage:WaitForChild("RemoteEvents", 5):WaitForChild("FruitPowerRemote", 5)
    end)
    if ok and remote then
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            if method == "FireServer" and self == remote then
                local args = {...}
                if type(args[2]) == "table" and args[2].FruitPower then
                    DetectedFruitPower = args[2].FruitPower
                end
            end
            return oldNamecall(self, ...)
        end)
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- SETTINGS
-- ═══════════════════════════════════════════════════════════════════════════════
local Settings = {
    AutoLevel        = false,
    AutoFarmMob      = false,
    SelectedMob      = nil,
    AutoFarmBoss     = false,
    SelectedBoss     = nil,
    AutoFarmPity     = false,
    PityFarmBossList = {},
    PityFarmBoss     = nil,
    PityKillBoss     = nil,
    PityDifficulty   = "Normal",
    AutoSummonBoss   = false,
    SummonBossName   = "Saber Boss",
    SummonDifficulty = "Normal",
    AutoCraftGrail   = false,
    AutoCraftSlime   = false,
    AutoUnlockSlime   = false,
    AutoUnlockDungeon = false,
    AutoJoinDungeon   = false,
    SelectedDungeon   = "CidDungeon",
    -- Dungeon
    DungeonAutoFarm       = false,
    DungeonDifficulty     = "Easy",
    DungeonAutoVote       = false,
    DungeonAutoReplay     = false,
    DungeonMobPull        = false,
    DungeonAutoEquip      = false,
    DungeonSelectedWeapons = {},
    -- UNIFIED Dungeon skill system
    DungeonAutoSkill      = false,
    DungeonSelectedSkills  = {},
    DungeonSkillInterval  = 0.5,
    DungeonAutoArmament   = false,
    DungeonAutoObs        = false,
    DungeonAutoConq       = false,
    DungeonFarmPosition   = "Above",
    DungeonFarmDistance   = 6,
    -- Combat
    AutoAttack       = false,
    -- UNIFIED skill system
    AutoSkill        = false,
    SelectedSkills   = {},
    SkillInterval    = 0.5,
    -- Equip
    AutoEquip        = false,
    SelectedWeapons  = {},
    -- Stats
    AutoStats        = false,
    SelectedStats    = {"Melee"},
    SelectedStat     = "Melee",
    StatAmount       = 1,
    -- Haki
    AutoArmament     = false,
    AutoObs          = false,
    AutoConq         = false,
    -- Position
    Farm_Position    = "Above",
    Farm_Distance    = 6,
    Tween_Speed      = 50,
}

local HIT_INTERVAL = 0.01

-- ═══════════════════════════════════════════════════════════════════════════════
-- QUEST TABLE
-- ═══════════════════════════════════════════════════════════════════════════════
local QUESTS = {
    { id="QuestNPC1",  minLvl=0,    maxLvl=99,    questTitle="Thief Hunter",           npcPath={"ServiceNPCs","QuestNPC1"},  targets={"Thief1","Thief2","Thief3","Thief4","Thief5"} },
    { id="QuestNPC2",  minLvl=100,  maxLvl=249,   questTitle="Thief Boss",             npcPath={"QuestNPC2"},               targets={"ThiefBoss"} },
    { id="QuestNPC3",  minLvl=250,  maxLvl=499,   questTitle="Monkey Hunter",          npcPath={"QuestNPC3"},               targets={"Monkey1","Monkey2","Monkey3","Monkey4","Monkey5"} },
    { id="QuestNPC4",  minLvl=500,  maxLvl=749,   questTitle="Monkey Boss",            npcPath={"QuestNPC4"},               targets={"MonkeyBoss"} },
    { id="QuestNPC5",  minLvl=750,  maxLvl=999,   questTitle="Desert Bandit Hunter",   npcPath={"QuestNPC5"},               targets={"DesertBandit1","DesertBandit2","DesertBandit3","DesertBandit4","DesertBandit5"} },
    { id="QuestNPC6",  minLvl=1000, maxLvl=1499,  questTitle="Desert Bandit Boss",     npcPath={"QuestNPC6"},               targets={"DesertBoss"} },
    { id="QuestNPC7",  minLvl=1500, maxLvl=1999,  questTitle="Frost Rogue Hunter",     npcPath={"QuestNPC7"},               targets={"FrostRogue1","FrostRogue2","FrostRogue3","FrostRogue4","FrostRogue5"} },
    { id="QuestNPC8",  minLvl=2000, maxLvl=2999,  questTitle="Winter Warden Boss",     npcPath={"QuestNPC8"},               targets={"SnowBoss"} },
    { id="QuestNPC9",  minLvl=3000, maxLvl=3999,  questTitle="Sorcerer Hunter",        npcPath={"QuestNPC9"},               targets={"Sorcerer1","Sorcerer2","Sorcerer3","Sorcerer4","Sorcerer5"} },
    { id="QuestNPC10", minLvl=4000, maxLvl=5000,  questTitle="Panda Sorcerer Boss",    npcPath={"QuestNPC10"},              targets={"PandaMiniBoss"} },
    { id="QuestNPC11", minLvl=5000, maxLvl=6250,  questTitle="Hollow Hunter",          npcPath={"QuestNPC11"},              targets={"Hollow1","Hollow2","Hollow3","Hollow4","Hollow5"} },
    { id="QuestNPC12", minLvl=6250, maxLvl=7000,  questTitle="Strong Sorcerer Hunter", npcPath={"QuestNPC12"},              targets={"StrongSorcerer1","StrongSorcerer2","StrongSorcerer3","StrongSorcerer4","StrongSorcerer5"} },
    { id="QuestNPC13", minLvl=7000, maxLvl=8000,  questTitle="Curse Hunter",           npcPath={"QuestNPC13"},              targets={"Curse1","Curse2","Curse3","Curse4","Curse5"} },
    { id="QuestNPC14", minLvl=8000, maxLvl=9000,  questTitle="Slime Warrior Hunter",   npcPath={"ServiceNPCs","QuestNPC14"},targets={"Slime1","Slime2","Slime3","Slime4","Slime5"} },
    { id="QuestNPC15", minLvl=9000, maxLvl=10000, questTitle="Academy Challenge",      npcPath={"ServiceNPCs","QuestNPC15"},targets={"AcademyTeacher1","AcademyTeacher2","AcademyTeacher3","AcademyTeacher4","AcademyTeacher5"} },
}
local TITLE_TO_QUEST = {}
for _, q in ipairs(QUESTS) do TITLE_TO_QUEST[q.questTitle] = q end

local SLIME_KEY_WAYPOINTS = {
    Vector3.new(-854,  1,   -320),
    Vector3.new(-435,  25,  -1184),
    Vector3.new(63,    35,  -144),
    Vector3.new(-584,  58,   318),
    Vector3.new(1744,  9,    495),
    Vector3.new(-435,  27,  1399),
    Vector3.new(788,   68, -2309),
}

local DUNGEON_PIECE_WAYPOINTS = {
    Vector3.new(90,    10,  -136),
    Vector3.new(-396,   1,   510),
    Vector3.new(-1056,  7,  -307),
    Vector3.new(-314,  -1, -1188),
    Vector3.new(1717,  140,  -27),
    Vector3.new(-686,  100, 1335),
}

local ISLANDS = {
    "AcademyIsland","BossIsland","DesertIsland","JungleIsland",
    "SailorIsland","ShinjukuIsland","SlimeIsland","SnowIsland",
    "StarterIsland","ValentineIsland",
}

local DUNGEON_OPTIONS = {
    { label = "Cid Dungeon",    arg = "CidDungeon",    placeId = MAIN_PLACE_ID },
    { label = "Rune Dungeon",   arg = "RuneDungeon",   placeId = RUNE_DUNGEON_ID },
    { label = "Double Dungeon", arg = "DoubleDungeon", placeId = DOUBLE_DUNGEON_ID },
}
local DUNGEON_LABELS = {}
for _, d in ipairs(DUNGEON_OPTIONS) do table.insert(DUNGEON_LABELS, d.label) end

local DUNGEON_DIFFICULTIES = {"Easy","Medium","Hard","Extreme"}

-- ─── Fruit Power Keycodes ─────────────────────────────────────────────────────
local FRUIT_KEYCODES = {"Z","X","C","V","F","Q","E","R","T","G"}

-- ─── Summonable Boss Config ───────────────────────────────────────────────────
local SUMMON_DIFFICULTIES = { "Normal", "Medium", "Hard", "Extreme" }

local SUMMON_BOSS_CONFIG = {
    { id="SaberBoss",    label="Saber Boss",    npcMatch="Saber",              remoteFolder="Remotes",      remoteName="RequestSummonBoss",      buildArgs=function(id,diff) return id end },
    { id="QinShiBoss",   label="QinShi Boss",   npcMatch="QinShi",             remoteFolder="Remotes",      remoteName="RequestSummonBoss",      buildArgs=function(id,diff) return id end },
    { id="IchigoBoss",   label="Ichigo Boss",   npcMatch="Ichigo",             remoteFolder="Remotes",      remoteName="RequestSummonBoss",      buildArgs=function(id,diff) return id end },
    { id="GilgameshBoss",label="Gilgamesh Boss",npcMatch="Gilgamesh",          remoteFolder="Remotes",      remoteName="RequestSummonBoss",      buildArgs=function(id,diff) return id,diff end },
    { id="Rimuru",       label="Rimuru",         npcMatch="Rimuru",             remoteFolder="RemoteEvents", remoteName="RequestSpawnRimuru",     buildArgs=function(id,diff) return diff end },
    { id="Anos",         label="Anos",           npcMatch="AnosBoss",           remoteFolder="Remotes",      remoteName="RequestSpawnAnosBoss",   buildArgs=function(id,diff) return "Anos",diff end },
    { id="GojoV2",       label="GojoV2",         npcMatch="StrongestofTodayBoss",remoteFolder="Remotes",    remoteName="RequestSpawnStrongestBoss",buildArgs=function(id,diff) return "StrongestToday",diff end },
    { id="SukunaV2",     label="SukunaV2",       npcMatch="StrongestinHistoryBoss",remoteFolder="Remotes",  remoteName="RequestSpawnStrongestBoss",buildArgs=function(id,diff) return "StrongestHistory",diff end },
}

local SUMMON_BOSS_LABELS = {}
for _, b in ipairs(SUMMON_BOSS_CONFIG) do table.insert(SUMMON_BOSS_LABELS, b.label) end

local function GetSummonConfigByLabel(label)
    for _, cfg in ipairs(SUMMON_BOSS_CONFIG) do
        if cfg.label == label then return cfg end
    end
    return nil
end

local function SummonBossByLabel(label, difficulty)
    local cfg = GetSummonConfigByLabel(label)
    if not cfg then return false end
    local remoteParent = ReplicatedStorage:FindFirstChild(cfg.remoteFolder)
    local remote = remoteParent and remoteParent:FindFirstChild(cfg.remoteName)
    if not remote then return false end
    pcall(function()
        local args = table.pack(cfg.buildArgs(cfg.id, difficulty))
        remote:FireServer(table.unpack(args, 1, args.n))
    end)
    return true, cfg.npcMatch
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- RUNTIME STATE
-- ═══════════════════════════════════════════════════════════════════════════════
local CurrentTween       = nil
local ActiveBodyVelocity = nil
local ActiveBodyGyro     = nil
local CurrentQuest       = nil
local ForceQuestRefresh  = false
local LastHitTime        = 0
local _instantHookActive = false

local StatusLabel        = nil
local LevelLabel         = nil
local MobStatusLabel     = nil
local BossStatusLabel    = nil
local PityLabel          = nil
local DungeonStatusLabel = nil

local MobsList    = {}
local BossesList  = {}
local WeaponsList = {}
local PityBossList = {}

local BuyerNPCList   = {}
local MasteryNPCList = {}
local OtherNPCList   = {}

local ArmDebounce = false
local ObsDebounce = false
local DungArmDebounce = false
local DungObsDebounce = false

local PityFarmDropdownRef = nil
local PityKillDropdownRef = nil

-- ═══════════════════════════════════════════════════════════════════════════════
-- CHARACTER HELPER
-- ═══════════════════════════════════════════════════════════════════════════════
local function GetCharacter()
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart")
        and char:FindFirstChild("Humanoid")
        and char.Humanoid.Health > 0
    then return char end
    return nil
end

LocalPlayer.CharacterAdded:Connect(function()
    ActiveBodyVelocity = nil
    ActiveBodyGyro     = nil
    CurrentTween       = nil
end)

local VIM = game:GetService("VirtualInputManager")
local ProximityPromptService = game:GetService("ProximityPromptService")

local function FireNearbyPrompts(position, radius)
    radius = radius or 15
    for _, prompt in ipairs(ProximityPromptService:GetPrompts()) do
        local part = prompt.Parent
        if part and part:IsA("BasePart") then
            if (part.Position - position).Magnitude <= radius then
                pcall(function() fireproximityprompt(prompt) end)
            end
        end
    end
end

local function SpamCollect(position, radius, duration)
    radius   = radius   or 25
    duration = duration or 1.5
    local endTime = tick() + duration
    while tick() < endTime do
        pcall(function() FireNearbyPrompts(position, radius) end)
        pcall(function()
            VIM:SendKeyEvent(true,  Enum.KeyCode.E, false, game)
            task.wait(0.05)
            VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
        end)
        task.wait(0.1)
    end
end

ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
    if _instantHookActive then
        pcall(function() fireproximityprompt(prompt) end)
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- TWEEN / LOCK / UNLOCK
-- ═══════════════════════════════════════════════════════════════════════════════
local function TweenTo(targetCFrame)
    local char = GetCharacter()
    if not char then return 0 end
    if CurrentTween then CurrentTween:Cancel() end
    local RootPart = char.HumanoidRootPart
    local Distance = (RootPart.Position - targetCFrame.Position).Magnitude
    local Time     = Distance / Settings.Tween_Speed
    local TI = TweenInfo.new(Time, Enum.EasingStyle.Linear)
    CurrentTween = TweenService:Create(RootPart, TI, {CFrame = targetCFrame})
    CurrentTween:Play()
    local bVel = Instance.new("BodyVelocity")
    bVel.Name = "TweenFloat" bVel.MaxForce = Vector3.new(0, 100000, 0)
    bVel.Velocity = Vector3.zero bVel.Parent = RootPart
    task.spawn(function()
        while CurrentTween and CurrentTween.PlaybackState == Enum.PlaybackState.Playing do
            if not GetCharacter() then if CurrentTween then CurrentTween:Cancel() end break end
            RunService.Stepped:Wait()
        end
        if bVel and bVel.Parent then bVel:Destroy() end
    end)
    return Time
end

local function LockPosition(targetCFrame)
    local char = GetCharacter()
    if not char or not char.PrimaryPart then return end
    if not ActiveBodyVelocity or ActiveBodyVelocity.Parent ~= char.PrimaryPart then
        if ActiveBodyVelocity then ActiveBodyVelocity:Destroy() end
        ActiveBodyVelocity = Instance.new("BodyVelocity")
        ActiveBodyVelocity.Name = "AutoLevel_Hold"
        ActiveBodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        ActiveBodyVelocity.Velocity = Vector3.zero
        ActiveBodyVelocity.Parent = char.PrimaryPart
    end
    if not ActiveBodyGyro or ActiveBodyGyro.Parent ~= char.PrimaryPart then
        if ActiveBodyGyro then ActiveBodyGyro:Destroy() end
        ActiveBodyGyro = Instance.new("BodyGyro")
        ActiveBodyGyro.Name = "AutoLevel_Look"
        ActiveBodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
        ActiveBodyGyro.P = 30000 ActiveBodyGyro.D = 100
        ActiveBodyGyro.Parent = char.PrimaryPart
    end
    char.PrimaryPart.CFrame = targetCFrame
    ActiveBodyGyro.CFrame = targetCFrame
    ActiveBodyVelocity.Velocity = Vector3.zero
end

local function UnlockPosition()
    if ActiveBodyVelocity then ActiveBodyVelocity:Destroy() ActiveBodyVelocity = nil end
    if ActiveBodyGyro     then ActiveBodyGyro:Destroy()     ActiveBodyGyro     = nil end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- POSITION OFFSET
-- ═══════════════════════════════════════════════════════════════════════════════
local function GetOffsetFromPart(targetPart, posOverride, distOverride)
    local pos  = targetPart.Position
    local dist = distOverride or Settings.Farm_Distance
    local mode = posOverride  or Settings.Farm_Position
    if mode == "Above"  then return pos + Vector3.new(0,  dist, 0) end
    if mode == "Below"  then return pos + Vector3.new(0, -dist, 0) end
    if mode == "Behind" then
        local cf = targetPart.CFrame or CFrame.new(pos)
        return pos + (-cf.LookVector * dist)
    end
    return pos + Vector3.new(0, dist, 0)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- MISC HELPERS
-- ═══════════════════════════════════════════════════════════════════════════════
local function GetLevel()
    local ok, val = pcall(function() return LocalPlayer.Data.Level.Value end)
    return ok and tonumber(val) or 0
end

local function GetQuestForLevel(level)
    for i = #QUESTS, 1, -1 do
        if level >= QUESTS[i].minLvl then return QUESTS[i] end
    end
    return QUESTS[1]
end

local function GetModelCFrame(model)
    if not model then return nil end
    local hrp = model:FindFirstChild("HumanoidRootPart")
    if hrp then return hrp.CFrame end
    if model.PrimaryPart then return model.PrimaryPart.CFrame end
    local part = model:FindFirstChildWhichIsA("BasePart", true)
    if part then return part.CFrame end
    local ok, cf = pcall(function() return model:GetPivot() end)
    if ok then return cf end
    return nil
end

local function GetQuestNPCInstance(quest)
    local obj = Workspace
    for _, name in ipairs(quest.npcPath) do
        obj = obj:FindFirstChild(name)
        if not obj then return nil end
    end
    return obj
end

local function FindTarget(quest)
    local folder = Workspace:FindFirstChild("NPCs")
    if not folder then return nil end
    local char = GetCharacter()
    if not char then return nil end
    local myPos = char.HumanoidRootPart.Position
    local closest, closestDist = nil, math.huge
    for _, name in ipairs(quest.targets) do
        local npc = folder:FindFirstChild(name)
        if npc then
            local h = npc:FindFirstChildOfClass("Humanoid")
            if h and h.Health > 0 then
                local cf = GetModelCFrame(npc)
                if cf then
                    local d = (cf.Position - myPos).Magnitude
                    if d < closestDist then closest = npc closestDist = d end
                end
            end
        end
    end
    return closest
end

local function FindManualTarget(baseName)
    local folder = Workspace:FindFirstChild("NPCs")
    if not folder then return nil end
    local char = GetCharacter()
    if not char then return nil end
    local myPos = char.HumanoidRootPart.Position
    local cleanTarget = baseName:gsub("[%d%s]",""):lower()
    local closest, closestDist = nil, math.huge
    for _, npc in ipairs(folder:GetChildren()) do
        if npc:IsA("Model") then
            local h = npc:FindFirstChildOfClass("Humanoid")
            if h and h.Health > 0 then
                local cleanName = npc.Name:gsub("[%d%s]",""):lower()
                if cleanName:find(cleanTarget, 1, true) then
                    local cf = GetModelCFrame(npc)
                    if cf then
                        local d = (cf.Position - myPos).Magnitude
                        if d < closestDist then closest = npc closestDist = d end
                    end
                end
            end
        end
    end
    return closest
end

local function FindManualTargetMulti(nameList)
    local folder = Workspace:FindFirstChild("NPCs")
    if not folder then return nil end
    local char = GetCharacter()
    if not char then return nil end
    local myPos = char.HumanoidRootPart.Position
    local closest, closestDist = nil, math.huge
    for _, baseName in ipairs(nameList) do
        local cleanTarget = baseName:gsub("[%d%s]",""):lower()
        for _, npc in ipairs(folder:GetChildren()) do
            if npc:IsA("Model") then
                local h = npc:FindFirstChildOfClass("Humanoid")
                if h and h.Health > 0 then
                    local cleanName = npc.Name:gsub("[%d%s]",""):lower()
                    if cleanName:find(cleanTarget, 1, true) then
                        local cf = GetModelCFrame(npc)
                        if cf then
                            local d = (cf.Position - myPos).Magnitude
                            if d < closestDist then closest = npc closestDist = d end
                        end
                    end
                end
            end
        end
    end
    return closest
end

local function GetAllAliveTargets(nameList)
    local folder = Workspace:FindFirstChild("NPCs")
    if not folder then return {} end
    local result = {}
    if nameList and #nameList > 0 then
        for _, baseName in ipairs(nameList) do
            local cleanTarget = baseName:gsub("[%d%s]",""):lower()
            for _, npc in ipairs(folder:GetChildren()) do
                if npc:IsA("Model") then
                    local h = npc:FindFirstChildOfClass("Humanoid")
                    if h and h.Health > 0 then
                        local cleanName = npc.Name:gsub("[%d%s]",""):lower()
                        if cleanName:find(cleanTarget, 1, true) then
                            if not table.find(result, npc) then
                                table.insert(result, npc)
                            end
                        end
                    end
                end
            end
        end
    else
        for _, npc in ipairs(folder:GetChildren()) do
            if npc:IsA("Model") then
                local h = npc:FindFirstChildOfClass("Humanoid")
                if h and h.Health > 0 then
                    table.insert(result, npc)
                end
            end
        end
    end
    return result
end

local function FindAnyDungeonTarget()
    local folder = Workspace:FindFirstChild("NPCs")
    if not folder then return nil end
    local char = GetCharacter()
    if not char then return nil end
    local myPos = char.HumanoidRootPart.Position
    local closest, closestDist = nil, math.huge
    for _, npc in ipairs(folder:GetChildren()) do
        if npc:IsA("Model") then
            local h = npc:FindFirstChildOfClass("Humanoid")
            if h and h.Health > 0 then
                local cf = GetModelCFrame(npc)
                if cf then
                    local d = (cf.Position - myPos).Magnitude
                    if d < closestDist then closest = npc closestDist = d end
                end
            end
        end
    end
    return closest
end

local SUMMON_NPC_MATCH_NAMES = {}
for _, cfg in ipairs(SUMMON_BOSS_CONFIG) do
    SUMMON_NPC_MATCH_NAMES[cfg.npcMatch] = true
end

local QUEST_BOSS_NAMES = {
    "ThiefBoss","MonkeyBoss","DesertBoss","SnowBoss","PandaMiniBoss"
}

local function RebuildPityBossList()
    PityBossList = {}
    for _, name in ipairs(BossesList) do
        table.insert(PityBossList, name)
    end
    for _, label in ipairs(SUMMON_BOSS_LABELS) do
        if not table.find(PityBossList, label) then
            table.insert(PityBossList, label)
        end
    end
end

local function RefreshNPCs()
    MobsList   = {}
    BossesList = {}
    local folder = Workspace:FindFirstChild("NPCs")
    if folder then
        for _, npc in ipairs(folder:GetChildren()) do
            if npc:IsA("Model") and npc:FindFirstChildOfClass("Humanoid") then
                local base = npc.Name:gsub("%d+$",""):match("^%s*(.-)%s*$") or npc.Name
                if not table.find(MobsList, base) then table.insert(MobsList, base) end
                local isQuestBoss   = table.find(QUEST_BOSS_NAMES, base) ~= nil
                local isSummonAlias = SUMMON_NPC_MATCH_NAMES[base] == true
                if base:lower():find("boss") and not isQuestBoss and not isSummonAlias then
                    if not table.find(BossesList, base) then table.insert(BossesList, base) end
                end
            end
        end
        table.sort(MobsList)
        table.sort(BossesList)
    end
    RebuildPityBossList()
    if PityFarmDropdownRef then
        pcall(function() PityFarmDropdownRef:SetOptions(PityBossList) end)
    end
    if PityKillDropdownRef then
        pcall(function() PityKillDropdownRef:SetOptions(PityBossList) end)
    end
end

local function RefreshWeapons()
    WeaponsList = {}
    local function scan(c)
        for _, t in ipairs(c:GetChildren()) do
            if t:IsA("Tool") and not table.find(WeaponsList, t.Name) then
                table.insert(WeaponsList, t.Name)
            end
        end
    end
    if LocalPlayer.Character then scan(LocalPlayer.Character) end
    if LocalPlayer.Backpack   then scan(LocalPlayer.Backpack)  end
    table.sort(WeaponsList)
end

local function RefreshServiceNPCs()
    BuyerNPCList   = {}
    MasteryNPCList = {}
    OtherNPCList   = {}
    local folder = Workspace:FindFirstChild("ServiceNPCs")
    if not folder then return end
    for _, npc in ipairs(folder:GetChildren()) do
        local lname = npc.Name:lower()
        if lname:find("buy") or lname:find("buyer") then
            table.insert(BuyerNPCList, npc.Name)
        elseif lname:find("mastery") then
            table.insert(MasteryNPCList, npc.Name)
        elseif not lname:find("quest") then
            table.insert(OtherNPCList, npc.Name)
        end
    end
    table.sort(BuyerNPCList)
    table.sort(MasteryNPCList)
    table.sort(OtherNPCList)
end

RefreshNPCs()
RefreshWeapons()
RefreshServiceNPCs()

local function SetStatus(text)
    if StatusLabel then pcall(function() StatusLabel:Set({ Name = "Status: " .. text }) end) end
end

local function SetDungeonStatus(text)
    if DungeonStatusLabel then pcall(function() DungeonStatusLabel:Set({ Name = "Status: " .. text }) end) end
end

local function GetPityText()
    local ok, val = pcall(function()
        return LocalPlayer.PlayerGui.BossUI.MainFrame.BossHPBar.Pity.Text
    end)
    if ok and val then return val end
    local ok2, val2 = pcall(function()
        return tostring(LocalPlayer.PlayerGui.BossUI.MainFrame.BossHPBar.Pity.Value)
    end)
    if ok2 and val2 then return val2 end
    return "?"
end

local function GetPityNumber()
    local txt = GetPityText()
    local n = txt:match("%d+")
    return n and tonumber(n) or 0
end

local function IsDungeonReplayVisible()
    local ok, vis = pcall(function()
        return LocalPlayer.PlayerGui.DungeonUI.ReplayDungeonFrameVisibleOnlyWhenClearingDungeon.Visible
    end)
    return ok and vis == true
end

-- ─── Fixed: checks actual difficulty frame visibility ────────────────────────
local function IsDungeonVoteVisible()
    local ok, vis = pcall(function()
        local actions = LocalPlayer.PlayerGui.DungeonUI.ContentFrame.Actions
        return actions.EasyDifficultyFrame.Visible
            or actions.MediumDifficultyFrame.Visible
            or actions.HardDifficultyFrame.Visible
            or actions.ExtremeDifficultyFrame.Visible
    end)
    return ok and vis == true
end

-- ─── Fixed: only fires the remote, no VIM clicking ───────────────────────────
local function VoteDungeonDifficulty(diff)
    pcall(function()
        ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DungeonWaveVote"):FireServer(diff)
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- QUEST UI HELPERS
-- ═══════════════════════════════════════════════════════════════════════════════
local function IsQuestUIVisible()
    local ok, visible = pcall(function()
        return LocalPlayer.PlayerGui.QuestUI.Quest.Visible
    end)
    return ok and visible == true
end

local function GetCurrentQuestTitle()
    if not IsQuestUIVisible() then return "" end
    local ok, title = pcall(function()
        return LocalPlayer.PlayerGui.QuestUI.Quest.Quest.Holder.Content.QuestInfo.QuestTitle.QuestTitle.Text
    end)
    if ok and type(title) == "string" then return title:match("^%s*(.-)%s*$") end
    return ""
end

local function IsCorrectQuestActive(quest)
    return IsQuestUIVisible() and GetCurrentQuestTitle() == quest.questTitle
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- AUTO LEVEL LOOP
-- ═══════════════════════════════════════════════════════════════════════════════
local function AutoLevelLoop()
    CurrentQuest      = nil
    ForceQuestRefresh = true
    while Settings.AutoLevel do
        local level = GetLevel()
        if level >= 10000 then
            SetStatus("MAX LEVEL REACHED! 🎉")
            Settings.AutoLevel = false
            break
        end
        local quest = GetQuestForLevel(level)
        local needAccept = ForceQuestRefresh or not IsCorrectQuestActive(quest)
        if needAccept then
            UnlockPosition()
            ForceQuestRefresh = false
            if IsQuestUIVisible() then
                QuestAbandon:FireServer("repeatable")
                task.wait(0.4)
            end
            if not Settings.AutoLevel then break end
            SetStatus("Going to " .. quest.questTitle .. "...")
            local questNPC = GetQuestNPCInstance(quest)
            if questNPC then
                local npcCF = GetModelCFrame(questNPC)
                if npcCF then
                    local t = TweenTo(CFrame.new(npcCF.Position + Vector3.new(0, 3, 0)))
                    task.wait(t + 0.3)
                else
                    SetStatus("Cant read CFrame for " .. quest.id .. "!") task.wait(1)
                end
            else
                SetStatus("Quest NPC not found: " .. quest.id .. "!") task.wait(1)
            end
            if not Settings.AutoLevel then break end
            QuestAccept:FireServer(quest.id)
            SetStatus("Accepting " .. quest.questTitle .. "...")
            local deadline = tick() + 3
            repeat
                task.wait(0.1)
                if not Settings.AutoLevel then break end
            until IsCorrectQuestActive(quest) or tick() > deadline
            if not Settings.AutoLevel then break end
            if not IsCorrectQuestActive(quest) then
                SetStatus("Accept failed, retrying...") task.wait(0.5) continue
            end
            CurrentQuest = quest
            SetStatus("Quest active: " .. quest.questTitle .. " | Lvl " .. level)
            task.wait(0.2)
        end
        local target = FindTarget(quest)
        if target then
            local targetCF = GetModelCFrame(target)
            if targetCF then
                local targetPos = targetCF.Position
                local goalPos   = GetOffsetFromPart({ Position = targetPos, CFrame = targetCF })
                local char      = GetCharacter()
                if char then
                    if (char.HumanoidRootPart.Position - goalPos).Magnitude > 10 then
                        UnlockPosition()
                        local t = TweenTo(CFrame.new(goalPos))
                        if t > 0 then task.wait(t) end
                    end
                    if not Settings.AutoLevel then break end
                    if CurrentTween then CurrentTween:Cancel() end
                    LockPosition(CFrame.new(goalPos, targetPos))
                    local now = tick()
                    if now - LastHitTime >= HIT_INTERVAL then
                        HitRemote:FireServer()
                        LastHitTime = now
                        SetStatus("Farming " .. target.Name .. " | Lvl " .. level)
                    end
                end
            end
        else
            UnlockPosition()
            SetStatus("Waiting for spawn... | Lvl " .. level)
            task.wait(0.5)
        end
        RunService.Heartbeat:Wait()
    end
    UnlockPosition()
    if CurrentTween then CurrentTween:Cancel() end
    CurrentQuest = nil ForceQuestRefresh = false
    SetStatus("Idle")
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- MANUAL FARM LOOP
-- ═══════════════════════════════════════════════════════════════════════════════
local function ManualFarmLoop(isBoss)
    local statusLbl = isBoss and BossStatusLabel or MobStatusLabel
    while (isBoss and Settings.AutoFarmBoss) or (not isBoss and Settings.AutoFarmMob) do
        local folder = Workspace:FindFirstChild("NPCs")
        local char   = GetCharacter()
        local target = nil
        if folder and char then
            local myPos = char.HumanoidRootPart.Position
            local closestDist = math.huge
            for _, npc in ipairs(folder:GetChildren()) do
                local h = npc:FindFirstChildOfClass("Humanoid")
                if h and h.Health > 0 then
                    local cf = GetModelCFrame(npc)
                    if cf then
                        local d = (cf.Position - myPos).Magnitude
                        if d < closestDist then target = npc closestDist = d end
                    end
                end
            end
        end
        if target then
            local targetCF = GetModelCFrame(target)
            if targetCF then
                local targetPos = targetCF.Position
                local goalPos   = GetOffsetFromPart({ Position = targetPos, CFrame = targetCF })
                if char then
                    if (char.HumanoidRootPart.Position - goalPos).Magnitude > 10 then
                        UnlockPosition()
                        local t = TweenTo(CFrame.new(goalPos))
                        if t > 0 then task.wait(t) end
                    end
                    if (isBoss and not Settings.AutoFarmBoss) or (not isBoss and not Settings.AutoFarmMob) then break end
                    if CurrentTween then CurrentTween:Cancel() end
                    LockPosition(CFrame.new(goalPos, targetPos))
                    local now = tick()
                    if now - LastHitTime >= HIT_INTERVAL then
                        HitRemote:FireServer()
                        LastHitTime = now
                        if statusLbl then pcall(function() statusLbl:Set({ Name = "Status: Farming " .. target.Name }) end) end
                    end
                end
            end
        else
            UnlockPosition()
            if statusLbl then pcall(function() statusLbl:Set({ Name = "Status: Waiting for spawn..." }) end) end
            task.wait(0.5)
        end
        RunService.Heartbeat:Wait()
    end
    UnlockPosition()
    if CurrentTween then CurrentTween:Cancel() end
    if statusLbl then pcall(function() statusLbl:Set({ Name = "Status: Idle" }) end) end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- AUTO PITY FARM LOOP
-- ═══════════════════════════════════════════════════════════════════════════════
local function AutoPityLoop()
    local bossIndex        = 1
    local killSummoned     = false
    local inKillPhase      = false
    local farmSummoned     = false
    local currentFarmLabel = nil

    while Settings.AutoFarmPity do
        local bossList = Settings.PityFarmBossList
        if not bossList or #bossList == 0 then
            if PityLabel then pcall(function() PityLabel:Set({ Name = "Pity: Select a boss first" }) end) end
            task.wait(1) continue
        end

        local pity = GetPityNumber()

        if pity >= 24 and not inKillPhase then
            inKillPhase    = true
            killSummoned   = false
            farmSummoned   = false
            UnlockPosition()
        elseif pity < 24 and inKillPhase then
            inKillPhase      = false
            killSummoned     = false
            farmSummoned     = false
            currentFarmLabel = nil
            bossIndex        = 1
        end

        if PityLabel then pcall(function()
            local phase = inKillPhase and " | KILL PHASE" or (" [" .. bossIndex .. "/" .. #bossList .. "]")
            PityLabel:Set({ Name = "Pity: " .. GetPityText() .. phase })
        end) end

        if inKillPhase then
            local killLabel = Settings.PityKillBoss
            if not killLabel or killLabel == "" then
                if PityLabel then pcall(function()
                    PityLabel:Set({ Name = "Pity: " .. GetPityText() .. " | KILL PHASE — no kill boss set!" })
                end) end
                task.wait(1) RunService.Heartbeat:Wait() continue
            end

            local killCfg       = GetSummonConfigByLabel(killLabel)
            local npcSearchName = killCfg and killCfg.npcMatch or killLabel

            if killCfg and not killSummoned then
                if PityLabel then pcall(function()
                    PityLabel:Set({ Name = "Pity: " .. GetPityText() .. " | Summoning " .. killLabel .. " (" .. Settings.PityDifficulty .. ")..." })
                end) end
                local ok = SummonBossByLabel(killLabel, Settings.PityDifficulty)
                if ok then killSummoned = true task.wait(2) end
            end

            if not Settings.AutoFarmPity then break end

            local target = FindManualTarget(npcSearchName)
            if target then
                local targetCF = GetModelCFrame(target)
                if targetCF then
                    local targetPos = targetCF.Position
                    local goalPos   = GetOffsetFromPart({ Position = targetPos, CFrame = targetCF })
                    local char = GetCharacter()
                    if char then
                        if (char.HumanoidRootPart.Position - goalPos).Magnitude > 10 then
                            UnlockPosition()
                            local t = TweenTo(CFrame.new(goalPos))
                            if t > 0 then task.wait(t) end
                        end
                        if not Settings.AutoFarmPity then break end
                        if CurrentTween then CurrentTween:Cancel() end
                        LockPosition(CFrame.new(goalPos, targetPos))
                        local now = tick()
                        if now - LastHitTime >= HIT_INTERVAL then
                            HitRemote:FireServer() LastHitTime = now
                        end
                    end
                end
            else
                UnlockPosition()
                if PityLabel then pcall(function()
                    PityLabel:Set({ Name = "Pity: " .. GetPityText() .. " | Waiting for " .. killLabel .. "..." })
                end) end
                if killCfg and killSummoned then killSummoned = false end
                task.wait(0.5)
            end

            RunService.Heartbeat:Wait()
            continue
        end

        local killLabel = Settings.PityKillBoss or ""
        local filteredList = {}
        for _, name in ipairs(bossList) do
            if name ~= killLabel then table.insert(filteredList, name) end
        end

        if #filteredList == 0 then
            if PityLabel then pcall(function()
                PityLabel:Set({ Name = "Pity: " .. GetPityText() .. " | Waiting for pity 24..." })
            end) end
            task.wait(1) RunService.Heartbeat:Wait() continue
        end

        if bossIndex > #filteredList then bossIndex = 1 end

        local targetLabel = filteredList[bossIndex]
        if currentFarmLabel ~= targetLabel then
            currentFarmLabel = targetLabel
            farmSummoned     = false
        end

        local farmCfg       = GetSummonConfigByLabel(targetLabel)
        local npcSearchName = farmCfg and farmCfg.npcMatch or targetLabel

        if farmCfg and not farmSummoned then
            if PityLabel then pcall(function()
                PityLabel:Set({ Name = "Pity: " .. GetPityText() .. " | Summoning " .. targetLabel .. "..." })
            end) end
            local ok = SummonBossByLabel(targetLabel, Settings.PityDifficulty)
            if ok then farmSummoned = true task.wait(2) end
        end

        if not Settings.AutoFarmPity then break end

        local target = FindManualTarget(npcSearchName)
        if target then
            local targetCF = GetModelCFrame(target)
            if targetCF then
                local targetPos = targetCF.Position
                local goalPos   = GetOffsetFromPart({ Position = targetPos, CFrame = targetCF })
                local char = GetCharacter()
                if char then
                    if (char.HumanoidRootPart.Position - goalPos).Magnitude > 10 then
                        UnlockPosition()
                        local t = TweenTo(CFrame.new(goalPos))
                        if t > 0 then task.wait(t) end
                    end
                    if not Settings.AutoFarmPity then break end
                    if CurrentTween then CurrentTween:Cancel() end
                    LockPosition(CFrame.new(goalPos, targetPos))
                    local now = tick()
                    if now - LastHitTime >= HIT_INTERVAL then
                        HitRemote:FireServer() LastHitTime = now
                        if PityLabel then pcall(function()
                            PityLabel:Set({ Name = "Pity: " .. GetPityText() .. " | " .. target.Name .. " [" .. bossIndex .. "/" .. #filteredList .. "]" })
                        end) end
                    end
                end
            end
        else
            UnlockPosition()
            farmSummoned = false
            if #filteredList > 1 then
                bossIndex        = (bossIndex % #filteredList) + 1
                currentFarmLabel = filteredList[bossIndex]
                if PityLabel then pcall(function()
                    PityLabel:Set({ Name = "Pity: " .. GetPityText() .. " | Boss dead → next: " .. filteredList[bossIndex] })
                end) end
            else
                if farmCfg then
                    if PityLabel then pcall(function()
                        PityLabel:Set({ Name = "Pity: " .. GetPityText() .. " | Boss dead → re-summoning..." })
                    end) end
                else
                    if PityLabel then pcall(function()
                        PityLabel:Set({ Name = "Pity: " .. GetPityText() .. " | Waiting respawn..." })
                    end) end
                    task.wait(0.5)
                end
            end
        end

        RunService.Heartbeat:Wait()
    end

    UnlockPosition()
    if CurrentTween then CurrentTween:Cancel() end
    if PityLabel then pcall(function() PityLabel:Set({ Name = "Pity: Idle" }) end) end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- AUTO SUMMON BOSS LOOP
-- ═══════════════════════════════════════════════════════════════════════════════
local function GetSummonBossConfig()
    for _, cfg in ipairs(SUMMON_BOSS_CONFIG) do
        if cfg.label == Settings.SummonBossName then return cfg end
    end
    return SUMMON_BOSS_CONFIG[1]
end

local function AutoSummonBossLoop()
    while Settings.AutoSummonBoss do
        local cfg = GetSummonBossConfig()
        local remoteParent = ReplicatedStorage:FindFirstChild(cfg.remoteFolder)
        local remote = remoteParent and remoteParent:FindFirstChild(cfg.remoteName)
        if not remote then task.wait(1) continue end
        pcall(function()
            local args = table.pack(cfg.buildArgs(cfg.id, Settings.SummonDifficulty))
            remote:FireServer(table.unpack(args, 1, args.n))
        end)
        task.wait(2)
        if not Settings.AutoSummonBoss then break end
        local waitStart = tick()
        while Settings.AutoSummonBoss do
            local target = FindManualTarget(cfg.npcMatch)
            if not target then
                if tick() - waitStart > 5 then break end
                UnlockPosition() task.wait(0.3) continue
            end
            waitStart = tick()
            local targetCF = GetModelCFrame(target)
            if targetCF then
                local targetPos = targetCF.Position
                local goalPos   = GetOffsetFromPart({ Position = targetPos, CFrame = targetCF })
                local char = GetCharacter()
                if char then
                    if (char.HumanoidRootPart.Position - goalPos).Magnitude > 10 then
                        UnlockPosition()
                        local t = TweenTo(CFrame.new(goalPos))
                        if t > 0 then task.wait(t) end
                    end
                    if not Settings.AutoSummonBoss then break end
                    if CurrentTween then CurrentTween:Cancel() end
                    LockPosition(CFrame.new(goalPos, targetPos))
                    local now = tick()
                    if now - LastHitTime >= HIT_INTERVAL then
                        HitRemote:FireServer() LastHitTime = now
                    end
                end
            end
            RunService.Heartbeat:Wait()
        end
    end
    UnlockPosition()
    if CurrentTween then CurrentTween:Cancel() end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- AUTO JOIN DUNGEON LOOP
-- ═══════════════════════════════════════════════════════════════════════════════
local function AutoJoinDungeonLoop()
    local DungeonPortalRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RequestDungeonPortal")
    while Settings.AutoJoinDungeon do
        local arg = Settings.SelectedDungeon or "CidDungeon"
        pcall(function()
            DungeonPortalRemote:FireServer(arg)
        end)
        task.wait(2)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- DUNGEON FARM LOOP — fixed Auto Vote + Auto Replay
-- ═══════════════════════════════════════════════════════════════════════════════
local function DungeonFarmLoop()
    -- Auto Vote: only fires when difficulty frames are actually visible
    task.spawn(function()
        while Settings.DungeonAutoFarm do
            if Settings.DungeonAutoVote and IsDungeonVoteVisible() then
                VoteDungeonDifficulty(Settings.DungeonDifficulty)
                SetDungeonStatus("Voted " .. Settings.DungeonDifficulty)
                task.wait(3) -- cooldown after voting to avoid spam
            else
                task.wait(1)
            end
        end
    end)

    -- Auto Replay: only fires DungeonWaveReplayVote remote when replay frame is visible
    task.spawn(function()
        local ReplayRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DungeonWaveReplayVote")
        while Settings.DungeonAutoFarm do
            if Settings.DungeonAutoReplay and IsDungeonReplayVisible() then
                pcall(function()
                    ReplayRemote:FireServer("sponsor")
                end)
                SetDungeonStatus("Replaying dungeon...")
                task.wait(3) -- cooldown after firing to avoid duplicate requests
            else
                task.wait(1)
            end
        end
    end)

    -- Main farm loop
    while Settings.DungeonAutoFarm do
        local folder = Workspace:FindFirstChild("NPCs")
        local char   = GetCharacter()
        local target = nil
        if folder and char then
            local myPos = char.HumanoidRootPart.Position
            local closestDist = math.huge
            for _, npc in ipairs(folder:GetChildren()) do
                local h = npc:FindFirstChildOfClass("Humanoid")
                if h and h.Health > 0 then
                    local cf = GetModelCFrame(npc)
                    if cf then
                        local d = (cf.Position - myPos).Magnitude
                        if d < closestDist then target = npc closestDist = d end
                    end
                end
            end
        end

        if target then
            local targetCF = GetModelCFrame(target)
            if targetCF then
                local targetPos = targetCF.Position
                local goalPos   = GetOffsetFromPart(
                    { Position = targetPos, CFrame = targetCF },
                    Settings.DungeonFarmPosition,
                    Settings.DungeonFarmDistance
                )
                if char then
                    if (char.HumanoidRootPart.Position - goalPos).Magnitude > 10 then
                        UnlockPosition()
                        local t = TweenTo(CFrame.new(goalPos))
                        if t > 0 then task.wait(t) end
                    end
                    if not Settings.DungeonAutoFarm then break end
                    if CurrentTween then CurrentTween:Cancel() end
                    LockPosition(CFrame.new(goalPos, targetPos))
                    local now = tick()
                    if now - LastHitTime >= HIT_INTERVAL then
                        HitRemote:FireServer()
                        LastHitTime = now
                        SetDungeonStatus("Farming " .. target.Name)
                    end
                end
            end
        else
            UnlockPosition()
            SetDungeonStatus("Waiting for mobs...")
            task.wait(0.5)
        end
        RunService.Heartbeat:Wait()
    end
    UnlockPosition()
    if CurrentTween then CurrentTween:Cancel() end
    SetDungeonStatus("Idle")
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- AUTO CRAFT LOOPS
-- ═══════════════════════════════════════════════════════════════════════════════
local function AutoCraftGrailLoop()
    local GrailRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RequestGrailCraft")
    while Settings.AutoCraftGrail do
        pcall(function() GrailRemote:InvokeServer("DivineGrail", 1) end)
        task.wait(0.5)
    end
end

local function AutoCraftSlimeLoop()
    local SlimeRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RequestSlimeCraft")
    while Settings.AutoCraftSlime do
        pcall(function() SlimeRemote:InvokeServer("SlimeKey", 1) end)
        task.wait(0.5)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- AUTO UNLOCK SLIME
-- ═══════════════════════════════════════════════════════════════════════════════
local function AutoUnlockSlimeLoop()
    _instantHookActive = true
    local svcFolder = Workspace:FindFirstChild("ServiceNPCs")
    local slimeNPC  = svcFolder and svcFolder:FindFirstChild("SlimeCraftNPC")
    if slimeNPC then
        local npcCF = GetModelCFrame(slimeNPC)
        if npcCF then
            local char = GetCharacter()
            if char then
                char.HumanoidRootPart.CFrame = CFrame.new(npcCF.Position + Vector3.new(0, 3, 0))
                task.wait(0.5)
            end
            if not Settings.AutoUnlockSlime then _instantHookActive = false return end
            SpamCollect(npcCF.Position, 15, 1.5)
        end
    else
        Starlight:Notification({ Title = "Unlock Slime", Content = "SlimeCraftNPC not found in ServiceNPCs.", Duration = 3 }, "SlimeNPCMiss")
        Settings.AutoUnlockSlime = false _instantHookActive = false return
    end
    if not Settings.AutoUnlockSlime then _instantHookActive = false return end
    local deadline = tick() + 8
    repeat task.wait(0.2) until GetCurrentQuestTitle() == "Slime Collection" or tick() > deadline
    if GetCurrentQuestTitle() ~= "Slime Collection" then
        Starlight:Notification({ Title = "Unlock Slime", Content = "Quest accept failed — try again.", Duration = 3 }, "SlimeQFail")
        Settings.AutoUnlockSlime = false _instantHookActive = false return
    end
    Starlight:Notification({ Title = "Unlock Slime", Content = "Quest detected! Collecting all 7 key locations...", Duration = 3 }, "SlimeStarted")
    for i, wp in ipairs(SLIME_KEY_WAYPOINTS) do
        if not Settings.AutoUnlockSlime then break end
        local char = GetCharacter()
        if char then
            char.HumanoidRootPart.CFrame = CFrame.new(wp + Vector3.new(0, 3, 0))
            task.wait(0.5)
        end
        if not Settings.AutoUnlockSlime then break end
        SpamCollect(wp, 25, 1.5)
        Starlight:Notification({ Title = "Slime Key " .. i .. " / 7", Content = "Collected ✓", Duration = 1.2 }, "SlimeKey" .. i)
    end
    _instantHookActive = false
    Settings.AutoUnlockSlime = false
    Starlight:Notification({ Title = "Unlock Slime", Content = "All 7 key locations visited! 🎉", Duration = 4 }, "SlimeQDone")
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- AUTO UNLOCK DUNGEON
-- ═══════════════════════════════════════════════════════════════════════════════
local function IsQuestHolderVisible()
    local ok, visible = pcall(function()
        return LocalPlayer.PlayerGui.QuestUI.Quest.Quest.Holder.Visible
    end)
    return ok and visible == true
end

local function GetDungeonQuestTitle()
    local ok, title = pcall(function()
        return LocalPlayer.PlayerGui.QuestUI.Quest.Quest.Holder.Content.QuestInfo.QuestTitle.QuestTitle.Text
    end)
    if ok and type(title) == "string" then return title:match("^%s*(.-)%s*$") end
    return ""
end

local function GetQuestRequirement()
    local ok, text = pcall(function()
        return LocalPlayer.PlayerGui.QuestUI.Quest.Quest.Holder.Content.QuestInfo.QuestRequirement.Text
    end)
    if ok and type(text) == "string" then
        local cur, req = text:match("(%d+)/(%d+)")
        if cur and req then return tonumber(cur), tonumber(req) end
    end
    return 0, 25
end

local function AutoUnlockDungeonLoop()
    _instantHookActive = true
    local currentTitle = GetDungeonQuestTitle()
    local skipToPhase2 = IsQuestHolderVisible() and currentTitle == "Prove Your Strength"
    local skipToPhase1 = IsQuestHolderVisible() and currentTitle == "Dungeon Discovery"

    if not skipToPhase2 then
        if not skipToPhase1 then
            Starlight:Notification({ Title = "Unlock Dungeon — Phase 1", Content = "Waiting for Dungeon Discovery quest... Accept it first!", Duration = 4 }, "DungeonWait")
            local deadline = tick() + 30
            repeat
                task.wait(0.3)
                if not Settings.AutoUnlockDungeon then _instantHookActive = false return end
                currentTitle = GetDungeonQuestTitle()
            until (IsQuestHolderVisible() and (currentTitle == "Dungeon Discovery" or currentTitle == "Prove Your Strength")) or tick() > deadline
            currentTitle = GetDungeonQuestTitle()
            if currentTitle == "Prove Your Strength" then
                skipToPhase2 = true
            elseif currentTitle ~= "Dungeon Discovery" then
                Starlight:Notification({ Title = "Unlock Dungeon", Content = "No dungeon quest detected. Accept Dungeon Discovery first.", Duration = 5 }, "DungeonNoQuest")
                Settings.AutoUnlockDungeon = false _instantHookActive = false return
            end
        end

        if not skipToPhase2 then
            Starlight:Notification({ Title = "Unlock Dungeon — Phase 1", Content = "Collecting all 6 dungeon pieces...", Duration = 3 }, "DungeonStarted")
            for i, wp in ipairs(DUNGEON_PIECE_WAYPOINTS) do
                if not Settings.AutoUnlockDungeon then break end
                local char = GetCharacter()
                if char then
                    char.HumanoidRootPart.CFrame = CFrame.new(wp + Vector3.new(0, 3, 0))
                    task.wait(0.5)
                end
                if not Settings.AutoUnlockDungeon then break end
                SpamCollect(wp, 25, 1.5)
                Starlight:Notification({ Title = "Dungeon Piece " .. i .. " / 6", Content = "Collected ✓", Duration = 1.2 }, "DungeonPiece" .. i)
            end
            if not Settings.AutoUnlockDungeon then _instantHookActive = false return end
            Starlight:Notification({ Title = "Unlock Dungeon — Phase 2", Content = "Waiting for Prove Your Strength quest...", Duration = 4 }, "DungeonPhase2Wait")
            local deadline2 = tick() + 15
            repeat
                task.wait(0.3)
                if not Settings.AutoUnlockDungeon then _instantHookActive = false return end
            until (IsQuestHolderVisible() and GetDungeonQuestTitle() == "Prove Your Strength") or tick() > deadline2
            if GetDungeonQuestTitle() ~= "Prove Your Strength" then
                Starlight:Notification({ Title = "Unlock Dungeon", Content = "Phase 2 quest didn't appear.\nAccept Prove Your Strength then re-toggle.", Duration = 5 }, "DungeonNoPhase2")
                Settings.AutoUnlockDungeon = false _instantHookActive = false return
            end
        end
    end

    if #BossesList == 0 then RefreshNPCs() end
    if #BossesList == 0 then
        Starlight:Notification({ Title = "Unlock Dungeon — Phase 2", Content = "No bosses found. Refresh NPC list first.", Duration = 5 }, "DungeonNoBoss")
        Settings.AutoUnlockDungeon = false _instantHookActive = false return
    end

    local cur, req = GetQuestRequirement()
    Starlight:Notification({ Title = "Unlock Dungeon — Phase 2", Content = "Cycling all " .. #BossesList .. " bosses\nProgress: " .. cur .. "/" .. req, Duration = 4 }, "DungeonFarmStart")

    local bossIndex = 1
    while Settings.AutoUnlockDungeon do
        cur, req = GetQuestRequirement()
        if cur >= req then break end
        local bossName = BossesList[bossIndex]
        SetStatus("Dungeon P2: " .. cur .. "/" .. req .. " | " .. bossName)
        local target = FindManualTarget(bossName)
        if target then
            local targetCF = GetModelCFrame(target)
            if targetCF then
                local targetPos = targetCF.Position
                local goalPos   = GetOffsetFromPart({ Position = targetPos, CFrame = targetCF })
                local char = GetCharacter()
                if char then
                    if (char.HumanoidRootPart.Position - goalPos).Magnitude > 10 then
                        UnlockPosition()
                        local t = TweenTo(CFrame.new(goalPos))
                        if t > 0 then task.wait(t) end
                    end
                    if not Settings.AutoUnlockDungeon then break end
                    if CurrentTween then CurrentTween:Cancel() end
                    LockPosition(CFrame.new(goalPos, targetPos))
                    local now = tick()
                    if now - LastHitTime >= HIT_INTERVAL then
                        HitRemote:FireServer()
                        LastHitTime = now
                    end
                end
            end
        else
            UnlockPosition()
            bossIndex = (bossIndex % #BossesList) + 1
            task.wait(0.2)
        end
        RunService.Heartbeat:Wait()
    end

    UnlockPosition()
    if CurrentTween then CurrentTween:Cancel() end
    _instantHookActive = false
    Settings.AutoUnlockDungeon = false
    SetStatus("Idle")
    Starlight:Notification({ Title = "Unlock Dungeon — DONE! 🎉", Content = "25 bosses killed! Dungeon portals unlocked.", Duration = 6 }, "DungeonFullDone")
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- SKILL LOOPS
-- ═══════════════════════════════════════════════════════════════════════════════
local KEY_TO_SLOT = { Z=1, X=2, C=3, V=4, F=5 }

local function AutoSkillLoop()
    local FruitRemote = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("FruitPowerRemote")
    while Settings.AutoSkill do
        local keys = Settings.SelectedSkills
        if keys and #keys > 0 then
            for _, k in ipairs(keys) do
                local slot = KEY_TO_SLOT[k]
                if slot then pcall(function() AbilityRemote:FireServer(slot) end) end
                local kc = Enum.KeyCode[k]
                if kc then
                    pcall(function()
                        FruitRemote:FireServer("UseAbility", { FruitPower = DetectedFruitPower, KeyCode = kc })
                    end)
                end
                task.wait(Settings.SkillInterval)
                if not Settings.AutoSkill then break end
            end
        else
            task.wait(0.2)
        end
    end
end

local function DungeonSkillLoop()
    local FruitRemote = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("FruitPowerRemote")
    while Settings.DungeonAutoSkill do
        local keys = Settings.SelectedSkills
        if keys and #keys > 0 then
            for _, k in ipairs(keys) do
                local slot = KEY_TO_SLOT[k]
                if slot then pcall(function() AbilityRemote:FireServer(slot) end) end
                local kc = Enum.KeyCode[k]
                if kc then
                    pcall(function()
                        FruitRemote:FireServer("UseAbility", { FruitPower = DetectedFruitPower, KeyCode = kc })
                    end)
                end
                task.wait(Settings.SkillInterval)
                if not Settings.DungeonAutoSkill then break end
            end
        else
            task.wait(0.2)
        end
    end
end

local function AutoAttackLoop()
    while Settings.AutoAttack do
        HitRemote:FireServer()
        RunService.Heartbeat:Wait()
    end
end
-- ═══════════════════════════════════════════════════════════════════════════════
-- BACKGROUND LOOPS
-- ═══════════════════════════════════════════════════════════════════════════════
task.spawn(function()
    while true do
        task.wait(1)
        pcall(function()
            if LevelLabel then LevelLabel:Set({ Name = "Level: " .. tostring(GetLevel()) }) end
        end)
        pcall(function()
            if PityLabel and not Settings.AutoFarmPity then
                PityLabel:Set({ Name = "Pity: " .. GetPityText() })
            end
        end)
    end
end)

task.spawn(function()
    while true do
        task.wait(0.5)
        pcall(function()
            if Settings.AutoStats then
                local stats = (#Settings.SelectedStats > 0) and Settings.SelectedStats or { Settings.SelectedStat }
                for _, stat in ipairs(stats) do
                    FireRemote("AllocateStat", stat, Settings.StatAmount)
                end
            end
            if Settings.AutoArmament and not ArmDebounce then
                local char = LocalPlayer.Character
                if char and char:FindFirstChild("Left Arm") then
                    if char["Left Arm"].BrickColor.Name ~= "Really black" then
                        ArmDebounce = true
                        FireRemote("HakiRemote", "Toggle")
                        task.delay(1.5, function() ArmDebounce = false end)
                    end
                end
            end
            if Settings.AutoObs and not ObsDebounce then
                local pGui = LocalPlayer:FindFirstChild("PlayerGui")
                if pGui then
                    local dodgeUI = pGui:FindFirstChild("DodgeCounterUI")
                    if dodgeUI and dodgeUI:FindFirstChild("MainFrame") and not dodgeUI.MainFrame.Visible then
                        ObsDebounce = true
                        FireRemote("ObservationHakiRemote", "Toggle")
                        task.delay(1.5, function() ObsDebounce = false end)
                    end
                end
            end
            if Settings.AutoConq then FireRemote("ConquerorHakiRemote", "Toggle") end

            if IS_IN_DUNGEON then
                if Settings.DungeonAutoArmament and not DungArmDebounce then
                    local char = LocalPlayer.Character
                    if char and char:FindFirstChild("Left Arm") then
                        if char["Left Arm"].BrickColor.Name ~= "Really black" then
                            DungArmDebounce = true
                            FireRemote("HakiRemote", "Toggle")
                            task.delay(1.5, function() DungArmDebounce = false end)
                        end
                    end
                end
                if Settings.DungeonAutoObs and not DungObsDebounce then
                    local pGui = LocalPlayer:FindFirstChild("PlayerGui")
                    if pGui then
                        local dodgeUI = pGui:FindFirstChild("DodgeCounterUI")
                        if dodgeUI and dodgeUI:FindFirstChild("MainFrame") and not dodgeUI.MainFrame.Visible then
                            DungObsDebounce = true
                            FireRemote("ObservationHakiRemote", "Toggle")
                            task.delay(1.5, function() DungObsDebounce = false end)
                        end
                    end
                end
                if Settings.DungeonAutoConq then FireRemote("ConquerorHakiRemote", "Toggle") end
            end
        end)
    end
end)

task.spawn(function()
    while true do
        task.wait(0.1)
        pcall(function()
            if Settings.AutoEquip and #Settings.SelectedWeapons > 0 then
                local char = LocalPlayer.Character
                if not char then return end
                for _, wName in ipairs(Settings.SelectedWeapons) do
                    local equipped = false
                    for _, t in ipairs(char:GetChildren()) do
                        if t:IsA("Tool") and t.Name == wName then equipped = true break end
                    end
                    if not equipped and LocalPlayer.Backpack then
                        local tool = LocalPlayer.Backpack:FindFirstChild(wName)
                        if tool and char:FindFirstChild("Humanoid") then
                            char.Humanoid:EquipTool(tool) break
                        end
                    end
                end
            end
            if IS_IN_DUNGEON and Settings.DungeonAutoEquip and #Settings.DungeonSelectedWeapons > 0 then
                local char = LocalPlayer.Character
                if not char then return end
                for _, wName in ipairs(Settings.DungeonSelectedWeapons) do
                    local equipped = false
                    for _, t in ipairs(char:GetChildren()) do
                        if t:IsA("Tool") and t.Name == wName then equipped = true break end
                    end
                    if not equipped and LocalPlayer.Backpack then
                        local tool = LocalPlayer.Backpack:FindFirstChild(wName)
                        if tool and char:FindFirstChild("Humanoid") then
                            char.Humanoid:EquipTool(tool) break
                        end
                    end
                end
            end
        end)
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════════
-- STOP ALL
-- ═══════════════════════════════════════════════════════════════════════════════
local function StopAll()
    Settings.AutoLevel          = false
    Settings.AutoFarmMob        = false
    Settings.AutoFarmBoss       = false
    Settings.AutoFarmPity       = false
    Settings.AutoSummonBoss     = false
    Settings.AutoCraftGrail     = false
    Settings.AutoCraftSlime     = false
    Settings.AutoAttack         = false
    Settings.AutoSkill          = false
    Settings.AutoUnlockSlime    = false
    Settings.AutoUnlockDungeon  = false
    Settings.AutoJoinDungeon    = false
    Settings.DungeonAutoFarm    = false
    Settings.DungeonAutoSkill   = false
    _instantHookActive          = false
    UnlockPosition()
    if CurrentTween then CurrentTween:Cancel() end
    SetStatus("Stopped")
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- UI BUILD
-- ═══════════════════════════════════════════════════════════════════════════════
local Window = Starlight:CreateWindow({
    Name     = "CrazyHub",
    Subtitle = "Game: Sailor Piece | Developer: Crazy",
    Icon     = NebulaIcons:GetIcon("sword", "Lucide"),
    LoadingSettings = { Title = "CrazyHub", Subtitle = "Loading..." },
    FileSettings    = { ConfigFolder = "CrazyHub_SailorPiece" }
})

Window:CreateHomeTab({
    SupportedExecutors = {"Synapse Z", "Scriptware", "Krnl", "Delta", "Fluxus", "Hydrogen", "Wave"},
    UnsupportedExecutors = {},
    DiscordInvite = "tjeCGgdC7j", Backdrop = 0, IconStyle = 1,
    Changelog = {{
        Title = "", Date = "Latest",
        Description = ""
    }}
})

if IS_IN_DUNGEON then
    -- ─────────────────────────────────────────────────────────────────────────
    -- DUNGEON-ONLY TABS
    -- ─────────────────────────────────────────────────────────────────────────
    local DungeonSection = Window:CreateTabSection("Dungeon")

    local DungeonTab = DungeonSection:CreateTab({
        Name = "Dungeon", Icon = NebulaIcons:GetIcon("sword","Lucide"), Columns = 2
    }, "DungeonTab")

    local DungFarmBox = DungeonTab:CreateGroupbox({ Name = "Dungeon Farm", Column = 1 }, "DungFarmBox")
    DungeonStatusLabel = DungFarmBox:CreateLabel({ Name = "Status: Idle" }, "DungeonStatusLbl")

    DungFarmBox:CreateToggle({
        Name = "Auto Farm Mobs", CurrentValue = false, Style = 2,
        Tooltip = "Teleports to and attacks EVERY alive NPC in the NPCs folder, cycling through all.",
        Callback = function(val)
            Settings.DungeonAutoFarm = val
            if val then task.spawn(DungeonFarmLoop) end
        end,
    }, "DungeonAutoFarmToggle")

    DungFarmBox:CreateDivider()

    DungFarmBox:CreateLabel({ Name = "Farm Position" }, "DungFarmPosLbl"):AddDropdown({
        Options = {"Above","Below","Behind"}, CurrentOption = {"Above"}, Placeholder = "Above", MultipleOptions = false,
        Callback = function(opts)
            Settings.DungeonFarmPosition = (type(opts)=="table" and opts[1]) or opts or "Above"
        end,
    }, "DungFarmPosDrop")

    DungFarmBox:CreateSlider({
        Name = "Farm Distance", Range = {1,20}, Increment = 1, CurrentValue = 6, Suffix = " Studs",
        Callback = function(val) Settings.DungeonFarmDistance = val end,
    }, "DungFarmDistSlider")

    DungFarmBox:CreateSlider({
        Name = "Tween Speed", Range = {16,500}, Increment = 1, CurrentValue = 50, Suffix = " Speed",
        Callback = function(val) Settings.Tween_Speed = val end,
    }, "DungTweenSpeedSlider")

    -- Col 1 – Difficulty vote + replay
    local DungVoteBox = DungeonTab:CreateGroupbox({ Name = "Difficulty & Replay", Column = 1 }, "DungVoteBox")

    DungVoteBox:CreateLabel({ Name = "Vote Difficulty" }, "DungDiffLbl"):AddDropdown({
        Options = DUNGEON_DIFFICULTIES, CurrentOption = {"Easy"}, Placeholder = "Easy", MultipleOptions = false,
        Callback = function(opts)
            Settings.DungeonDifficulty = (type(opts)=="table" and opts[1]) or opts or "Easy"
        end,
    }, "DungDiffDropdown")

    DungVoteBox:CreateToggle({
        Name = "Auto Vote Difficulty", CurrentValue = false, Style = 2,
        Tooltip = "Fires vote remote only when difficulty frames are visible.",
        Callback = function(val) Settings.DungeonAutoVote = val end,
    }, "DungAutoVoteToggle")

    DungVoteBox:CreateButton({
        Name = "Vote Now", Icon = NebulaIcons:GetIcon("check","Lucide"),
        Callback = function() VoteDungeonDifficulty(Settings.DungeonDifficulty) end,
    }, "DungVoteNowBtn")

    DungVoteBox:CreateDivider()

    DungVoteBox:CreateToggle({
        Name = "Auto Replay", CurrentValue = false, Style = 2,
        Tooltip = "Fires DungeonWaveReplayVote remote only when replay frame is visible.",
        Callback = function(val) Settings.DungeonAutoReplay = val end,
    }, "DungAutoReplayToggle")

    -- Col 2 – Auto Skill
    local DungSkillBox = DungeonTab:CreateGroupbox({ Name = "Auto Skills", Column = 2 }, "DungSkillBox")

    DungSkillBox:CreateLabel({ Name = "Select Keys" }, "DungSkillInfoLbl"):AddDropdown({
        Options = {"Z","X","C","V","F"},
        CurrentOption = {"Z","X","C","V","F"}, MultipleOptions = true, Placeholder = "None",
        Callback = function(opts)
            Settings.SelectedSkills = type(opts) == "table" and opts or {opts}
        end,
    }, "DungSkillKeysDropdown")

    DungSkillBox:CreateSlider({
        Name = "Skill Interval", Range = {0.05,5}, Increment = 0.05, CurrentValue = 0.5, Suffix = " s",
        Callback = function(val) Settings.SkillInterval = val end,
    }, "DungSkillIntervalSlider")

    DungSkillBox:CreateToggle({
        Name = "Auto Skill", CurrentValue = false, Style = 2,
        Callback = function(val)
            Settings.DungeonAutoSkill = val
            if val then task.spawn(DungeonSkillLoop) end
        end,
    }, "DungAutoSkillToggle")

    -- Col 2 – Auto Equip
    local DungWeaponBox = DungeonTab:CreateGroupbox({ Name = "Auto Equip Weapon", Column = 2 }, "DungWeaponBox")

    DungWeaponBox:CreateLabel({ Name = "Select Weapon(s)" }, "DungWeaponLbl"):AddDropdown({
        Options = WeaponsList, CurrentOption = {}, Placeholder = "None Selected", MultipleOptions = true,
        Callback = function(opts)
            Settings.DungeonSelectedWeapons = type(opts)=="table" and opts or {opts}
        end,
    }, "DungWeaponDropdown")

    DungWeaponBox:CreateToggle({
        Name = "Auto Equip", CurrentValue = false, Style = 2,
        Callback = function(val) Settings.DungeonAutoEquip = val end,
    }, "DungAutoEquipToggle")

    DungWeaponBox:CreateButton({
        Name = "Refresh Weapons", Icon = NebulaIcons:GetIcon("refresh-cw","Lucide"),
        Callback = function()
            RefreshWeapons()
            Starlight:Notification({ Title = "Weapons", Content = #WeaponsList .. " weapon(s) found.", Duration = 3 }, "DungWeaponsRefreshed")
        end,
    }, "DungRefreshWeaponsBtn")

    -- Col 2 – Haki
    local DungHakiBox = DungeonTab:CreateGroupbox({ Name = "Auto Haki", Column = 2 }, "DungHakiBox")
    DungHakiBox:CreateToggle({ Name = "Auto Armament Haki",    CurrentValue = false, Style = 2, Callback = function(val) Settings.DungeonAutoArmament = val end }, "DungArmamentToggle")
    DungHakiBox:CreateToggle({ Name = "Auto Observation Haki", CurrentValue = false, Style = 2, Callback = function(val) Settings.DungeonAutoObs = val end }, "DungObsToggle")
    DungHakiBox:CreateToggle({ Name = "Auto Conqueror Haki",   CurrentValue = false, Style = 2, Callback = function(val) Settings.DungeonAutoConq = val end }, "DungConqToggle")

    local ConfigSectionD = Window:CreateTabSection("Config")
    local ConfigTabD = ConfigSectionD:CreateTab({ Name = "Config", Icon = NebulaIcons:GetIcon("settings","Lucide"), Columns = 1 }, "ConfigTab")
    ConfigTabD:BuildConfigGroupbox(1)

    Starlight:Notification({
        Title   = "Dungeon Mode",
        Content = "Dungeon-only tabs loaded for Place ID " .. tostring(CURRENT_PLACE_ID),
        Icon    = NebulaIcons:GetIcon("sword","Lucide"),
        Duration = 4
    }, "DungeonTabLoaded")

else
    -- ─────────────────────────────────────────────────────────────────────────
    -- MAIN GAME TABS
    -- ─────────────────────────────────────────────────────────────────────────
    local FarmSection   = Window:CreateTabSection("Farming")
    local BossSection   = Window:CreateTabSection("Boss Farm")
    local CombatSection = Window:CreateTabSection("Combat")
    local MiscSection   = Window:CreateTabSection("MISC")
    local ConfigSection = Window:CreateTabSection("Config")

    -- ─── TAB: AUTO LEVEL ─────────────────────────────────────────────────────
    local AutoLevelTab = FarmSection:CreateTab({
        Name = "Auto Level", Icon = NebulaIcons:GetIcon("trending-up","Lucide"), Columns = 2
    }, "AutoLevelTab")

    local ControlBox = AutoLevelTab:CreateGroupbox({ Name = "Auto Level", Column = 1 }, "ControlBox")
    StatusLabel = ControlBox:CreateLabel({ Name = "Status: Idle" }, "StatusLbl")
    LevelLabel  = ControlBox:CreateLabel({ Name = "Level: --" }, "LevelLbl")

    ControlBox:CreateToggle({
        Name = "Auto Level", CurrentValue = false, Style = 2, Tooltip = "",
        Callback = function(val)
            Settings.AutoLevel = val ForceQuestRefresh = val
            if val then task.spawn(AutoLevelLoop) end
        end,
    }, "AutoLevelToggle")

    local MobBox = AutoLevelTab:CreateGroupbox({ Name = "Farm Mobs", Column = 1 }, "MobBox")
    MobStatusLabel = MobBox:CreateLabel({ Name = "Status: Idle" }, "MobStatusLbl")

    MobBox:CreateLabel({ Name = "Select Mob(s)" }, "MobSelectLbl"):AddDropdown({
        Options = MobsList, CurrentOption = {}, Placeholder = "None Selected", MultipleOptions = true,
        Callback = function(opts)
            Settings.SelectedMob = type(opts) == "table" and opts or { opts }
        end,
    }, "MobDropdown")

    MobBox:CreateToggle({
        Name = "Auto Farm Mob", CurrentValue = false, Style = 2,
        Tooltip = "Teleports to and attacks each selected mob, cycling through all alive ones.",
        Callback = function(val)
            Settings.AutoFarmMob = val
            if val then task.spawn(function() ManualFarmLoop(false) end) end
        end,
    }, "AutoFarmMobToggle")

    MobBox:CreateButton({
        Name = "Refresh Lists", Icon = NebulaIcons:GetIcon("refresh-cw","Lucide"),
        Callback = function() RefreshNPCs() end,
    }, "RefreshMobBtn")

    -- Position & Distance (Col 2)
    local PosBox = AutoLevelTab:CreateGroupbox({ Name = "Position & Distance", Column = 2 }, "PosBox")

    PosBox:CreateLabel({ Name = "Farm Position" }, "FarmPosLbl"):AddDropdown({
        Options = {"Above","Below","Behind"}, CurrentOption = {"Above"}, Placeholder = "Above",
        MultipleOptions = false,
        Callback = function(opts)
            Settings.Farm_Position = (type(opts)=="table" and opts[1]) or opts or "Above"
        end,
    }, "FarmPosDrop")

    PosBox:CreateSlider({
        Name = "Farm Distance", Range = {1,15}, Increment = 1, CurrentValue = 6, Suffix = " Studs",
        Callback = function(val) Settings.Farm_Distance = val end,
    }, "FarmDistSlider")

    PosBox:CreateSlider({
        Name = "Tween Speed", Range = {16,500}, Increment = 1, CurrentValue = 50, Suffix = " Speed",
        Callback = function(val) Settings.Tween_Speed = val end,
    }, "TweenSpeed")

    PosBox:CreateDivider()

    -- Auto Join Dungeon (Col 2)
    local JoinDungeonBox = AutoLevelTab:CreateGroupbox({ Name = "Auto Join Dungeon", Column = 2 }, "JoinDungeonBox")

    JoinDungeonBox:CreateLabel({ Name = "Select Dungeon" }, "JoinDungeonLbl"):AddDropdown({
        Options = DUNGEON_LABELS, CurrentOption = {"Cid Dungeon"}, Placeholder = "Cid Dungeon",
        MultipleOptions = false,
        Callback = function(opts)
            local label = (type(opts)=="table" and opts[1]) or opts or "Cid Dungeon"
            for _, d in ipairs(DUNGEON_OPTIONS) do
                if d.label == label then Settings.SelectedDungeon = d.arg break end
            end
        end,
    }, "JoinDungeonDropdown")

    JoinDungeonBox:CreateToggle({
        Name = "Auto Join Dungeon", CurrentValue = false, Style = 2,
        Tooltip = "Repeatedly fires RequestDungeonPortal until teleported in.",
        Callback = function(val)
            Settings.AutoJoinDungeon = val
            if val then task.spawn(AutoJoinDungeonLoop) end
        end,
    }, "AutoJoinDungeonToggle")

    -- ─── TAB: BOSS FARM ───────────────────────────────────────────────────────
    local BossFarmTab = BossSection:CreateTab({
        Name = "Boss Farm", Icon = NebulaIcons:GetIcon("skull","Lucide"), Columns = 2
    }, "BossFarmTab")

    local PityBox = BossFarmTab:CreateGroupbox({ Name = "Pity Farm", Column = 1 }, "PityBox")
    PityLabel = PityBox:CreateLabel({ Name = "Pity: --" }, "PityLbl")

    PityFarmDropdownRef = PityBox:CreateLabel({ Name = "Pity Farm Bosses" }, "PityFarmLbl"):AddDropdown({
        Options = PityBossList, CurrentOption = {}, Placeholder = "--", MultipleOptions = true,
        Callback = function(opts)
            Settings.PityFarmBossList = type(opts) == "table" and opts or { opts }
            Settings.PityFarmBoss     = Settings.PityFarmBossList[1]
        end,
    }, "PityFarmDropdown")

    PityKillDropdownRef = PityBox:CreateLabel({ Name = "25th Kill Boss" }, "PityKillLbl"):AddDropdown({
        Options = PityBossList, CurrentOption = {}, Placeholder = "--", MultipleOptions = false,
        Callback = function(opts)
            Settings.PityKillBoss = (type(opts)=="table" and opts[1]) or opts
        end,
    }, "PityKillDropdown")

    PityBox:CreateLabel({ Name = "Kill Boss Difficulty" }, "PityDiffLbl"):AddDropdown({
        Options = SUMMON_DIFFICULTIES, CurrentOption = {"Normal"}, Placeholder = "Normal", MultipleOptions = false,
        Callback = function(opts)
            Settings.PityDifficulty = (type(opts)=="table" and opts[1]) or opts or "Normal"
        end,
    }, "PityDiffDropdown")

    PityBox:CreateToggle({
        Name = "Auto Pity Farm", CurrentValue = false, Style = 2,
        Callback = function(val)
            Settings.AutoFarmPity = val
            if val then task.spawn(AutoPityLoop) end
        end,
    }, "AutoPityToggle")

    PityBox:CreateButton({
        Name = "Refresh Boss List", Icon = NebulaIcons:GetIcon("refresh-cw","Lucide"),
        Callback = function()
            RefreshNPCs()
            Starlight:Notification({ Title = "Pity Farm", Content = #PityBossList .. " bosses in list.", Duration = 3 }, "PityRefresh")
        end,
    }, "PityRefreshBtn")

    local WorldBossBox = BossFarmTab:CreateGroupbox({ Name = "World Boss Farm", Column = 1 }, "WorldBossBox")
    BossStatusLabel = WorldBossBox:CreateLabel({ Name = "Status: Idle" }, "BossStatusLbl")

    WorldBossBox:CreateLabel({ Name = "Select Boss" }, "BossSelectLbl"):AddDropdown({
        Options = BossesList, CurrentOption = {}, Placeholder = "None Selected", MultipleOptions = true,
        Callback = function(opts)
            Settings.SelectedBoss = type(opts) == "table" and opts or { opts }
        end,
    }, "BossDropdown")

    WorldBossBox:CreateToggle({
        Name = "Auto Farm Boss", CurrentValue = false, Style = 2,
        Tooltip = "Cycles through all selected bosses.",
        Callback = function(val)
            Settings.AutoFarmBoss = val
            if val then task.spawn(function() ManualFarmLoop(true) end) end
        end,
    }, "AutoFarmBossToggle")

    WorldBossBox:CreateButton({
        Name = "Refresh Boss List", Icon = NebulaIcons:GetIcon("refresh-cw","Lucide"),
        Callback = function() RefreshNPCs() end,
    }, "RefreshBossBtn")

    local SummonBox = BossFarmTab:CreateGroupbox({ Name = "Summonable Bosses", Column = 1 }, "SummonBox")

    SummonBox:CreateLabel({ Name = "Select Boss" }, "SummonBossLbl"):AddDropdown({
        Options = SUMMON_BOSS_LABELS, CurrentOption = {"Saber Boss"}, Placeholder = "Saber Boss", MultipleOptions = false,
        Callback = function(opts)
            Settings.SummonBossName = (type(opts)=="table" and opts[1]) or opts or "Saber Boss"
        end,
    }, "SummonBossDropdown")

    SummonBox:CreateLabel({ Name = "Difficulty" }, "DiffLbl"):AddDropdown({
        Options = SUMMON_DIFFICULTIES, CurrentOption = {"Normal"}, Placeholder = "Normal", MultipleOptions = false,
        Callback = function(opts)
            Settings.SummonDifficulty = (type(opts)=="table" and opts[1]) or opts or "Normal"
        end,
    }, "DiffDropdown")

    SummonBox:CreateToggle({
        Name = "Auto Farm", CurrentValue = false, Style = 2,
        Callback = function(val)
            Settings.AutoSummonBoss = val
            if val then task.spawn(AutoSummonBossLoop) end
        end,
    }, "AutoSummonToggle")

    local CraftBox = BossFarmTab:CreateGroupbox({ Name = "Auto Craft", Column = 2 }, "CraftBox")

    CraftBox:CreateToggle({
        Name = "Auto Craft Divine Grail", CurrentValue = false, Style = 2,
        Callback = function(val)
            Settings.AutoCraftGrail = val
            if val then task.spawn(AutoCraftGrailLoop) end
        end,
    }, "AutoCraftGrailToggle")

    CraftBox:CreateDivider()

    CraftBox:CreateToggle({
        Name = "Auto Craft Slime Key", CurrentValue = false, Style = 2,
        Callback = function(val)
            Settings.AutoCraftSlime = val
            if val then task.spawn(AutoCraftSlimeLoop) end
        end,
    }, "AutoCraftSlimeToggle")

    -- ─── TAB: COMBAT ─────────────────────────────────────────────────────────
    local CombatTab = CombatSection:CreateTab({
        Name = "Combat", Icon = NebulaIcons:GetIcon("zap","Lucide"), Columns = 2
    }, "CombatTab")

    local AttackBox = CombatTab:CreateGroupbox({ Name = "Auto Attack", Column = 1 }, "AttackBox")
    AttackBox:CreateToggle({
        Name = "Auto Attack", CurrentValue = false, Style = 2,
        Callback = function(val)
            Settings.AutoAttack = val
            if val then task.spawn(AutoAttackLoop) end
        end,
    }, "AutoAttackToggle")

    AttackBox:CreateDivider()
    local SkillBox = CombatTab:CreateGroupbox({ Name = "Auto Skills", Column = 1 }, "SkillBox")

    SkillBox:CreateLabel({ Name = "Select Keys" }, "SkillInfoLbl"):AddDropdown({
        Options = {"Z","X","C","V","F"},
        CurrentOption = {"Z","X","C","V","F"}, MultipleOptions = true, Placeholder = "None",
        Callback = function(opts)
            Settings.SelectedSkills = type(opts) == "table" and opts or {opts}
        end,
    }, "SkillKeysDropdown")

    SkillBox:CreateSlider({
        Name = "Skill Interval", Range = {0.05,5}, Increment = 0.05, CurrentValue = 0.5, Suffix = " s",
        Callback = function(val) Settings.SkillInterval = val end,
    }, "SkillIntervalSlider")

    SkillBox:CreateToggle({
        Name = "Auto Skill", CurrentValue = false, Style = 2,
        Callback = function(val)
            Settings.AutoSkill = val
            if val then task.spawn(AutoSkillLoop) end
        end,
    }, "AutoSkillToggle")

    local WeaponBox = CombatTab:CreateGroupbox({ Name = "Auto Equip Weapon", Column = 2 }, "WeaponBox")

    WeaponBox:CreateLabel({ Name = "Select Weapon(s)" }, "WeaponLbl"):AddDropdown({
        Options = WeaponsList, CurrentOption = {}, Placeholder = "None Selected", MultipleOptions = true,
        Callback = function(opts)
            Settings.SelectedWeapons = type(opts) == "table" and opts or { opts }
        end,
    }, "WeaponDropdown")

    WeaponBox:CreateToggle({
        Name = "Auto Equip", CurrentValue = false, Style = 2,
        Callback = function(val) Settings.AutoEquip = val end,
    }, "AutoEquipToggle")

    WeaponBox:CreateButton({
        Name = "Refresh Weapons", Icon = NebulaIcons:GetIcon("refresh-cw","Lucide"),
        Callback = function()
            RefreshWeapons()
            Starlight:Notification({ Title = "Weapons", Content = #WeaponsList .. " weapon(s) found.", Duration = 3 }, "WeaponsRefreshed")
        end,
    }, "RefreshWeaponsBtn")

    local HakiBox = CombatTab:CreateGroupbox({ Name = "Auto Haki", Column = 2 }, "HakiBox")
    HakiBox:CreateToggle({ Name = "Auto Armament Haki",    CurrentValue = false, Style = 2, Callback = function(val) Settings.AutoArmament = val end }, "ArmamentToggle")
    HakiBox:CreateToggle({ Name = "Auto Observation Haki", CurrentValue = false, Style = 2, Callback = function(val) Settings.AutoObs = val end }, "ObsToggle")
    HakiBox:CreateToggle({ Name = "Auto Conqueror Haki",   CurrentValue = false, Style = 2, Callback = function(val) Settings.AutoConq = val end }, "ConqToggle")

    -- ─── TAB: MISC ────────────────────────────────────────────────────────────
    local MiscTab = MiscSection:CreateTab({
        Name = "MISC", Icon = NebulaIcons:GetIcon("settings-2","Lucide"), Columns = 2
    }, "MiscTab")

    local StatsBox = MiscTab:CreateGroupbox({ Name = "Auto Stats", Column = 1 }, "StatsBox")

    StatsBox:CreateLabel({ Name = "Select Stat(s)" }, "StatLbl"):AddDropdown({
        Options = {"Melee","Defense","Sword","Power"}, CurrentOption = {"Melee"},
        MultipleOptions = true, Placeholder = "None",
        Callback = function(opts)
            Settings.SelectedStats = type(opts) == "table" and opts or { opts }
            Settings.SelectedStat  = Settings.SelectedStats[1] or "Melee"
        end,
    }, "StatDropdown")

    StatsBox:CreateToggle({
        Name = "Auto Allocate Stats", CurrentValue = false, Style = 2,
        Callback = function(val) Settings.AutoStats = val end,
    }, "AutoStatsToggle")

    StatsBox:CreateSlider({
        Name = "Points Per Tick", Range = {1,1000}, Increment = 1, CurrentValue = 1, Suffix = " pts",
        Callback = function(val) Settings.StatAmount = val end,
    }, "StatAmountSlider")

    local IslandBox = MiscTab:CreateGroupbox({ Name = "Teleport Islands", Column = 1 }, "IslandBox")
    local selectedIsland = nil

    IslandBox:CreateLabel({ Name = "Select Island" }, "IslandLbl"):AddDropdown({
        Options = ISLANDS, CurrentOption = {}, Placeholder = "None Selected", MultipleOptions = false,
        Callback = function(opts) selectedIsland = (type(opts)=="table" and opts[1]) or opts end,
    }, "IslandDropdown")

    IslandBox:CreateButton({
        Name = "Teleport to Island", Icon = NebulaIcons:GetIcon("map-pin","Lucide"),
        Callback = function()
            if not selectedIsland then return end
            local islandFolder = Workspace:FindFirstChild(selectedIsland)
            if not islandFolder then
                Starlight:Notification({ Title = "Teleport", Content = selectedIsland .. " not found", Duration = 2 }, "IslandTPFail")
                return
            end
            local spawnPart = nil
            for _, child in ipairs(islandFolder:GetChildren()) do
                if child.Name:lower():find("spawnpointcrystal") then spawnPart = child break end
            end
            local char = GetCharacter()
            if char and spawnPart then
                local cf = GetModelCFrame(spawnPart) or CFrame.new(spawnPart.Position)
                char.HumanoidRootPart.CFrame = cf + Vector3.new(0, 3, 0)
            elseif char and islandFolder then
                local cf = GetModelCFrame(islandFolder)
                if cf then char.HumanoidRootPart.CFrame = cf + Vector3.new(0, 3, 0) end
            end
        end,
    }, "IslandTPBtn")

    local CodesBox = MiscTab:CreateGroupbox({ Name = "Redeem Codes", Column = 1 }, "CodesBox")

local CODES = {
    "25KCCU",
    "UPD5",
    "7.5KFOLLOWTY",
    "10KFOLLOWTY",
    "12.5KFOLLOWTY",
    "ROGUE",
}

local CodeRemote = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("CodeRedeem")

CodesBox:CreateButton({
    Name = "Redeem All Codes",
    Icon = NebulaIcons:GetIcon("gift", "Lucide"),
    Callback = function()
        local redeemed = 0
        for _, code in ipairs(CODES) do
            pcall(function()
                CodeRemote:InvokeServer(code)
            end)
            redeemed = redeemed + 1
            task.wait(0.5) -- small delay between each to avoid rate limiting
        end
        Starlight:Notification({
            Title   = "Codes Redeemed",
            Content = "Attempted " .. redeemed .. " codes!",
            Icon    = NebulaIcons:GetIcon("check", "Lucide"),
            Duration = 4
        }, "CodesRedeemed")
    end,
}, "RedeemAllCodesBtn")

    local ServiceBox = MiscTab:CreateGroupbox({ Name = "Service NPCs Teleport", Column = 2 }, "ServiceBox")
    local selectedServiceNPC = nil

    ServiceBox:CreateLabel({ Name = "Buyer / Shop NPCs" }, "BuyerLbl"):AddDropdown({
        Options = BuyerNPCList, CurrentOption = {}, Placeholder = "None", MultipleOptions = false,
        Callback = function(opts) selectedServiceNPC = (type(opts)=="table" and opts[1]) or opts end,
    }, "BuyerDropdown")

    ServiceBox:CreateLabel({ Name = "Mastery NPCs" }, "MasteryLbl"):AddDropdown({
        Options = MasteryNPCList, CurrentOption = {}, Placeholder = "None", MultipleOptions = false,
        Callback = function(opts) selectedServiceNPC = (type(opts)=="table" and opts[1]) or opts end,
    }, "MasteryDropdown")

    ServiceBox:CreateLabel({ Name = "Other NPCs" }, "OtherLbl"):AddDropdown({
        Options = OtherNPCList, CurrentOption = {}, Placeholder = "None", MultipleOptions = false,
        Callback = function(opts) selectedServiceNPC = (type(opts)=="table" and opts[1]) or opts end,
    }, "OtherDropdown")

    ServiceBox:CreateButton({
        Name = "Teleport to NPC", Icon = NebulaIcons:GetIcon("map-pin","Lucide"),
        Callback = function()
            if not selectedServiceNPC then return end
            local folder = Workspace:FindFirstChild("ServiceNPCs")
            if not folder then return end
            local npc = folder:FindFirstChild(selectedServiceNPC)
            if not npc then return end
            local char = GetCharacter()
            if not char then return end
            local cf = GetModelCFrame(npc)
            if cf then char.HumanoidRootPart.CFrame = cf + Vector3.new(0, 3, 0) end
        end,
    }, "ServiceTPBtn")

    ServiceBox:CreateButton({
        Name = "Refresh NPC Lists", Icon = NebulaIcons:GetIcon("refresh-cw","Lucide"),
        Callback = function()
            RefreshServiceNPCs()
            Starlight:Notification({ Title = "Refreshed", Content = "Service NPC lists updated.", Duration = 2 }, "SvcRefresh")
        end,
    }, "RefreshServiceBtn")

    local UnlockBox = MiscTab:CreateGroupbox({ Name = "Unlock Quests", Column = 2 }, "UnlockBox")
    UnlockBox:CreateLabel({ Name = "Auto Unlock" }, "UnlockInfoLbl")
    UnlockBox:CreateDivider()

    UnlockBox:CreateToggle({
        Name = "Unlock Slime Crafting", CurrentValue = false, Style = 2,
        Callback = function(val)
            Settings.AutoUnlockSlime = val
            if val then task.spawn(AutoUnlockSlimeLoop) end
        end,
    }, "UnlockSlimeToggle")

    UnlockBox:CreateDivider()

    UnlockBox:CreateToggle({
        Name = "Unlock Dungeon Portals", CurrentValue = false, Style = 2,
        Tooltip = "Phase 1: collect 6 pieces. Phase 2: kill 25 bosses.",
        Callback = function(val)
            Settings.AutoUnlockDungeon = val
            if val then task.spawn(AutoUnlockDungeonLoop) end
        end,
    }, "UnlockDungeonToggle")

    -- ─── TAB: CONFIG ──────────────────────────────────────────────────────────
    local ConfigTab = ConfigSection:CreateTab({
        Name = "Config", Icon = NebulaIcons:GetIcon("settings","Lucide"), Columns = 1
    }, "ConfigTab")
    ConfigTab:BuildConfigGroupbox(1)

end  -- end IS_IN_DUNGEON else block

-- ═══════════════════════════════════════════════════════════════════════════════
-- FINAL SETUP
-- ═══════════════════════════════════════════════════════════════════════════════
Starlight:OnDestroy(function()
    StopAll()
    Settings.AutoEquip        = false
    Settings.AutoStats        = false
    Settings.AutoArmament     = false
    Settings.AutoObs          = false
    Settings.AutoConq         = false
    Settings.AutoSkill        = false
    Settings.DungeonAutoSkill = false
    _instantHookActive        = false
    UnlockPosition()
    if CurrentTween then CurrentTween:Cancel() end
end)

Starlight:LoadAutoloadConfig()

Starlight:Notification({
    Title   = "CrazyHub",
    Content = "Loaded! Join the Discord for support, updates, and more scripts.\nhttps://discord.gg/tjeCGgdC7j",
    Icon    = NebulaIcons:GetIcon("check","Lucide"),
    Duration = 4
}, "LoadedNotif")
