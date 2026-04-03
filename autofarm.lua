-- ================= ЗАЩИТА ОТ ДВОЙНОГО ЗАПУСКА =================
if _G.MyFarmActive then
    _G.MyFarmActive = false
    task.wait(0.5) -- Ждем, пока старый цикл умрет
end
_G.MyFarmActive = true

-- Удаляем старое GUI, если оно висит на экране
if game.CoreGui:FindFirstChild("FarmGUI_Auto") then
    game.CoreGui.FarmGUI_Auto:Destroy()
end
-- ==============================================================

local plr = game.Players.LocalPlayer
local targetOre = "Abyssalite"
local targetTool = "Obsidian Pickaxe"
local BAG_NAME = "Item Bag"

local basePos = Vector3.new(-7120, -680, -2530)
local dropPos = CFrame.new(932, 42, -702) 

local A, B = Vector3.new(-7184, -703, -2544), Vector3.new(-7057, -720, -2531)
local padding = 50 
local SAFE_MIN_Y = -730 

local ZONE = {
    MIN = Vector3.new(math.min(A.X, B.X) - padding, SAFE_MIN_Y, math.min(A.Z, B.Z) - padding),
    MAX = Vector3.new(math.max(A.X, B.X) + padding, math.huge, math.max(A.Z, B.Z) + padding)
}

local MAX_BAG = 5
local DROP_DELAY = 0.5 

local active = false
local floor = nil

local Events = game:GetService("ReplicatedStorage"):WaitForChild("Events")
local ChargeRem = Events.Tools.Charge
local AttackRem = Events.Tools.Attack
local InputRem = Events.Tools.ToolInputChanged

local sg = Instance.new("ScreenGui", game.CoreGui)
sg.Name = "FarmGUI_Auto" -- Дали имя, чтобы удалять при перезапуске
local bt = Instance.new("TextButton", sg)
bt.Size, bt.Position = UDim2.new(0, 160, 0, 50), UDim2.new(0.5, -80, 0.1, 0)
bt.Text, bt.BackgroundColor3 = "FULL AUTO: OFF", Color3.fromRGB(255, 0, 0)
bt.TextColor3, bt.Font, bt.TextSize = Color3.new(1,1,1), 3, 18

local log = Instance.new("TextLabel", sg)
log.Size, log.Position = UDim2.new(0, 260, 0, 80), UDim2.new(0.5, -130, 0.1, 60)
log.BackgroundColor3, log.TextColor3, log.BackgroundTransparency = Color3.new(0,0,0), Color3.new(1,1,1), 0.5
log.TextSize = 14
log.Text = "Status: Waiting for start"

local function toggleFloor(on, pos)
    if not on and floor then floor:Destroy() floor = nil
    elseif on then
        if not floor then
            floor = Instance.new("Part", workspace)
            floor.Size, floor.Transparency, floor.Anchored = Vector3.new(15, 1, 15), 1, true
            floor.CanCollide, floor.CanQuery = true, false
        end
        floor.CFrame = pos * CFrame.new(0, -3.2, 0)
    end
end

bt.MouseButton1Click:Connect(function()
    active = not active
    bt.Text = active and "FULL AUTO: ON" or "FULL AUTO: OFF"
    bt.BackgroundColor3 = active and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
    if not active then toggleFloor(false) end
end)

local function autoGetTool()
    local char = plr.Character
    if not char then return nil end
    local t = char:FindFirstChild(targetTool) or plr.Backpack:FindFirstChild(targetTool)
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

local function isInZone(pos)
    return pos.X >= ZONE.MIN.X and pos.X <= ZONE.MAX.X and 
           pos.Y >= ZONE.MIN.Y and 
           pos.Z >= ZONE.MIN.Z and pos.Z <= ZONE.MAX.Z
end

