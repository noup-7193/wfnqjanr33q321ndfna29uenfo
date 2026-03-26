-- ================= CONFIGURATION =================
local TARGET_ORE = "Abyssalite"
local TOOL_NAME = "Obsidian Pickaxe"
local BAG_NAME = "Item Bag"

local IDLE_POS = CFrame.new(-7115, -693, -2533)
local DROP_POS = CFrame.new(932, 42, -702) 

-- Зона фарма (Bounding Box)
local A, B = Vector3.new(-7184, -703, -2544), Vector3.new(-7057, -720, -2531)
local ZONE = {
    MIN = Vector3.new(math.min(A.X, B.X) - 5, math.min(A.Y, B.Y) - 5, math.min(A.Z, B.Z) - 5),
    MAX = Vector3.new(math.max(A.X, B.X) + 5, math.max(A.Y, B.Y) + 5, math.max(A.Z, B.Z) + 5)
}

local MAX_BAG = 5
local DROP_DELAY = 0.5 
-- =================================================

local plr = game.Players.LocalPlayer
local char = plr.Character or plr.CharacterAdded:Wait()
local root = char:WaitForChild("HumanoidRootPart")
local Events = game:GetService("ReplicatedStorage"):WaitForChild("Events")

local active = false
local isBusy = false 
local status = "STATUS: IDLE"
local floor = nil

-- [УТИЛИТЫ]
local function updateFloor(cf)
    if not floor then
        floor = Instance.new("Part", workspace)
        floor.Size, floor.Anchored, floor.Transparency = Vector3.new(12, 1, 12), true, 1
        floor.CanCollide = true
    end
    floor.CFrame = cf * CFrame.new(0, -3.5, 0)
end

local function isInZone(pos)
    return pos.X >= ZONE.MIN.X and pos.X <= ZONE.MAX.X and
           pos.Y >= ZONE.MIN.Y and pos.Y <= ZONE.MAX.Y and
           pos.Z >= ZONE.MIN.Z and pos.Z <= ZONE.MAX.Z
end

-- Получение данных (строгий фильтр)
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

    local oresOnMap = 0
    local availableOre = nil
    for _, v in pairs(workspace.WorldSpawn.Ores:GetChildren()) do
        if v.Name == TARGET_ORE and v:FindFirstChild("Hittable") then
            oresOnMap = oresOnMap + 1
            if not availableOre then availableOre = v end
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

    return myDrops, availableOre, bagCount, bag, bagData
end

-- Возврат на базу ожидания
local function goToIdle()
    status = "STATUS: IDLE (Transition)"
    root.CFrame = IDLE_POS
    updateFloor(IDLE_POS)
    task.wait(0.5)
end

-- ================= СЦЕНАРИИ =================

-- 1. СБОР И ВЫГРУЗКА (Единый цикл)
local function transportScenario(bag, data)
    isBusy = true
    
    -- А: Собираем что есть на полу до упора
    local myDrops = getInfo()
    if #myDrops > 0 then
        status = "STATUS: COLLECTING DROPS"
        if bag.Parent ~= char then bag.Parent = char end
        
        for i, item in ipairs(myDrops) do
            local _, _, currentBag = getInfo()
            if currentBag >= MAX_BAG then break end
            
            local p = item:FindFirstChild("Part")
            if p then
                status = "PICKING BLOCK " .. i
                root.CFrame = p.CFrame * CFrame.new(0, 3, 0)
                updateFloor(root.CFrame)
                task.wait(0.2)
                bag.Action:FireServer("Store", p)
                task.wait(0.3)
            end
        end
    end

    -- Б: Если после сбора сумка полная - летим на базу
    local _, _, finalBagCount = getInfo()
    if finalBagCount >= MAX_BAG then
        status = "STATUS: TELEPORTING TO SELL"
        goToIdle()
        root.CFrame = DROP_POS
        updateFloor(DROP_POS)
        task.wait(1.5)
        
        status = "STATUS: DUMPING ITEMS"
        local safety = 0
        while data.Value ~= "[]" and safety < 15 do
            bag.Action:FireServer("Drop")
            task.wait(DROP_DELAY)
            safety = safety + 1
        end
    end

    goToIdle()
    isBusy = false
