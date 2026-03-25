local plr = game.Players.LocalPlayer
local targetOre = "Abyssalite"
local targetTool = "Obsidian Pickaxe"
local basePos = Vector3.new(-7120, -680, -2530)

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
bt.Text, bt.BackgroundColor3 = "FULL AUTO: OFF", Color3.fromRGB(255, 0, 0)
bt.TextColor3, bt.Font, bt.TextSize = Color3.new(1,1,1), 3, 18

local log = Instance.new("TextLabel", sg)
log.Size, log.Position = UDim2.new(0, 250, 0, 60), UDim2.new(0.5, -125, 0.1, 60)
log.BackgroundColor3, log.TextColor3, log.BackgroundTransparency = Color3.new(0,0,0), Color3.new(1,1,1), 0.5
log.Text = "Status: Waiting for start"

-- Платформа (замена Anchor)
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
    bt.Text = active and "FULL AUTO: ON" or "FULL AUTO: OFF"
    bt.BackgroundColor3 = active and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
    if not active then toggleFloor(false) isMining = false end
end)

-- АВТО-ПОИСК КИРКИ
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

task.spawn(function()
    while true do
        task.wait(0.1)
        if active then
            pcall(function()
                local root = plr.Character.HumanoidRootPart
                local cam = workspace.CurrentCamera
                local tool, cTime, cd = autoGetTool()
                
                if not tool then log.Text = "Status: No Pickaxe found!"; return end
                if tool.Parent ~= plr.Character then tool.Parent = plr.Character end 

                -- АВТО-ПОИСК АБИССАЛИТА
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
                    
                    -- ТП + Взгляд
                    local lookCF = CFrame.lookAt(targetPos + Vector3.new(0, 4, 5), targetPos)
                    root.CFrame = lookCF
                    cam.CFrame = CFrame.lookAt(cam.CFrame.Position, targetPos)
                    toggleFloor(true, root.CFrame)
                    
                    log.Text = "Mining: " .. targetOre
                    
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
                    log.Text = "Status: Searching " .. targetOre .. "..."
                    if (root.Position - basePos).Magnitude > 10 then
                        root.CFrame = CFrame.new(basePos)
                        toggleFloor(true, root.CFrame)
                    end
                end
            end)
        end
    end
end)