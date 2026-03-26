-- ================= CONFIGURATION =================
local TARGET_ORE = "Abyssalite"
local TOOL_NAME = "Obsidian Pickaxe"
local BAG_NAME = "Item Bag"

local IDLE_POS = CFrame.new(-7115, -693, -2533)
local DROP_POS = CFrame.new(932, 42, -702) 

-- Зона фарма (увеличенная коробка)
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
local isBusy = false -- ПРЕДОХРАНИТЕЛЬ ОТ ПРЕРЫВАНИЙ
local status = "OFF"
local floor = nil

-- [УТИЛИТЫ]
local function updateFloor(cf)
    if not floor then
        floor = Instance.new("Part", workspace)
        floor.Size, floor.Anchored, floor.Transparency = Vector3.new(12, 1, 12), true, 0.8
        floor.Color = Color3.new(0, 1, 1)
    end
    floor.CFrame = cf * CFrame.new(0, -3.2, 0)
end

local function isInZone(pos)
    return pos.X >= ZONE.MIN.X and pos.X <= ZONE.MAX.X and
           pos.Y >= ZONE.MIN.Y and pos.Y <= ZONE.MAX.Y and
           pos.Z >= ZONE.MIN.Z and pos.Z <= ZONE.MAX.Z
end

-- Сбор данных (только свои и только Абиссалит)
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

    local ores = 0
    for _, v in pairs(workspace.WorldSpawn.Ores:GetChildren()) do
        if v.Name == TARGET_ORE then ores = ores + 1 end
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

-- [СЦЕНАРИЙ: ТЕЛЕПОРТ НА IDLE]
local function goToIdle()
    status = "STATUS: IDLE (Transitioning)"
    root.CFrame = IDLE_POS
    updateFloor(IDLE_POS)
    task.wait(0.5)
end

-- [СЦЕНАРИЙ: ВЫГРУЗКА]
local function transportItems(bag, data)
    isBusy = true
    goToIdle()
    
    status = "STATUS: TRAVELING TO BASE"
    root.CFrame = DROP_POS
    updateFloor(DROP_POS)
    task.wait(1.5) -- Ждем лаг эмулятора
    
    if bag.Parent ~= char then bag.Parent = char end
    
    status = "STATUS: DUMPING BAG"
    local safety = 0
    while data.Value ~= "[]" and safety < 15 do
        bag.Action:FireServer("Drop")
        task.wait(DROP_DELAY)
        safety = safety + 1
    end
    
    goToIdle()
    isBusy = false
end

-- [СЦЕНАРИЙ: СБОР]
local function collectDrops(dropList, needed)
    isBusy = true
    status = "STATUS: GATHERING DROPS"
    
    local bag = char:FindFirstChild(BAG_NAME) or plr.Backpack:FindFirstChild(BAG_NAME)
    if bag.Parent ~= char then bag.Parent = char end
    
    for i = 1, math.min(#dropList, needed) do
        local block = dropList[i]
        local part = block:FindFirstChild("Part")
        if part then
            status = "STATUS: PICKING " .. i .. "/" .. needed
            root.CFrame = part.CFrame * CFrame.new(0, 3, 0)
            updateFloor(root.CFrame)
            task.wait(0.2)
            bag.Action:FireServer("Store", part)
            task.wait(0.3) -- Пауза чтобы сервер успел "съесть" блок
        end
    end
    
    goToIdle()
    isBusy = false
end

-- [СЦЕНАРИЙ: КОПКА]
local function mineOneOre(ore)
    isBusy = true
    status = "STATUS: MINING ORE NODE"
    
    local tool = char:FindFirstChild(TOOL_NAME) or plr.Backpack:FindFirstChild(TOOL_NAME)
    if not tool then isBusy = false return end
    if tool.Parent ~= char then tool.Parent = char end

    -- Проходим по всем Hittable частям этой ОДНОЙ руды
    local parts = ore.Hittable:GetChildren()
    for _, h in pairs(parts) do
        if h:IsA("BasePart") or h:FindFirstChild("Part") then
            local p = h:IsA("BasePart") and h or h.Part
            status = "STATUS: SWINGING PICKAXE"
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

-- [GUI]
local sg = Instance.new("ScreenGui", game.CoreGui)
local bt = Instance.new("TextButton", sg)
bt.Size, bt.Position = UDim2.new(0, 180, 0, 50), UDim2.new(0.5, -90, 0.05, 0)
bt.Text, bt.BackgroundColor3 = "SYSTEM: OFF", Color3.fromRGB(255, 0, 0)
bt.TextColor3, bt.Font, bt.TextSize = Color3.new(1,1,1), 3, 18

local log = Instance.new("TextLabel", sg)
log.Size, log.Position = UDim2.new(0, 300, 0, 140), UDim2.new(0.5, -150, 0.05, 60)
log.BackgroundColor3, log.TextColor3, log.BackgroundTransparency = Color3.new(0,0,0), Color3.new(1,1,1), 0.5
log.TextSize, log.Font = 15, 3

bt.MouseButton1Click:Connect(function()
    active = not active
    bt.Text = active and "SYSTEM: ACTIVE" or "SYSTEM: OFF"
    bt.BackgroundColor3 = active and Color3.new(0,1,0) or Color3.new(1,0,0)
    if not active then status = "OFF" if floor then floor:Destroy() floor = nil end end
end)

-- [ГЛАВНЫЙ ЦИКЛ УПРАВЛЕНИЯ]
task.spawn(function()
    while true do
        task.wait(0.3)
        local drops, mapOres, inBag, bag, bagData = getInfo()
        
        log.Text = string.format(
            " %s\n ----------------------\n BAG: %d/5\n DROPS IN ZONE: %d\n ORES ON MAP: %d",
            status, inBag, #drops, mapOres
        )

        if active and not isBusy then
            pcall(function()
                -- 1. Сначала проверяем сумку
                if inBag >= MAX_BAG then
                    transportItems(bag, bagData)
                
                -- 2. Затем проверяем, нужно ли собирать то, что УЖЕ лежит
                elseif #drops >= 1 and inBag < MAX_BAG then
                    collectDrops(drops, MAX_BAG - inBag)

                -- 3. Если сумка не полная и на полу пусто - копаем
                else
                    local ore = workspace.WorldSpawn.Ores:FindFirstChild(TARGET_ORE)
                    if ore then
                        mineOneOre(ore)
                    else
                        status = "STATUS: WAITING FOR RESPAWN"
                        root.CFrame = IDLE_POS
                        updateFloor(IDLE_POS)
                    end
                end
            end)
        end
    end
end)

for i, v in pairs(getconnections(plr.Idled)) do v:Disable() end