local function getStats()
    local myDrops = {}
    for _, item in pairs(workspace.Grab:GetChildren()) do
        if item.Name == "MaterialPart" then
            local p = item:FindFirstChild("Part")
            local o = item:FindFirstChild("Owner")
            local config = item:FindFirstChild("Configuration")
            local data = config and config:FindFirstChild("Data")
            local m = data and data:FindFirstChild("MaterialString")
            
            if p and o and m then
                local isMine = (typeof(o.Value) == "Instance" and o.Value == plr) or tostring(o.Value) == plr.Name
                if isMine and m.Value == targetOre and isInZone(p.Position) then
                    table.insert(myDrops, item)
                end
            end
        end
    end

    local oresCount = 0
    for _, v in pairs(workspace.WorldSpawn.Ores:GetChildren()) do
        if v.Name == targetOre and v:FindFirstChild("Hittable") then
            oresCount = oresCount + #v.Hittable:GetChildren()
        end
    end

    local bagCount = 0
    local bag = plr.Character:FindFirstChild(BAG_NAME) or plr.Backpack:FindFirstChild(BAG_NAME)
    local bagData = nil
    if bag then
        bagData = bag.Configuration.Data.Stored
        local _, count = string.gsub(bagData.Value, "Key", "")
        bagCount = count
    end

    return myDrops, oresCount, bagCount, bag, bagData
end

