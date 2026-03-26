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
local DROP_DELAY = 0.5 
-- =================================================

local plr = game.Players.LocalPlayer
local char = plr.Character or plr.CharacterAdded:Wait()
local root = char:WaitForChild("HumanoidRootPart")
local Events = game:GetService("ReplicatedStorage"):WaitForChild("Events")

local isBusy = false
local currentStatus = "IDLE"
local floor = nil

-- [УТИЛИТЫ]
local function updateFloor(cf)
    if not cf and floor then floor:Destroy() floor = nil return end
    if not floor then
        floor = Instance.new("Part", workspace)
        floor.Size, floor.Anchored, floor.Transparency = Vector3.new(12, 1, 12), true, 1
    end
    floor.CFrame = cf * CFrame.new(0, -3.2, 0)
end

local function isInZone(pos)
    return pos.X >= ZONE.MIN.X and pos.X <= ZONE.MAX.X and
           pos.Y >= ZONE.MIN.Y and pos.Y <= ZONE.MAX.Y and
           pos.Z >= ZONE.MIN.Z and pos.Z <= ZONE.MAX.Z
end

-- Сбор статистики (только инфа)
local function getStats()
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

    local ores = 0
    for _, v in pairs(workspace.WorldSpawn.Ores:GetChildren()) do
        if v.Name == TARGET_ORE and v:FindFirstChild("Hittable") then ores = ores + 1 end
    end

    local bagCount = 0
    local bag = char:FindFirstChild(BAG_NAME) or plr.Backpack:FindFirstChild(BAG_NAME)
    local bagData = nil
    if bag then
        bagData = bag.Configuration.Data.Stored
        local _, count = string.gsub(bagData.Value, "Key", "")
        bagCount = count
    end

    return myDrops, ores, bagCount, bag, bagData
end

-- ================= СЦЕНАРИИ (РУЧНОЙ ВЫЗОВ) =================

-- 1. МАЙНИНГ ОДНОЙ КУЧКИ
local function doMining()
    if isBusy then return end
    isBusy = true
    currentStatus = "MINING"
    
    local _, oresCount = getStats()
    local targetOre = nil
    local minDist = math.huge
    
    -- Ищем ближайшую к IDLE руду
    for _, v in pairs(workspace.WorldSpawn.Ores:GetChildren()) do
        if v.Name == TARGET_ORE and v:FindFirstChild("Hittable") and v.Hittable:FindFirstChild("Part") then
            local dist = (v.Hittable.Part.Position - IDLE_POS.Position).Magnitude
            if dist < minDist then
                minDist = dist
                targetOre = v
            end
        end
    end

    if targetOre then
        local tool = char:FindFirstChild(TOOL_NAME) or plr.Backpack:FindFirstChild(TOOL_NAME)
        if tool then
            if tool.Parent ~= char then tool.Parent = char end
            local parts = targetOre.Hittable:GetChildren()
            for _, h in ipairs(parts) do
                local p = h:IsA("BasePart") and h or h:FindFirstChild("Part")
                if p then
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
        end
    end

    root.CFrame = IDLE_POS
    updateFloor(IDLE_POS)
    task.wait(0.5)
    currentStatus = "IDLE"
    isBusy = false
end

