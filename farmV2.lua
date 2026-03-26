-- ================= CONFIGURATION =================
local TARGET_ORE = "Abyssalite"
local TOOL_NAME = "Obsidian Pickaxe"
local BAG_NAME = "Item Bag"

local IDLE_POS = CFrame.new(-7115, -693, -2533)
local DROP_POS = CFrame.new(932, 40, -702) 

-- Зона фарма (Bounding Box)
local A, B = Vector3.new(-7184, -703, -2544), Vector3.new(-7057, -720, -2531)
local ZONE = {
    MIN = Vector3.new(math.min(A.X, B.X) - 5, math.min(A.Y, B.Y) - 5, math.min(A.Z, B.Z) - 5),
    MAX = Vector3.new(math.max(A.X, B.X) + 5, math.max(A.Y, B.Y) + 5, math.max(A.Z, B.Z) + 5)
}

local MAX_BAG = 5
-- =================================================

local plr = game.Players.LocalPlayer
local char = plr.Character or plr.CharacterAdded:Wait()
local root = char:WaitForChild("HumanoidRootPart")
local Events = game:GetService("ReplicatedStorage"):WaitForChild("Events")

local active = false
local isBusy = false 
local statusText = "OFF"
local floor = nil

-- [СИСТЕМА GUI]
local sg = Instance.new("ScreenGui", game.CoreGui)
local bt = Instance.new("TextButton", sg)
bt.Size, bt.Position = UDim2.new(0, 180, 0, 50), UDim2.new(0.5, -90, 0.05, 0)
bt.Text, bt.BackgroundColor3 = "SYSTEM: OFF", Color3.new(0.5, 0, 0)
bt.TextColor3, bt.Font, bt.TextSize = Color3.new(1,1,1), 3, 18

local log = Instance.new("TextLabel", sg)
log.Size, log.Position = UDim2.new(0, 300, 0, 140), UDim2.new(0.5, -150, 0.05, 60)
log.BackgroundColor3, log.TextColor3, log.BackgroundTransparency = Color3.new(0,0,0), Color3.new(1,1,1), 0.5
log.TextSize, log.Font = 15, 3

-- [ФУНКЦИИ ПРОВЕРКИ]
local function isInZone(pos)
    return pos.X >= ZONE.MIN.X and pos.X <= ZONE.MAX.X and
           pos.Y >= ZONE.MIN.Y and pos.Y <= ZONE.MAX.Y and
           pos.Z >= ZONE.MIN.Z and pos.Z <= ZONE.MAX.Z
end

local function getInfo()
    local myDrops = {}
    for _, item in pairs(workspace.Grab:GetChildren()) do
        if item.Name == "MaterialPart" then
            local p = item:FindFirstChild("Part")
            local o = item:FindFirstChild("Owner")
            local m = item:FindFirstChild("Configuration") and item.Configuration.Data:FindFirstChild("MaterialString")
            if p and o and o.Value == plr and m and m.Value == TARGET_ORE and isInZone(p.Position) then
                table.insert(myDrops, item)
            end
        end
    end

    local firstOre = nil
    for _, v in pairs(workspace.WorldSpawn.Ores:GetChildren()) do
        if v.Name == TARGET_ORE and v:FindFirstChild("Hittable") then
            firstOre = v; break
        end
    end

    local bagCount = 0
    local bag = char:FindFirstChild(BAG_NAME) or plr.Backpack:FindFirstChild(BAG_NAME)
    local bagData = nil
    if bag then
        bagData = bag.Configuration.Data.Stored
        local _, count = string.gsub(bagData.Value, "Key", "")
        bagCount = count
    end

    return myDrops, firstOre, bagCount, bag, bagData
end

local function toggleFloor(cf)
    if not cf and floor then floor:Destroy() floor = nil return end
    if not floor then
        floor = Instance.new("Part", workspace)
        floor.Size, floor.Anchored, floor.Transparency = Vector3.new(12, 1, 12), true, 1
    end
    floor.CFrame = cf * CFrame.new(0, -3.2, 0)
end