task.spawn(function()
    while _G.MyFarmActive do
        task.wait(0.1)
        if active then
            local success, err = pcall(function()
                local root = plr.Character.HumanoidRootPart
                local cam = workspace.CurrentCamera
                local tool, cTime, cd = autoGetTool()
                
                if not tool then log.Text = "Status: No Pickaxe found!"; return end
                
                local myDrops, oresCount, bagCount, bag, bagData = getStats()
                local currentAction = ""

                -- ================== 1. ВЫГРУЗКА И ПРОДАЖА ==================
                if bagCount >= MAX_BAG then
                    currentAction = "Selling Ores"
                    log.Text = string.format("Bag: %d/5 | Drops: %d | Ores: %d\n%s", bagCount, #myDrops, oresCount, currentAction)
                    
                    InputRem:FireServer(tool, false)
                    
                    local structures = workspace:WaitForChild("Map"):WaitForChild("Structures")
                    local sellArea = structures:WaitForChild("Nova_Sellary"):WaitForChild("SellZone"):WaitForChild("Area")
                    local talkPart = structures.Nova_Sellary:WaitForChild("TalkPart")

                    local safeX = (sellArea.Size.X / 2) - 8
                    local safeZ = (sellArea.Size.Z / 2) - 8
                    local dropCFrame = sellArea.CFrame * CFrame.new(math.random(-safeX, safeX), 5, math.random(-safeZ, safeZ))
                    
                    root.CFrame = dropCFrame
                    toggleFloor(true, root.CFrame)
                    task.wait(math.random(4, 7) / 10) 
                    
                    if bag.Parent ~= plr.Character then bag.Parent = plr.Character end
                    
                    local safety = 0
                    while bagData.Value ~= "[]" and safety < 15 do
                        bag.Action:FireServer("Drop")
                        task.wait(DROP_DELAY)
                        safety = safety + 1
                    end
                    
                    task.wait(math.random(10, 15) / 10)

                    root.CFrame = talkPart.CFrame * CFrame.new(math.random(-3, 3), 0, math.random(-3, 3))
                    toggleFloor(true, root.CFrame)
                    task.wait(math.random(5, 9) / 10)

                    if talkPart:FindFirstChild("Interact") then
                        talkPart.Interact:FireServer("Deal", 1)
                    end
                    
                    task.wait(math.random(8, 12) / 10)
                    
                    root.CFrame = CFrame.new(basePos)
                    toggleFloor(true, root.CFrame)
                    task.wait(0.5)

                -- ================== 2. СБОР РУДЫ ==================
                elseif #myDrops >= 5 or (#myDrops > 0 and bagCount + #myDrops >= MAX_BAG) then
                    currentAction = "Collecting Drops"
                    if bag.Parent ~= plr.Character then bag.Parent = plr.Character end
                    
                    for _, item in ipairs(myDrops) do
                        local _, _, cBag = getStats()
                        if cBag >= MAX_BAG then break end
                        
                        local p = item:FindFirstChild("Part")
                        if p then
                            root.CFrame = p.CFrame * CFrame.new(0, 3, 0)
                            toggleFloor(true, root.CFrame)
                            task.wait(0.1)
                            bag.Action:FireServer("Store", p)
                            task.wait(0.3)
                        end
                    end

                -- ================== 3. ФАРМ ==================
                else
                    if tool.Parent ~= plr.Character then tool.Parent = plr.Character end 
                    
                    local target = nil
                    for _, v in pairs(workspace.WorldSpawn.Ores:GetChildren()) do
                        if v.Name == targetOre and v:FindFirstChild("Hittable") and v.Hittable:FindFirstChild("Part") then
                            target = v; break
                        end
                    end

                    if target then
                        currentAction = "Mining: " .. targetOre
                        local realPart = target.Hittable.Part
                        local targetPos = realPart.Position
                        
                        local lookCF = CFrame.lookAt(targetPos + Vector3.new(0, 4, 5), targetPos)
                        root.CFrame = lookCF
                        cam.CFrame = CFrame.lookAt(cam.CFrame.Position, targetPos)
                        toggleFloor(true, root.CFrame)
                        
                        InputRem:FireServer(tool, true)
                        local chargeData = {["Target"] = realPart, ["HitPosition"] = targetPos}
                        ChargeRem:FireServer(chargeData)
                        task.wait(0.02)
                        ChargeRem:FireServer(chargeData)
                        
                        task.wait(math.random(7, 12) / 100)
                        
                        AttackRem:FireServer({
                            ["Alpha"] = 1, 
                            ["ResponseTime"] = cTime
                        })
                        InputRem:FireServer(tool, false)
                        task.wait(math.min(cd, 0.2))
                    else
                        currentAction = "Searching " .. targetOre .. "..."
                        if oresCount == 0 and (root.Position - basePos).Magnitude > 20 then
                            root.CFrame = CFrame.new(basePos)
                            toggleFloor(true, root.CFrame)
                        end
                    end
                end

                log.Text = string.format("Bag: %d/5 | Drops: %d | Ores: %d\n%s", bagCount, #myDrops, oresCount, currentAction)
            end)
            
            -- Если случилась ошибка, выводим её в консоль экзекутора
            if not success then
                warn("FARM ERROR: ", err)
            end
        end
    end
end)

local ScreenGui = Instance.new("ScreenGui", game:GetService("CoreGui"))
local ToggleBtn = Instance.new("TextButton", ScreenGui)

ToggleBtn.Size = UDim2.new(0, 100, 0, 40)
ToggleBtn.Position = UDim2.new(0, 10, 0, 10)
ToggleBtn.Text = "OPTIMIZE: OFF"
ToggleBtn.BackgroundColor3 = Color3.fromRGB(200, 0, 0)

local Optimized = false

ToggleBtn.MouseButton1Click:Connect(function()
    Optimized = not Optimized
    
    if Optimized then
        -- ВКЛЮЧАЕМ ОПТИМИЗАЦИЮ
        ToggleBtn.Text = "OPTIMIZE: ON"
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
        
        game:GetService("RunService"):Set3dRenderingEnabled(false) -- Выключаем 3D мир
        settings().Physics.PhysicsEnvironmentalThrottle = Enum.EnviromentalPhysicsThrottle.Always
        
        -- Глушим звуки (не удаляя)
        for _, v in pairs(game:GetDescendants()) do
            if v:IsA("Sound") then v.Volume = 0 end
        end
    else
        -- ВЫКЛЮЧАЕМ (ВОЗВРАЩАЕМ КАК БЫЛО)
        ToggleBtn.Text = "OPTIMIZE: OFF"
        ToggleBtn.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
        
        game:GetService("RunService"):Set3dRenderingEnabled(true) -- Включаем 3D мир
        settings().Physics.PhysicsEnvironmentalThrottle = Enum.EnviromentalPhysicsThrottle.Default
        
        -- Возвращаем звуки (примерно на среднюю громкость)
        for _, v in pairs(game:GetDescendants()) do
            if v:IsA("Sound") then v.Volume = 0.5 end
        end
    end
end)