-- 2. ТРАНСПОРТИРОВКА (1 ЦИКЛ)
local function doTransport()
    if isBusy then return end
    isBusy = true
    currentStatus = "TRANSPORTING"

    local myDrops, _, bagCount, bag, bagData = getStats()
    
    -- А. СБОР ДО ФУЛЛА (ближайшие к IDLE)
    if #myDrops > 0 and bagCount < MAX_BAG then
        if bag.Parent ~= char then bag.Parent = char end
        
        -- Сортируем по дистанции к IDLE
        table.sort(myDrops, function(a, b)
            return (a.Part.Position - IDLE_POS.Position).Magnitude < (b.Part.Position - IDLE_POS.Position).Magnitude
        end)

        for _, item in ipairs(myDrops) do
            local _, _, currentBag = getStats()
            if currentBag >= MAX_BAG then break end
            
            local p = item:FindFirstChild("Part")
            if p then
                root.CFrame = p.CFrame * CFrame.new(0, 3, 0)
                updateFloor(root.CFrame)
                task.wait(0.2)
                bag.Action:FireServer("Store", p)
                task.wait(0.35)
            end
        end
    end

    -- Б. ВЫГРУЗКА (если в сумке что-то есть)
    local _, _, finalBagCount = getStats()
    if finalBagCount > 0 then
        root.CFrame = DROP_POS
        updateFloor(DROP_POS)
        task.wait(1.5)
        
        local safety = 0
        while bagData.Value ~= "[]" and safety < 15 do
            bag.Action:FireServer("Drop")
            task.wait(DROP_DELAY)
            safety = safety + 1
        end
    end

    root.CFrame = IDLE_POS
    updateFloor(IDLE_POS)
    task.wait(0.5)
    currentStatus = "IDLE"
    isBusy = false
end

-- ================= GUI (2 КНОПКИ + СТАТУС) =================
local sg = Instance.new("ScreenGui", game.CoreGui)
local frame = Instance.new("Frame", sg)
frame.Size, frame.Position = UDim2.new(0, 220, 0, 240), UDim2.new(0.02, 0, 0.4, 0)
frame.BackgroundColor3, frame.BorderSizePixel = Color3.new(0.1,0.1,0.1), 0

local statLab = Instance.new("TextLabel", frame)
statLab.Size, statLab.Position = UDim2.new(1, 0, 0, 100), UDim2.new(0,0,0,0)
statLab.BackgroundColor3, statLab.TextColor3 = Color3.new(0.15,0.15,0.15), Color3.new(1,1,1)
statLab.TextSize, statLab.Font = 14, 3
statLab.Text = "Loading..."

local btnMine = Instance.new("TextButton", frame)
btnMine.Size, btnMine.Position = UDim2.new(0.9, 0, 0, 50), UDim2.new(0.05, 0, 0.45, 0)
btnMine.Text, btnMine.BackgroundColor3 = "MINE 1 NODE", Color3.new(0.2, 0.4, 0.2)
btnMine.TextColor3, btnMine.Font, btnMine.TextSize = Color3.new(1,1,1), 3, 16

local btnTrans = Instance.new("TextButton", frame)
btnTrans.Size, btnTrans.Position = UDim2.new(0.9, 0, 0, 50), UDim2.new(0.05, 0, 0.7, 0)
btnTrans.Text, btnTrans.BackgroundColor3 = "TRANSPORT 1 RUN", Color3.new(0.2, 0.2, 0.4)
btnTrans.TextColor3, btnTrans.Font, btnTrans.TextSize = Color3.new(1,1,1), 3, 16

btnMine.MouseButton1Click:Connect(function() 
    if not isBusy then task.spawn(doMining) end 
end)
btnTrans.MouseButton1Click:Connect(function() 
    if not isBusy then task.spawn(doTransport) end 
end)

-- [ОБНОВЛЕНИЕ GUI И ПОДДЕРЖКА IDLE]
task.spawn(function()
    while true do
        task.wait(0.3)
        local myDrops, ores, bagC = getStats()
        
        statLab.Text = string.format(
            " STATUS: %s\n ------------------\n BAG: %d/%d\n DROPS IN ZONE: %d\n ORES ON MAP: %d",
            currentStatus, bagC, MAX_BAG, #myDrops, ores
        )
        
        -- Если ничего не делаем - стоим на базе
        if not isBusy then
            if (root.Position - IDLE_POS.Position).Magnitude > 5 then
                root.CFrame = IDLE_POS
                updateFloor(IDLE_POS)
            end
        end
    end
end)

for i, v in pairs(getconnections(plr.Idled)) do v:Disable() end