-- ================= CONFIGURATION =================
local TARGET_ORE = "Abyssalite"
local TOOL_NAME = "Obsidian Pickaxe"
local BAG_NAME = "Item Bag"

local IDLE_POS = CFrame.new(-7115, -693, -2533)
local DROP_POS = CFrame.new(1945, 60, -32) -- Сброс с высоты ~5 стадов

-- Зона фарма (Bounding Box)
local A, B = Vector3.new(-7184, -703, -2544), Vector3.new(-7057, -720, -2531)
local ZONE = {
    MIN = Vector3.new(math.min(A.X, B.X), math.min(A.Y, B.Y), math.min(A.Z, B.Z)),
    MAX = Vector3.new(math.max(A.X, B.X), math.max(A.Y, B.Y), math.max(A.Z, B.Z))
}

local MAX_BAG = 5
local DROP_DELAY = 0.5 -- Та самая задержка сервера на выброс
-- =================================================

local plr = game.Players.LocalPlayer
local char = plr.Character or plr.CharacterAdded:Wait()
local root = char:WaitForChild("HumanoidRootPart")
local Events = game:GetService("ReplicatedStorage"):WaitForChild("Events")

local active = true -- Тумблер
local floor = nil

-- [УТИЛИТЫ]
local function isInZone(pos)
    return pos.X >= ZONE.MIN.X and pos.X <= ZONE.MAX.X and
           pos.Y >= ZONE.MIN.Y and pos.Y <= ZONE.MAX.Y and
           pos.Z >= ZONE.MIN.Z and pos.Z <= ZONE.MAX.Z
end

local function updateFloor(cf)
    if not floor then
        floor = Instance.new("Part", workspace)
        floor.Size, floor.Anchored, floor.Transparency = Vector3.new(15, 1, 15), true, 0.8
    end
    floor.CFrame = cf * CFrame.new(0, -3.5, 0)
end

local function getBagData()
    local bag = char:FindFirstChild(BAG_NAME) or plr.Backpack:FindFirstChild(BAG_NAME)
    if not bag then return 0, nil end
    local data = bag.Configuration.Data.Stored
    local _, count = string.gsub(data.Value, "Key", "")
    return count, bag, data
end

-- [ЛОГИКА СБРОСА]
local function clearBag(bag, data)
    print("Dumping items...")
    root.CFrame = DROP_POS
    updateFloor(DROP_POS)
    task.wait(1) -- Ждем отвисания эмулятора после ТП
    
    if bag.Parent ~= char then bag.Parent = char end
    
    local timeout = 0
    while data.Value ~= "[]" and timeout < 15 do
        bag.Action:FireServer("Drop")
        task.wait(DROP_DELAY)
        timeout = timeout + 1
    end
end

-- [ЛОГИКА ПОДБОРА]
local function collectDrops(needed)
    local collected = 0
    local bag = char:FindFirstChild(BAG_NAME) or plr.Backpack:FindFirstChild(BAG_NAME)
    if bag.Parent ~= char then bag.Parent = char end

    for _, item in pairs(workspace.Grab:GetChildren()) do
        if collected >= needed then break end
        local p, o = item:FindFirstChild("Part"), item:FindFirstChild("Owner")
        local mat = item:FindFirstChild("Configuration") and item.Configuration.Data:FindFirstChild("MaterialString")
        
        if p and o and o.Value == plr and mat and mat.Value == TARGET_ORE and isInZone(p.Position) then
            root.CFrame = p.CFrame * CFrame.new(0, 3, 0)
            task.wait(0.1)
            bag.Action:FireServer("Store", p)
            collected = collected + 1
            task.wait(0.2)
        end
    end
end

-- [ОСНОВНОЙ ЦИКЛ]
task.spawn(function()
    while true do
        task.wait(0.5)
        if not active then continue end
        
        pcall(function()
            local inBag, bag, bagData = getBagData()
            
            -- СЦЕНАРИЙ 1: Пора на базу
            if inBag >= MAX_BAG then
                clearBag(bag, bagData)
                root.CFrame = IDLE_POS -- Возврат в зону ожидания
                return
            end

            -- СЦЕНАРИЙ 2: Считаем, что на полу
            local dropsOnFloor = 0
            for _, item in pairs(workspace.Grab:GetChildren()) do
                local p, o = item:FindFirstChild("Part"), item:FindFirstChild("Owner")
                if p and o and o.Value == plr and isInZone(p.Position) then
                    dropsOnFloor = dropsOnFloor + 1
                end
            end

            if dropsOnFloor >= 5 then
                collectDrops(MAX_BAG - inBag)
            else
                -- СЦЕНАРИЙ 3: Копаем
                local ore = workspace.WorldSpawn.Ores:FindFirstChild(TARGET_ORE)
                if ore then
                    local targetPart = ore.Hittable:FindFirstChild("Part")
                    if targetPart then
                        root.CFrame = targetPart.CFrame * CFrame.new(0, 4, 3)
                        updateFloor(root.CFrame)
                        -- Тут твои пакеты атаки:
                        Events.Tools.Attack:FireServer({["Alpha"] = 1, ["ResponseTime"] = 0.4})
                    end
                else
                    root.CFrame = IDLE_POS
                    updateFloor(IDLE_POS)
                end
            end
        end)
    end
end)

-- Anti-AFK (чтобы не кикнуло за 20 мин фарма)
for i, v in pairs(getconnections(plr.Idled)) do v:Disable() end