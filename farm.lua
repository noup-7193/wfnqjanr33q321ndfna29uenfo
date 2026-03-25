local plr = game.Players.LocalPlayer
local targetOre = "Abyssalite"
local targetTool = "Obsidian Pickaxe"
local targetBag = "Item Bag" -- Твоя сумка в руках
local basePos = Vector3.new(-7120, -680, -2531)
local maxCapacity = 5 -- Вместимость сумки

local active = false
local isMining = false
local blocksCollected = 0 -- Точный счетчик блоков в сумке
local floor = nil
local HttpService = game:GetService("HttpService") -- Для парсинга JSON (Data)

-- Глобальные события
local Events = game:GetService("ReplicatedStorage"):WaitForChild("Events")
local ChargeRem = Events.Tools.Charge
local AttackRem = Events.Tools.Attack
local InputRem = Events.Tools.ToolInputChanged
local SellPart = workspace.Map.Structures.Nova_Sellary:FindFirstChild("TalkPart")

-- GUI
local sg = Instance.new("ScreenGui", game.CoreGui)
local bt = Instance.new("TextButton", sg)
bt.Size, bt.Position = UDim2.new(0, 160, 0, 50), UDim2.new(0.5, -80, 0.1, 0)
bt.Text, bt.BackgroundColor3 = "ULTRA FARM: OFF", Color3.fromRGB(255, 0, 0)
bt.TextColor3, bt.Font, bt.TextSize = Color3.new(1,1,1), 3, 18

local log = Instance.new("TextLabel", sg)
log.Size, log.Position = UDim2.new(0, 260, 0, 60), UDim2.new(0.5, -130, 0.1, 60)
log.BackgroundColor3, log.TextColor3, log.BackgroundTransparency = Color3.new(0,0,0), Color3.new(1,1,1), 0.5
log.Text = "Bag: 0/5 | Search Obsidian Pickaxe..."

local function toggleFloor(on, pos)
    if not on and floor then floor:Destroy() floor = nil
    elseif on then
        if not floor then
            floor = Instance.new("Part", workspace)
            floor.Size, floor.Transparency, floor.Anchored = Vector3.new(10, 1, 10), 1, true
            floor.CanCollide, floor.CanQuery = true, false
        end
        floor.CFrame = pos * CFrame.new(0, -3.2, 0)
    end
end

-- АВТО-ПЫЛЕСОС (На основе твоих находок в Dex)
local function vacuumGrab()
    local char = plr.Character
    if not char then return end
    
    -- ПРОВЕРКА И ЭКИПИРОВКА СУМКИ (Чтобы была в руках)
    local bag = char:FindFirstChild(targetBag) or plr.Backpack:FindFirstChild(targetBag)
    if not bag then return end
    
    local oldTool = char:FindFirstChildOfClass("Tool")
    if oldTool and oldTool ~= bag then oldTool.Parent = plr.Backpack end
    bag.Parent = char -- Взяли сумку в руки
    task.wait(0.1)

    -- Ищем всё, что выпало в Grab
    for _, material in pairs(workspace.Grab:GetChildren()) do
        if blocksCollected < maxCapacity then
            local part = material:FindFirstChild("Part") or material:FindFirstChildOfClass("Part")
            if part and part:FindFirstChild("Data") then
                pcall(function()
                    -- ПАРСИМ JSON (Data стринг), чтобы найти Key
                    local jsonData = HttpService:JSONDecode(part.Data.Value)
                    local itemKey = jsonData and jsonData[1] and jsonData[1].Data and jsonData[1].Data.Key
                    
                    if itemKey then
                        -- МОМЕНТАЛЬНЫЙ ПОДБОР ПО КЛЮЧУ
                        bag.Action:FireServer("Store", part) -- Серверу нужен только Part, Key он читает сам
                        
                        material:Destroy() -- Удаляем на клиенте, чтобы не спамил
                        blocksCollected = blocksCollected + 1
                        log.Text = "Bag: "..blocksCollected.."/"..maxCapacity.." | Picked Up Abyssalite!"
                        task.wait(0.05)
                    end
                end)
            end
        end
    end
    
    -- Возвращаем кирку, если она была
    if oldTool then oldTool.Parent = char end