-- ================= СЦЕНАРИЙ 1: МАЙНИНГ ОДНОЙ РУДЫ =================
local function runMiningScenario(ore)
    isBusy = true
    statusText = "ACTION: MINING (1 NODE)"
    
    local tool = char:FindFirstChild(TOOL_NAME) or plr.Backpack:FindFirstChild(TOOL_NAME)
    if not tool then isBusy = false return end
    if tool.Parent ~= char then tool.Parent = char end

    -- Проходим строго по Hittable частям этой руды
    local parts = ore.Hittable:GetChildren()
    for _, h in ipairs(parts) do
        local p = h:IsA("BasePart") and h or h:FindFirstChild("Part")
        if p then
            root.CFrame = p.CFrame * CFrame.new(0, 4, 3)
            toggleFloor(root.CFrame)
            
            Events.Tools.ToolInputChanged:FireServer(tool, true)
            Events.Tools.Charge:FireServer({["Target"] = p, ["HitPosition"] = p.Position})
            task.wait(0.05)
            Events.Tools.Attack:FireServer({["Alpha"] = 1, ["ResponseTime"] = 0.4})
            Events.Tools.ToolInputChanged:FireServer(tool, false)
            task.wait(0.3) -- Cooldown
        end
    end

    -- Конец сценария -> IDLE
    statusText = "STATUS: TRANSITIONING"
    root.CFrame = IDLE_POS
    toggleFloor(IDLE_POS)
    task.wait(0.5)
    isBusy = false
end

-- ================= СЦЕНАРИЙ 2: СБОР И ВЫГРУЗКА =================
local function runTransportScenario(drops, bag, data)
    isBusy = true
    statusText = "ACTION: COLLECTING DROPS"
    
    if bag.Parent ~= char then bag.Parent = char end

    -- А. Сбор до фулла
    for i, item in ipairs(drops) do
        local _, _, bagCount = getInfo()
        if bagCount >= MAX_BAG then break end
        
        local p = item:FindFirstChild("Part")
        if p then
            root.CFrame = p.CFrame * CFrame.new(0, 3, 0)
            toggleFloor(root.CFrame)
            task.wait(0.2)
            bag.Action:FireServer("Store", p)
            task.wait(0.3) -- Даем серверу время
        end
    end

    -- Б. Если сумка забита - на базу
    local _, _, finalCount = getInfo()
    if finalCount >= MAX_BAG then
        statusText = "ACTION: TELEPORT TO BASE"
        root.CFrame = DROP_POS
        toggleFloor(DROP_POS)
        task.wait(1.5) -- Прогрузка эмулятора
        
        statusText = "ACTION: DUMPING ITEMS"
        local safety = 0
        while data.Value ~= "[]" and safety < 15 do
            bag.Action:FireServer("Drop")
            task.wait(0.5)
            safety = safety + 1
        end
    end

    -- Конец сценария -> IDLE
    statusText = "STATUS: TRANSITIONING"
    root.CFrame = IDLE_POS
    toggleFloor(IDLE_POS)
    task.wait(0.5)
    isBusy = false
end

-- [УПРАВЛЕНИЕ]
bt.MouseButton1Click:Connect(function()
    active = not active
    bt.Text = active and "SYSTEM: ACTIVE" or "SYSTEM: OFF"
    bt.BackgroundColor3 = active and Color3.new(0, 0.6, 0) or Color3.new(0.6, 0, 0)
    if not active then statusText = "OFF" toggleFloor(nil) end
end)

-- [ГЛАВНЫЙ ПОТОК]
task.spawn(function()
    while true do
        task.wait(0.2)
        local myDrops, firstOre, bagCount, bag, bagData = getInfo()
        
        log.Text = string.format(
            " %s\n ----------------------\n BAG: %d/5\n DROPS IN ZONE: %d\n MAP ORES: %s",
            statusText, bagCount, #myDrops, firstOre and "READY" or "NONE"
        )

        if active and not isBusy then
            pcall(function()
                -- 1. Приоритет Сбора (если на полу есть своё или сумка полная)
                if #myDrops >= 1 or bagCount >= MAX_BAG then
                    runTransportScenario(myDrops, bag, bagData)
                
                -- 2. Приоритет Копки (если пол чист и есть руда)
                elseif firstOre then
                    runMiningScenario(firstOre)
                
                -- 3. Ожидание
                else
                    statusText = "STATUS: IDLE (Wait Respawn)"
                    root.CFrame = IDLE_POS
                    toggleFloor(IDLE_POS)
                end
            end)
        end
    end
end)

for i, v in pairs(getconnections(plr.Idled)) do v:Disable() end