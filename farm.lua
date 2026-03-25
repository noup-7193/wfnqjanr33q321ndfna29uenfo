local plr = game.Players.LocalPlayer
local basePos = Vector3.new(-7120, -680, -2531)
local maxTier = 4 -- Наш лимит по тиру
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
bt.Size, bt.Position = UDim2.new(0, 160, 0, 50), UDim2.new(0.5, -80, 0.1, 0)
bt.Text, bt.BackgroundColor3 = "ULTRA FARM: OFF", Color3.fromRGB(255, 0, 0)

local log = Instance.new("TextLabel", sg)
log.Size, log.Position = UDim2.new(0, 250, 0, 60), UDim2.new(0.5, -125, 0.1, 60)
log.BackgroundColor3, log.TextColor3, log.BackgroundTransparency = Color3.new(0,0,0), Color3.new(1,1,1), 0.5
log.Text = "Status: Idle"

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
    bt.Text = active and "ULTRA FARM: ON" or "ULTRA FARM: OFF"
    bt.BackgroundColor3 = active and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
    if not active then toggleFloor(false) isMining = false end
end)

local function getTool()
    local c = plr.Character
    -- Ищем любую кирку в руках или рюкзаке
    local t = c:FindFirstChildOfClass("Tool") or plr.Backpack:FindFirstChildOfClass("Tool")
    if t and t:FindFirstChild("Configuration") then
        local d = t.Configuration:FindFirstChild("Data")
        local ct = d and d:FindFirstChild("ChargeTime") and d.ChargeTime.Value or 0.4
        local cd = t.Configuration:FindFirstChild("Cooldown") and t.Configuration.Cooldown.Value or 0.5
        return t, ct, cd
    end
    return nil
end

task.spawn(function()
    while true do
        task.wait(0.05) -- Максимальная скорость цикла
        if active then
            pcall(function()
                local char = plr.Character
                local root = char.HumanoidRootPart
                local cam = workspace.CurrentCamera
                local tool, cTime, cd = getTool()
                
                if not tool then log.Text = "Status: Tool Not Found!"; return end
                if tool.Parent ~= char then tool.Parent = char end

                -- ПОИСК ЛЮБОЙ РУДЫ ДО 4 ТИРА
                local target = nil
                local dist = 999999
                for _, v in pairs(workspace.WorldSpawn.Ores:GetChildren()) do
                    local config = v:FindFirstChild("Configuration")
                    local tier = config and config:FindFirstChild("Tier") and config.Tier.Value or 0
                    
                    if tier <= maxTier and v:FindFirstChild("Hittable") and v.Hittable:FindFirstChild("Part") then
                        local d = (root.Position - v.Hittable.Part.Position).Magnitude
                        if d < dist then -- Ищем ближайшую
                            dist = d
                            target = v
                        end
                    end
                end

                if target and not isMining then
                    isMining = true
                    local realPart = target.Hittable.Part
                    local targetPos = realPart.Position
                    
                    -- ТП и Взгляд
                    root.CFrame = CFrame.lookAt(targetPos + Vector3.new(0, 4, 3), targetPos)
                    cam.CFrame = CFrame.lookAt(cam.CFrame.Position, targetPos)
                    toggleFloor(true, root.CFrame)
                    
                    -- МОМЕНТАЛЬНЫЙ ЦИКЛ УДАРА
                    InputRem:FireServer(tool, true)
                    
                    local chargeData = {["Target"] = realPart, ["HitPosition"] = targetPos}
                    ChargeRem:FireServer(chargeData)
                    
                    -- Вместо cTime ждем минимум для регистрации (0.05 - 0.1)
                    task.wait(0.07) 
                    
                    AttackRem:FireServer({
                        ["Alpha"] = 1, 
                        ["ResponseTime"] = cTime -- Врем серверу, что ждали долго
                    })
                    
                    InputRem:FireServer(tool, false)
                    
                    -- Кулдаун тоже режем (можешь поставить 0.1 если не кикает)
                    task.wait(math.min(cd, 0.2)) 
                    
                    isMining = false
                    log.Text = "Mining: " .. target.Name .. " (Tier " .. (target.Configuration.Tier.Value) .. ")"
                elseif not target then
                    log.Text = "Status: Waiting for Ores (Tier <= 4)"
                    if (root.Position - basePos).Magnitude > 10 then
                        root.CFrame = CFrame.new(basePos)
                        toggleFloor(true, root.CFrame)
                    end
                end
            end)
        end
    end
end)