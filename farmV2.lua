-- ================= CONFIGURATION =================
local TARGET_ORE = "Abyssalite"
local TOOL_NAME = "Obsidian Pickaxe"
local BAG_NAME = "Item Bag"

local IDLE_POS = CFrame.new(-7115, -693, -2533)
local DROP_POS = CFrame.new(932, 43, -702) -- Выгрузка (высота чуть поднята для безопасности)

local MAX_BAG = 5
local DROP_DELAY = 0.5 -- Задержка сервера на выброс
-- =================================================

local plr = game.Players.LocalPlayer
local char = plr.Character or plr.CharacterAdded:Wait()
local root = char:WaitForChild("HumanoidRootPart")
local Events = game:GetService("ReplicatedStorage"):WaitForChild("Events")

local active = false
local currentTask = "IDLE"
local floor = nil

-- [GUI SYSTEM]
local sg = Instance.new("ScreenGui", game.CoreGui)
local bt = Instance.new("TextButton", sg)
bt.Size, bt.Position = UDim2.new(0, 180, 0, 50), UDim2.new(0.5, -90, 0.05, 0)
bt.Text, bt.BackgroundColor3 = "AUTO-FARM: OFF", Color3.fromRGB(255, 0, 0)
bt.TextColor3, bt.Font, bt.TextSize = Color3.new(1,1,1), 3, 18

local log = Instance.new("TextLabel", sg)
log.Size, log.Position = UDim2.new(0, 320, 0, 140), UDim2.new(0.5, -160, 0.05, 60)
log.BackgroundColor3, log.TextColor3, log.BackgroundTransparency = Color3.new(0,0,0), Color3.new(1,1,1), 0.5
log.TextSize, log.Font = 16, 3
log.Text = "Waiting for Start..."

-- [HELPER FUNCTIONS]
local function updateFloor(cf)
    if not floor then
        floor = Instance.new("Part", workspace)
        floor.Size, floor.Anchored, floor.Transparency = Vector3.new(15, 1, 15), true, 0.8
        floor.Color = Color3.new(1, 0, 1)
    end
    floor.CFrame = cf * CFrame.new(0, -3.5, 0)
end

local function getStats()
    local oresOnMap = 0
    for _, v in pairs(workspace.WorldSpawn.Ores:GetChildren()) do
        if v.Name == TARGET_ORE then oresOnMap = oresOnMap + 1 end
    end

    local myDrops = 0
    local dropTable = {}
    for _, item in pairs(workspace.Grab:GetChildren()) do
        if item.Name == "MaterialPart" then
            local o = item:FindFirstChild("Owner")
            local m = item:FindFirstChild("Configuration") and item.Configuration.Data:FindFirstChild("MaterialString")
            if o and o.Value == plr and m and m.Value == TARGET_ORE then
                myDrops = myDrops + 1
                table.insert(dropTable, item)
            end
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

    return oresOnMap, myDrops, bagCount, bag, bagData
end

-- [MAIN ACTIONS]
local function sellSequence(bag, data)
    currentTask = "TELEPORTING TO BASE"
    root.CFrame = DROP_POS
    updateFloor(DROP_POS)
    task.wait(1.5) -- Ждем эмулятор
    
    currentTask = "DUMPING ITEMS"
    if bag.Parent ~= char then bag.Parent = char end
    
    local timeout = 0
    while data.Value ~= "[]" and timeout < 15 do
        bag.Action:FireServer("Drop")
        task.wait(DROP_DELAY)
        timeout = timeout + 1
    end
    currentTask = "RETURNING TO MINE"
    root.CFrame = IDLE_POS
    task.wait(1)
end

local function collectSequence(bag, drops, needed)
    currentTask = "PICKING UP LAVA"
    if bag.Parent ~= char then bag.Parent = char end
    
    for i = 1, math.min(#drops, needed) do
        local block = drops[i]
        local part = block:FindFirstChild("Part")
        if part then
            currentTask = "VACUUMING BLOCK " .. i
            root.CFrame = part.CFrame * CFrame.new(0, 3, 0)
            updateFloor(root.CFrame)
            task.wait(0.1)
            bag.Action:FireServer("Store", part)
            task.wait(0.2)
        end
    end
end

local function mineSequence(ore)
    currentTask = "MOVING TO ORE"
    local tool = char:FindFirstChild(TOOL_NAME) or plr.Backpack:FindFirstChild(TOOL_NAME)
    if not tool then return end
    if tool.Parent ~= char then tool.Parent = char end

    -- Проходим по всем Hittable частям этой конкретной руды
    for _, hittable in pairs(ore.Hittable:GetChildren()) do
        if hittable:IsA("BasePart") or hittable:FindFirstChild("Part") then
            local targetPart = hittable:IsA("BasePart") and hittable or hittable.Part
            currentTask = "SWINGING PICKAXE"
            root.CFrame = targetPart.CFrame * CFrame.new(0, 4, 3)
            updateFloor(root.CFrame)
            
            Events.Tools.ToolInputChanged:FireServer(tool, true)
            Events.Tools.Charge:FireServer({["Target"] = targetPart, ["HitPosition"] = targetPart.Position})
            task.wait(0.05)
            Events.Tools.Attack:FireServer({["Alpha"] = 1, ["ResponseTime"] = 0.4})
            Events.Tools.ToolInputChanged:FireServer(tool, false)
            task.wait(0.2)
        end
    end
end

-- [CONTROL]
bt.MouseButton1Click:Connect(function()
    active = not active
    bt.Text = active and "AUTO-FARM: ON" or "AUTO-FARM: OFF"
    bt.BackgroundColor3 = active and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
    if not active then 
        if floor then floor:Destroy() floor = nil end
        currentTask = "IDLE"
    end
end)

-- [MAIN LOOP]
task.spawn(function()
    while true do
        task.wait(0.4)
        local ores, drops, inBag, bag, bagData = getStats()
        
        -- Обновляем лог
        log.Text = string.format(
            " STATE: %s\n BAG: %d/5\n DROPS ON FLOOR: %d\n ORES IN CAVE: %d",
            currentTask, inBag, drops, ores
        )

        if active then
            pcall(function()
                -- 1. Если сумка полная - летим сдавать
                if inBag >= MAX_BAG then
                    sellSequence(bag, bagData)
                
                -- 2. Если на полу достаточно - собираем
                elseif drops >= 5 then
                    -- Собираем только сколько влезет
                    local dropList = {}
                    for _, item in pairs(workspace.Grab:GetChildren()) do
                        local o = item:FindFirstChild("Owner")
                        if o and o.Value == plr then table.insert(dropList, item) end
                    end
                    collectSequence(bag, dropList, MAX_BAG - inBag)

                -- 3. Если на полу пусто - ломаем ОДНУ руду
                else
                    local ore = workspace.WorldSpawn.Ores:FindFirstChild(TARGET_ORE)
                    if ore then
                        mineSequence(ore)
                    else
                        currentTask = "WAITING FOR RESPAWN"
                        root.CFrame = IDLE_POS
                        updateFloor(IDLE_POS)
                    end
                end
            end)
        end
    end
end)

-- Anti-Kick
for i, v in pairs(getconnections(plr.Idled)) do v:Disable() end