end

-- ФУНКЦИЯ ПРОДАЖИ (Flash Sell)
local function sellItems()
    local char = plr.Character
    local root = char.HumanoidRootPart
    
    -- Ищем сумку (может быть в руках или рюкзаке)
    local bag = char:FindFirstChild(targetBag) or plr.Backpack:FindFirstChild(targetBag)
    if not SellPart or not bag then return end
    
    local oldCF = root.CFrame
    log.Text = "Status: FULL! Flying to Sell..."
    
    -- Flash ТП
    root.CFrame = SellPart.CFrame * CFrame.new(0, 3, 0)
    toggleFloor(true, root.CFrame)
    task.wait(0.5)
    
    -- Выкладываем всё из сумки (несколько раз для верности)
    for i = 1, maxCapacity + 2 do
        bag.Action:FireServer("Drop")
        task.wait(0.1)
    end
    
    -- Сама продажа NPC
    SellPart.Interact:FireServer()
    task.wait(0.3)
    SellPart.Interact:FireServer("Deal", 1)
    
    task.wait(0.5)
    blocksCollected = 0
    root.CFrame = oldCF
    toggleFloor(true, root.CFrame)
    log.Text = "Status: Sold! Returning..."
end

bt.MouseButton1Click:Connect(function()
    active = not active
    bt.Text = active and "ULTRA FARM: ON" or "ULTRA FARM: OFF"
    bt.BackgroundColor3 = active and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
    if not active then toggleFloor(false) isMining = false end
end)

local function autoGetPickaxe()
    local char = plr.Character
    local t = char:FindFirstChild(targetTool) or plr.Backpack:FindFirstChild(targetTool)
    if t then
        local d = t:FindFirstChild("Configuration") and t.Configuration:FindFirstChild("Data")
        local ct = d and d:FindFirstChild("ChargeTime") and d.ChargeTime.Value or 0.4
        local cd = t.Configuration:FindFirstChild("Cooldown") and t.Configuration.Cooldown.Value or 0.5
        return t, ct, cd
    end
    return nil
end

task.spawn(function()
    while true do
        task.wait(0.1)
        if active then
            pcall(function()
                if blocksCollected >= maxCapacity then
                    sellItems()
                end

                local char = plr.Character
                local root = char.HumanoidRootPart
                local cam = workspace.CurrentCamera
                local tool, cTime, cd = autoGetPickaxe()
                
                if not tool then log.Text = "Status: Need Obsidian Pickaxe"; return end
                if tool.Parent ~= char then tool.Parent = char end

                local target = nil
                for _, v in pairs(workspace.WorldSpawn.Ores:GetChildren()) do
                    if v.Name == targetOre and v:FindFirstChild("Hittable") and v.Hittable:FindFirstChild("Part") then
                        target = v; break
                    end
                end

                if target and not isMining then
                    isMining = true
                    local realPart = target.Hittable.Part
                    local targetPos = realPart.Position
                    
                    root.CFrame = CFrame.lookAt(targetPos + Vector3.new(0, 4, 5), targetPos)
                    toggleFloor(true, root.CFrame)
                    
                    -- СУПЕР-УДАР
                    InputRem:FireServer(tool, true)
                    ChargeRem:FireServer({["Target"] = realPart, ["HitPosition"] = targetPos})
                    
                    task.wait(0.08)
                    AttackRem:FireServer({["Alpha"] = 1, ["ResponseTime"] = cTime})
                    
                    InputRem:FireServer(tool, false)
                    task.wait(math.min(cd, 0.2))
                    
                    -- ПОСЛЕ УДАРА ВРУБАЕМ ПЫЛЕСОС
                    vacuumGrab()
                    
                    isMining = false
                end
            end)
        end
    end
end)