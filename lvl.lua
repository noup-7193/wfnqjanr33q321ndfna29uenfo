local plr = game.Players.LocalPlayer
local targetOres = {"Stone", "Iron", "Copper", "Granite", "Marble", "Silver"}
local basePos = Vector3.new(857, 48, -841)

local active = false
local isMining = false
local floor = nil

-- События
local Events = game:GetService("ReplicatedStorage"):WaitForChild("Events")
local ChargeRem = Events.Tools.Charge
local AttackRem = Events.Tools.Attack
local InputRem = Events.Tools.ToolInputChanged

-- GUI
local sg = Instance.new("ScreenGui", game.CoreGui)
local bt = Instance.new("TextButton", sg)
bt.Size, bt.Position = UDim2.new(0, 180, 0, 50), UDim2.new(0.5, -90, 0.1, 0)
bt.Text, bt.BackgroundColor3 = "AUTO FARM: OFF", Color3.fromRGB(255, 0, 0)
bt.TextColor3, bt.Font, bt.TextSize = Color3.new(1,1,1), 3, 18

local log = Instance.new("TextLabel", sg)
log.Size, log.Position = UDim2.new(0, 300, 0, 60), UDim2.new(0.5, -150, 0.1, 60)
log.BackgroundColor3, log.TextColor3, log.BackgroundTransparency = Color3.new(0,0,0), Color3.new(1,1,1), 0.5
log.Text = "Status: Waiting for start"

-- Платформа
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

bt.MouseButton1Click:Connect(function()
    active = not active
    bt.Text = active and "AUTO FARM: ON" or "AUTO FARM: OFF"
    bt.BackgroundColor3 = active and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
    if not active then toggleFloor(false) isMining = false end
end)

-- ФУНКЦИЯ ПОИСКА ЛУЧШЕЙ КИРКИ
local function getBestPickaxe()
    local bestTool = nil
    local maxTier = -1
    
    -- Проверяем инвентарь и персонажа
    local locations = {plr.Backpack, plr.Character}
    
    for _, location in pairs(locations) do
        for _, item in pairs(location:GetChildren()) do
            if item:IsA("Tool") and (item.Name:lower():find("pickaxe") or item:FindFirstChild("Configuration")) then
                local tierObj = item:FindFirstChild("Configuration") and item.Configuration:FindFirstChild("Tier")
                if tierObj then
                    if tierObj.Value > maxTier then
                        maxTier = tierObj.Value
                        bestTool = item
                    end
                end
            end
        end
    end
    
    if bestTool then
        local config = bestTool.Configuration
        local data = config:FindFirstChild("Data")
        local ct = data and data:FindFirstChild("ChargeTime") and data.ChargeTime.Value or 0.4
        local cd = config:FindFirstChild("Cooldown") and config.Cooldown.Value or 0.5
        return bestTool, maxTier, ct, cd
    end
    return nil
end

task.spawn(function()
    while true do
        task.wait(0.1)
        if active then
            pcall(function()
                local char = plr.Character
                if not char or not char:FindFirstChild("HumanoidRootPart") then return end
                
                local root = char.HumanoidRootPart
                local cam = workspace.CurrentCamera
                
                -- Ищем лучшую кирку каждую итерацию (на случай, если купили новую)
                local tool, toolTier, cTime, cd = getBestPickaxe()
                
                if not tool then 
                    log.Text = "Status: No Pickaxe in inventory!" 
                    return 
                end
                
                -- Экипируем, если не в руках
                if tool.Parent ~= char then tool.Parent = char end 

                -- ПОИСК ПОДХОДЯЩЕЙ РУДЫ
                local target = nil
                for _, v in pairs(workspace.WorldSpawn.Ores:GetChildren()) do
                    if table.find(targetOres, v.Name) and v:FindFirstChild("Hittable") then
                        -- Проверка Tier руды
                        local oreTier = v:FindFirstChild("Configuration") and v.Configuration:FindFirstChild("Tier") and v.Configuration.Tier.Value or 0
                        
                        if toolTier >= oreTier then
                            target = v
                            break
                        end
                    end
                end

                if target and not isMining then
                    isMining = true
                    local realPart = target.Hittable.Part
                    local targetPos = realPart.Position
                    
                    -- Телепорт и поворот
                    local lookCF = CFrame.lookAt(targetPos + Vector3.new(0, 4, 5), targetPos)
                    root.CFrame = lookCF
                    cam.CFrame = CFrame.lookAt(cam.CFrame.Position, targetPos)
                    toggleFloor(true, root.CFrame)
                    
                    log.Text = "Mining: " .. target.Name .. " (Tier " .. toolTier .. " vs " .. (target.Configuration.Tier.Value or 0) .. ")"
                    
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
                    isMining = false
                    
                elseif not target then
                    log.Text = "Status: No reachable ores for Tier " .. toolTier
                    if (root.Position - basePos).Magnitude > 10 then
                        root.CFrame = CFrame.new(basePos)
                        toggleFloor(true, root.CFrame)
                    end
                end
            end)
        end
    end
end)