end

-- 2. ФАРМ ОДНОЙ КУЧКИ
local function miningScenario(ore)
    isBusy = true
    status = "STATUS: MINING FULL NODE"
    
    local tool = char:FindFirstChild(TOOL_NAME) or plr.Backpack:FindFirstChild(TOOL_NAME)
    if not tool then isBusy = false return end
    if tool.Parent ~= char then tool.Parent = char end

    -- Проходим по всем частям руды (обычно их 3)
    local hitParts = ore.Hittable:GetChildren()
    for _, h in ipairs(hitParts) do
        local p = h:IsA("BasePart") and h or h:FindFirstChild("Part")
        if p then
            status = "STATUS: SWINGING AT PART"
            root.CFrame = p.CFrame * CFrame.new(0, 4, 3)
            updateFloor(root.CFrame)
            
            Events.Tools.ToolInputChanged:FireServer(tool, true)
            Events.Tools.Charge:FireServer({["Target"] = p, ["HitPosition"] = p.Position})
            task.wait(0.05)
            Events.Tools.Attack:FireServer({["Alpha"] = 1, ["ResponseTime"] = 0.4})
            Events.Tools.ToolInputChanged:FireServer(tool, false)
            task.wait(0.3)
        end
    end
    
    goToIdle()
    isBusy = false
end

-- ================= GUI =================
local sg = Instance.new("ScreenGui", game.CoreGui)
local bt = Instance.new("TextButton", sg)
bt.Size, bt.Position = UDim2.new(0, 180, 0, 50), UDim2.new(0.5, -90, 0.05, 0)
bt.Text, bt.BackgroundColor3 = "FARM: OFF", Color3.new(0.6, 0, 0)
bt.TextColor3, bt.Font, bt.TextSize = Color3.new(1,1,1), 3, 18

local log = Instance.new("TextLabel", sg)
log.Size, log.Position = UDim2.new(0, 300, 0, 140), UDim2.new(0.5, -150, 0.05, 60)
log.BackgroundColor3, log.TextColor3, log.BackgroundTransparency = Color3.new(0,0,0), Color3.new(1,1,1), 0.5
log.TextSize, log.Font = 14, 3

bt.MouseButton1Click:Connect(function()
    active = not active
    bt.Text = active and "FARM: ACTIVE" or "FARM: OFF"
    bt.BackgroundColor3 = active and Color3.new(0, 0.5, 0) or Color3.new(0.6, 0, 0)
    if not active then status = "STATUS: IDLE" if floor then floor:Destroy() floor = nil end end
end)

-- ================= ГЛАВНЫЙ ПОТОК УПРАВЛЕНИЯ =================
task.spawn(function()
    while true do
        task.wait(0.4)
        local myDrops, nextOre, inBag, bag, bagData = getInfo()
        
        log.Text = string.format(
            " %s\n ----------------------\n BAG: %d/5\n DROPS IN ZONE: %d\n ORES AVAILABLE: %s",
            status, inBag, #myDrops, nextOre and "YES" or "NO"
        )

        if active and not isBusy then
            pcall(function()
                -- ПРИОРИТЕТ 1: Выгрузка или Сбор (если есть что нести или сумка полная)
                if inBag >= MAX_BAG or #myDrops > 0 then
                    transportScenario(bag, bagData)

                -- ПРИОРИТЕТ 2: Если сумка свободна и на полу чисто - копаем ОДНУ руду
                elseif nextOre then
                    miningScenario(nextOre)

                -- ИНАЧЕ: Ждем респавна
                else
                    status = "STATUS: WAITING RESPAWN"
                    root.CFrame = IDLE_POS
                    updateFloor(IDLE_POS)
                end
            end)
        end
    end
end)

for i, v in pairs(getconnections(plr.Idled)) do v:Disable() end