local plr = game.Players.LocalPlayer
local oreName = "Stone" -- Поменяй на Abyssalite потом
local basePos = Vector3.new(-7120, -680, -2531)
local active = false
local isMining = false
local floor = nil

-- Глобальные события (из твоего Spy)
local Events = game:GetService("ReplicatedStorage"):WaitForChild("Events")
local ChargeRem = Events.Tools.Charge
local AttackRem = Events.Tools.Attack -- Глобальный ивент!
local InputRem = Events.Tools.ToolInputChanged

-- GUI
local sg = Instance.new("ScreenGui", game.CoreGui)
local bt = Instance.new("TextButton", sg)
bt.Size, bt.Position = UDim2.new(0, 150, 0, 50), UDim2.new(0.5, -75, 0.1, 0)
bt.Text, bt.BackgroundColor3 = "AUTO: OFF", Color3.fromRGB(255, 0, 0)

local log = Instance.new("TextLabel", sg)
log.Size, log.Position = UDim2.new(0, 220, 0, 60), UDim2.new(0.5, -110, 0.1, 60)
log.BackgroundColor3, log.TextColor3, log.BackgroundTransparency = Color3.new(0,0,0), Color3.new(1,1,1), 0.5
log.Text = "Status: Ready"

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
    bt.Text = active and "AUTO: ON" or "AUTO: OFF"
    bt.BackgroundColor3 = active and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
    if not active then toggleFloor(false) isMining = false end
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
                local root = plr.Character.HumanoidRootPart
                local cam = workspace.CurrentCamera
                local tool, cTime, cd = getTool()
                
                if not tool then log.Text = "Status: No Tool!"; return end
                if tool.Parent ~= plr.Character then tool.Parent = plr.Character end

                local ores = workspace.WorldSpawn.Ores
                local target = nil
                for _, v in pairs(ores:GetChildren()) do
                    -- ИЩЕМ ПО ИМЕНИ И ПРОВЕРЯЕМ НАЛИЧИЕ HITTABLE.PART
                    if v.Name == oreName and v:FindFirstChild("Hittable") and v.Hittable:FindFirstChild("Part") then
                        target = v; break
                    end
                end

                if target and not isMining then
                    isMining = true
                    local realPart = target.Hittable.Part -- Наша реальная цель из логов!
                    local targetPos = realPart.Position
                    
                    -- ТП и Взгляд
                    local lookCF = CFrame.lookAt(targetPos + Vector3.new(0, 4, 5), targetPos)
                    root.CFrame = lookCF
                    cam.CFrame = CFrame.lookAt(cam.CFrame.Position, targetPos)
                    toggleFloor(true, root.CFrame)
                    
                    -- 1. Сигнал начала (как в Call #7 твоих логов)
                    InputRem:FireServer(tool, true)
                    
                    -- 2. Посылаем Charge ДВАЖДЫ (как в твоем Spy)
                    local chargeData = {
                        ["Target"] = realPart,
                        ["HitPosition"] = targetPos
                    }
                    ChargeRem:FireServer(chargeData)
                    task.wait(0.05)
                    ChargeRem:FireServer(chargeData)
                    
                    log.Text = "Mining: Waiting Charge..."
                    task.wait(cTime + 0.05)
                    
                    -- 3. ИДЕАЛЬНЫЙ УДАР (как в Call #4 твоего Attack)
                    AttackRem:FireServer({
                        ["Alpha"] = 1, -- Идеальный крит
                        ["ResponseTime"] = cTime -- Эмулируем время реакции
                    })
                    
                    log.Text = "Logs: PERFECT HIT (Alpha 1)"
                    
                    -- 4. Сброс
                    InputRem:FireServer(tool, false)
                    task.wait(cd)
                    isMining = false
                elseif not target then
                    log.Text = "Status: Searching "..oreName
                    if (root.Position - basePos).Magnitude > 10 then
                        root.CFrame = CFrame.new(basePos)
                        toggleFloor(true, root.CFrame)
                    end
                end
            end)
        end
    end
end)