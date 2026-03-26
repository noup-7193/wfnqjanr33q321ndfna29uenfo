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
-- =================================================

local plr = game.Players.LocalPlayer
local char = plr.Character or plr.CharacterAdded:Wait()
local root = char:WaitForChild("HumanoidRootPart")
local Events = game:GetService("ReplicatedStorage"):WaitForChild("Events")

local active = false
local isBusy = false 
local statusText = "IDLE"
local floor = nil

-- [УТИЛИТЫ]
local function isInZone(pos)
    return pos.X >= ZONE.MIN.X and pos.X <= ZONE.MAX.X and
           pos.Y >= ZONE.MIN.Y and pos.Y <= ZONE.MAX.Y and
           pos.Z >= ZONE.MIN.Z and pos.Z <= ZONE.MAX.Z
end

local function toggleFloor(cf)
    if not cf and floor then floor:Destroy() floor = nil return end
    if not floor then
        floor = Instance.new("Part", workspace)
        floor.Size, floor.Anchored, floor.Transparency = Vector3.new(12, 1, 12), true, 1
    end
    floor.CFrame = cf * CFrame.new(0, -3.2, 0)
end

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

    local firstOre = nil
    local minDist = math.huge
    for _, v in pairs(workspace.WorldSpawn.Ores:GetChildren()) do
        if v.Name == TARGET_ORE and v:FindFirstChild("Hittable") and v.Hittable:FindFirstChild("Part") then
            local d = (v.Hittable.Part.Position - IDLE_POS.Position).Magnitude
            if d < minDist then minDist = d; firstOre = v end
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

-- [СЦЕНАРИЙ 1: МАЙНИНГ ОДНОЙ КУЧКИ (ТВОЙ КОД)]
local function miningScenario(ore)
    isBusy = true
    statusText = "MINING"
    
    local tool = char:FindFirstChild(TOOL_NAME) or plr.Backpack:FindFirstChild(TOOL_NAME)
    if not tool then isBusy = false return end
    if tool.Parent ~= char then tool.Parent = char end

    -- Находим данные кирки
    local config = tool:FindFirstChild("Configuration") and tool.Configuration:FindFirstChild("Data")
    local cTime = config and config:FindFirstChild("ChargeTime") and config.ChargeTime.Value or 0.4
    local cd = config and config:FindFirstChild("Cooldown") and config.Cooldown.Value or 0.5

    -- Ломаем ВСЕ части этой руды
    local nodes = ore.Hittable:GetChildren()
    for _, node in ipairs(nodes) do
        local p = node:IsA("BasePart") and node or node:FindFirstChild("Part")
        if p then
            root.CFrame = CFrame.lookAt(p.Position + Vector3.new(0, 4, 5), p.Position)
            toggleFloor(root.CFrame)
            
            Events.Tools.ToolInputChanged:FireServer(tool, true)
            local chargeData = {["Target"] = p, ["HitPosition"] = p.Position}
            Events.Tools.Charge:FireServer(chargeData)
            task.wait(0.02)
            Events.Tools.Charge:FireServer(chargeData)
            
            task.wait(math.random(7, 12) / 100)
            
            Events.Tools.Attack:FireServer({["Alpha"] = 1, ["ResponseTime"] = cTime})
            Events.Tools.ToolInputChanged:FireServer(tool, false)
            task.wait(math.min(cd, 0.3))
        end
    end

    root.CFrame = IDLE_POS
    toggleFloor(IDLE_POS)
    task.wait(0.5)
    isBusy = false
end

-- [СЦЕНАРИЙ 2: ПЕРЕНОСКА (ОБРАБОТКА ДРОПА)]
local function transportScenario(drops, bag, data)
    isBusy = true
    statusText = "TRANSPORTING"
    
    if bag.Parent ~= char then bag.Parent = char end

    -- Сортируем дроп по дистанции к нам, чтобы не летать зигзагами
    table.sort(drops, function(a, b)
        return (a.Part.Position - root.Position).Magnitude < (b.Part.Position - root.Position).Magnitude
    end)

    -- 1. Собираем всё что можем (до 5 штук)
    for _, item in ipairs(drops) do
        local _, _, bagCount = getStats()
        if bagCount >= MAX_BAG then break end
        
        local p = item:FindFirstChild("Part")
        if p then
            root.CFrame = p.CFrame * CFrame.new(0, 3, 0)
            toggleFloor(root.CFrame)
            task.wait(0.2)
            bag.Action:FireServer("Store", p)
            task.wait(0.4)
        end
    end

    -- 2. Если в сумке есть хоть 1 предмет - везем продавать
    local _, _, finalBag = getStats()
    if finalBag > 0 then
        root.CFrame = DROP_POS
        toggleFloor(DROP_POS)
        task.wait(1.5)
        
        local safety = 0
        while data.Value ~= "[]" and safety < 15 do
            bag.Action:FireServer("Drop")
            task.wait(0.5)
            safety = safety + 1
        end
    end

    root.CFrame = IDLE_POS
    toggleFloor(IDLE_POS)
    task.wait(0.5)
    isBusy = false
end

-- [GUI]
local sg = Instance.new("ScreenGui", game.CoreGui)
local bt = Instance.new("TextButton", sg)
bt.Size, bt.Position = UDim2.new(0, 160, 0, 50), UDim2.new(0.5, -80, 0.1, 0)
bt.Text, bt.BackgroundColor3 = "FULL AUTO: OFF", Color3.fromRGB(255, 0, 0)
bt.TextColor3, bt.Font, bt.TextSize = Color3.new(1,1,1), 3, 18

local log = Instance.new("TextLabel", sg)
log.Size, log.Position = UDim2.new(0, 250, 0, 120), UDim2.new(0.5, -125, 0.1, 60)
log.BackgroundColor3, log.TextColor3, log.BackgroundTransparency = Color3.new(0,0,0), Color3.new(1,1,1), 0.5
log.TextSize = 14

bt.MouseButton1Click:Connect(function()
    active = not active
    bt.Text = active and "FULL AUTO: ON" or "FULL AUTO: OFF"
    bt.BackgroundColor3 = active and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
    if not active then statusText = "IDLE" toggleFloor(nil) end
end)

-- [ГЛАВНЫЙ ЦИКЛ]
task.spawn(function()
    while true do
        task.wait(0.2)
        local myDrops, nextOre, bagCount, bag, bagData = getStats()
        
        log.Text = string.format(
            " STATUS: %s\n BAG: %d/%d\n DROPS ON FLOOR: %d\n ORES ON MAP: %d",
            isBusy and statusText or "WAITING", 
            bagCount, MAX_BAG, #myDrops, nextOre and 1 or 0
        )

        if active and not isBusy then
            pcall(function()
                -- УСЛОВИЕ 1: Если на полу >= 5 блоков ИЛИ сумка не пуста - возим
                if #myDrops >= 5 or bagCount > 0 then
                    transportScenario(myDrops, bag, bagData)
                
                -- УСЛОВИЕ 2: Если на полу мало блоков - копаем 1 кучку
                elseif nextOre then
                    miningScenario(nextOre)
                
                -- Иначе стоим на IDLE
                else
                    root.CFrame = IDLE_POS
                    toggleFloor(IDLE_POS)
                end
            end)
        end
    end
end)