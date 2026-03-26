-- ================= CONFIGURATION =================
local TARGET_ORE = "Abyssalite"
local TOOL_NAME = "Obsidian Pickaxe"
local BAG_NAME = "Item Bag"

local IDLE_POS = CFrame.new(-7115, -693, -2533)
local DROP_POS = CFrame.new(932, 40, -702) 

-- Зона фарма (Bounding Box)
local A, B = Vector3.new(-7213, -664, -2580), Vector3.new(-7016, -830, -2478)
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
        floor.CanCollide = true
    end
    floor.CFrame = cf * CFrame.new(0, -3.2, 0)
end

local function isInZone(pos)
    return pos.X >= ZONE.MIN.X and pos.X <= ZONE.MAX.X and
           pos.Y >= ZONE.MIN.Y and pos.Y <= ZONE.MAX.Y and
           pos.Z >= ZONE.MIN.Z and pos.Z <= ZONE.MAX.Z
end

-- Поиск кирки (твой метод)
local function autoGetTool()
    local t = char:FindFirstChild(TOOL_NAME) or plr.Backpack:FindFirstChild(TOOL_NAME)
    if not t then
        for _, item in pairs(plr.Backpack:GetChildren()) do
            if item:IsA("Tool") and item.Name:lower():find("pickaxe") then t = item; break end
        end
    end
    if t then
        local d = t:FindFirstChild("Configuration") and t.Configuration:FindFirstChild("Data")
        local ct = d and d:FindFirstChild("ChargeTime") and d.ChargeTime.Value or 0.4
        local cd = t.Configuration:FindFirstChild("Cooldown") and t.Configuration.Cooldown.Value or 0.5
        return t, ct, cd
    end
    return nil
end

-- Сбор статистики
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

-- ================= СЦЕНАРИИ =================

-- 1. МАЙНИНГ ОДНОЙ КУЧКИ (Полный цикл)
local function doMining()
    if isBusy then return end
    isBusy = true
    currentStatus = "MINING"
    
    local tool, cTime, cd = autoGetTool()
    if not tool then 
        isBusy = false 
        currentStatus = "IDLE (No Tool)" 
        return 
    end

    -- Ищем ближайшую кучку к IDLE
    local targetOre = nil
    local minDist = math.huge
    for _, v in pairs(workspace.WorldSpawn.Ores:GetChildren()) do
        if v.Name == TARGET_ORE and v:FindFirstChild("Hittable") and v.Hittable:FindFirstChild("Part") then
            local dist = (v.Hittable.Part.Position - IDLE_POS.Position).Magnitude
            if dist < minDist then
                minDist = dist
                targetOre = v
            end
        end
    end

    if targetOre and targetOre:FindFirstChild("Hittable") then
        if tool.Parent ~= char then tool.Parent = char end
        
        -- Разбиваем ВСЕ части этой кучки
        local nodes = targetOre.Hittable:GetChildren()
        for _, node in ipairs(nodes) do
            local p = node:IsA("BasePart") and node or node:FindFirstChild("Part")
            if p then
                -- ТП к конкретной части
                root.CFrame = p.CFrame * CFrame.new(0, 4, 5)
                updateFloor(root.CFrame)
                task.wait(0.05)
                
                -- Твой рабочий метод удара
                Events.Tools.ToolInputChanged:FireServer(tool, true)
                local chargeData = {["Target"] = p, ["HitPosition"] = p.Position}
                Events.Tools.Charge:FireServer(chargeData)
                task.wait(0.02)
                Events.Tools.Charge:FireServer(chargeData)
                
                task.wait(math.random(7, 12) / 100)
                
                Events.Tools.Attack:FireServer({
                    ["Alpha"] = 1, 
                    ["ResponseTime"] = cTime
                })
                
                Events.Tools.ToolInputChanged:FireServer(tool, false)
                task.wait(math.min(cd, 0.3)) -- Задержка между частями
            end
        end
    end

    -- Возврат
    root.CFrame = IDLE_POS
    updateFloor(IDLE_POS)
    task.wait(0.5)
    currentStatus = "IDLE"
    isBusy = false
