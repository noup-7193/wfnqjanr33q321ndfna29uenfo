local plr = game.Players.LocalPlayer
local oreName = "Stone" -- Для теста на камне
local basePos = Vector3.new(-7120, -680, -2531)
local active = false
local isMining = false
local floor = nil -- Наша замена Anchor

-- События
local Events = game:GetService("ReplicatedStorage"):WaitForChild("Events")
local ChargeRem = Events.Tools.Charge
local AttackRem = Events.Tools.Attack -- Из твоего скрина в Events/Tools
local InputRem = Events.Tools.ToolInputChanged

-- GUI
local sg = Instance.new("ScreenGui", game.CoreGui)
local bt = Instance.new("TextButton", sg)
bt.Size, bt.Position = UDim2.new(0, 150, 0, 50), UDim2.new(0.5, -75, 0.1, 0)
bt.Text, bt.BackgroundColor3 = "AUTO: OFF", Color3.fromRGB(255, 0, 0)

local log = Instance.new("TextLabel", sg)
log.Size, log.Position = UDim2.new(0, 220, 0, 60), UDim2.new(0.5, -110, 0.1, 60)
log.BackgroundColor3, log.TextColor3, log.BackgroundTransparency = Color3.new(0,0,0), Color3.new(1,1,1), 0.5
log.Text = "Status: Waiting..."

-- Создание невидимого пола под ногами
local function toggleFloor(on, pos)
    if not on and floor then
        floor:Destroy()
        floor = nil
    elseif on then
        if not floor then
            floor = Instance.new("Part")
            floor.Name = "AntiAnchorFloor"
            floor.Size = Vector3.new(10, 1, 10)
            floor.Transparency = 1
            floor.Anchored = true
            floor.CanCollide = true
            floor.CanQuery = false -- Чтобы не мешал лучам (Raycast)
            floor.Parent = workspace
        end
        floor.CFrame = pos * CFrame.new(0, -3.2, 0) -- Чуть ниже ног
    end
end

bt.MouseButton1Click:Connect(function()
    active = not active
    bt.Text = active and "AUTO: ON" or "AUTO: OFF"
    bt.BackgroundColor3 = active and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
    if not active then 
        toggleFloor(false)
        isMining = false
        if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            plr.Character.HumanoidRootPart.Velocity = Vector3.new(0,0,0)
        end
    end
end)

local function getTool()
    local c = plr.Character
    local t = c:FindFirstChild("Iron Pickaxe") or plr.Backpack:FindFirstChild("Iron Pickaxe")
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
                local char = plr.Character
                local root = char.HumanoidRootPart
                local cam = workspace.CurrentCamera
                local tool, cTime, cd = getTool()
                
                if not tool then log.Text = "Status: No Pickaxe!"; return end
                if tool.Parent ~= char then tool.Parent = char end

                local folder = workspace.WorldSpawn.Ores
                local target = nil
                for _, v in pairs(folder:GetChildren()) do
                    if v.Name == oreName and v:FindFirstChild("Hitbox") then target = v; break end
                end

                if target and not isMining then
                    isMining = true
                    local hb = target.Hitbox
                    local targetPos = hb.Position
                    
                    -- 1. ТП + Поворот ТЕЛА и КАМЕРЫ на руду
                    local lookCF = CFrame.lookAt(targetPos + Vector3.new(0, 4, 5), targetPos)
                    root.CFrame = lookCF
                    cam.CFrame = CFrame.lookAt(cam.CFrame.Position, targetPos) -- Смотрим камерой
                    toggleFloor(true, root.CFrame)
                    
                    log.Text = "Mining: Perfect Hit..."
                    
                    -- 2. Начинаем замах
                    InputRem:FireServer(tool, true)
                    ChargeRem:FireServer({
                        ["Target"] = hb,
                        ["HitPosition"] = targetPos
                    })
                    
                    -- 3. Ждем идеальный тайминг Alpha (зеленая зона)
                    task.wait(cTime + 0.05)
                    
                    -- 4. Удар (Alpha 1)
                    if tool:FindFirstChild("Attack") then
                        -- Вызываем ивент самой кирки
                        tool.Attack:FireServer({
                            ["Alpha"] = 1,
                            ["AnimSpeed"] = 1,
                            ["DamageMultiplier"] = 1
                        })
                        -- И на всякий случай глобальный Attack, если кирка не сработает
                        AttackRem:FireServer(hb, {["Alpha"] = 1})
                        
                        log.Text = "Logs: CRITICAL HIT (Alpha 1)"
                    end
                    
                    InputRem:FireServer(tool, false)
                    task.wait(cd)
                    isMining = false
                    
                elseif not target then
                    log.Text = "Status: Searching "..oreName.."..."
                    if (root.Position - basePos).Magnitude > 10 then
                        root.CFrame = CFrame.new(basePos)
                        toggleFloor(true, root.CFrame)
                    end
                end
            end)
        end
    end
end)