end

-- 2. ТРАНСПОРТИРОВКА (Полный цикл)
local function doTransport()
    if isBusy then return end
    isBusy = true
    currentStatus = "TRANSPORTING"

    local myDrops, _, bagCount, bag, bagData = getStats()
    
    -- А. Сбор до 5 штук (ближайшие к IDLE)
    if #myDrops > 0 and bagCount < MAX_BAG then
        if bag.Parent ~= char then bag.Parent = char end
        
        table.sort(myDrops, function(a, b)
            return (a.Part.Position - IDLE_POS.Position).Magnitude < (b.Part.Position - IDLE_POS.Position).Magnitude
        end)

        for _, item in ipairs(myDrops) do
            local _, _, cBag = getStats()
            if cBag >= MAX_BAG then break end
            
            local p = item:FindFirstChild("Part")
            if p then
                root.CFrame = p.CFrame * CFrame.new(0, 3, 0)
                updateFloor(root.CFrame)
                task.wait(0.2)
                bag.Action:FireServer("Store", p)
                task.wait(0.4)
            end
        end
    end

    -- Б. Выгрузка если сумка полная (или просто не пустая)
    local _, _, finalCount = getStats()
    if finalCount > 0 then
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

-- ================= GUI =================
local sg = Instance.new("ScreenGui", game.CoreGui)
local frame = Instance.new("Frame", sg)
frame.Size, frame.Position = UDim2.new(0, 220, 0, 240), UDim2.new(0.02, 0, 0.4, 0)
frame.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)

local statLab = Instance.new("TextLabel", frame)
statLab.Size, statLab.Position = UDim2.new(1, 0, 0, 100), UDim2.new(0,0,0,0)
statLab.TextColor3, statLab.BackgroundTransparency = Color3.new(1,1,1), 1
statLab.TextSize, statLab.Font = 14, 3
statLab.Text = "Updating..."

local btnMine = Instance.new("TextButton", frame)
btnMine.Size, btnMine.Position = UDim2.new(0.9, 0, 0, 50), UDim2.new(0.05, 0, 0.45, 0)
btnMine.Text = "MINE 1 NODE"
btnMine.BackgroundColor3 = Color3.new(0.2, 0.5, 0.2)
btnMine.TextColor3, btnMine.Font, btnMine.TextSize = Color3.new(1,1,1), 3, 16

local btnTrans = Instance.new("TextButton", frame)
btnTrans.Size, btnTrans.Position = UDim2.new(0.9, 0, 0, 50), UDim2.new(0.05, 0, 0.7, 0)
btnTrans.Text = "TRANSPORT 1 RUN"
btnTrans.BackgroundColor3 = Color3.new(0.2, 0.2, 0.5)
btnTrans.TextColor3, btnTrans.Font, btnTrans.TextSize = Color3.new(1,1,1), 3, 16

btnMine.MouseButton1Click:Connect(function() if not isBusy then task.spawn(doMining) end end)
btnTrans.MouseButton1Click:Connect(function() if not isBusy then task.spawn(doTransport) end end)

-- [ГЛАВНЫЙ ПОТОК]
task.spawn(function()
    while true do
        task.wait(0.3)
        local myDrops, ores, bagC = getStats()
        statLab.Text = string.format(
            " STATUS: %s\n ------------------\n BAG: %d/%d\n DROPS IN ZONE: %d\n ORES ON MAP: %d",
            currentStatus, bagC, MAX_BAG, #myDrops, ores
        )
        
        if not isBusy then
            if (root.Position - IDLE_POS.Position).Magnitude > 5 then
                root.CFrame = IDLE_POS
                updateFloor(IDLE_POS)
            end
        end
    end
end)

for i, v in pairs(getconnections(plr.Idled)) do v:Disable() end