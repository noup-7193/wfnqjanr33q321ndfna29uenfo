local plr = game.Players.LocalPlayer
local oreName = "Stone" -- Поменяй на Abyssalite потом
local basePos = Vector3.new(-7120, -680, -2531)
local active = false
local isMining = false

-- ГУИ (Твой стиль)
local sg = Instance.new("ScreenGui", game.CoreGui)
local bt = Instance.new("TextButton", sg)
bt.Size, bt.Position = UDim2.new(0, 150, 0, 50), UDim2.new(0.5, -75, 0.1, 0)
bt.Text, bt.BackgroundColor3 = "AUTO: OFF", Color3.fromRGB(255, 0, 0)

local log = Instance.new("TextLabel", sg)
log.Size, log.Position = UDim2.new(0, 220, 0, 60), UDim2.new(0.5, -110, 0.1, 60)
log.BackgroundColor3, log.TextColor3, log.BackgroundTransparency = Color3.new(0,0,0), Color3.new(1,1,1), 0.5
log.Text = "Status: Waiting..."

local Events = game:GetService("ReplicatedStorage"):WaitForChild("Events")
local ChargeRem = Events.Tools.Charge
local InputRem = Events.Tools.ToolInputChanged

bt.MouseButton1Click:Connect(function()
    active = not active
    bt.Text = active and "AUTO: ON" or "AUTO: OFF"
    bt.BackgroundColor3 = active and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
    if not active and plr.Character then 
        plr.Character.HumanoidRootPart.Anchored = false 
        isMining = false
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
                local tool, cTime, cd = getTool()
                
                if not tool then log.Text = "Status: No Tool!"; return end
                if tool.Parent ~= char then tool.Parent = char end

                local ores = workspace.WorldSpawn.Ores
                local target = nil
                for _, v in pairs(ores:GetChildren()) do
                    if v.Name == oreName and v:FindFirstChild("Hitbox") then target = v; break end
                end

                if target and not isMining then
                    isMining = true
                    root.Anchored = true
                    
                    -- ФИКС: Поворачиваем персонажа лицом к руде
                    -- Мы встаем чуть в стороне и смотрим в центр хитбокса
                    local targetPos = target.Hitbox.Position
                    root.CFrame = CFrame.lookAt(targetPos + Vector3.new(0, 5, 4), targetPos)
                    
                    log.Text = "Logs: Targeting & Charging..."
                    
                    -- 1. Имитируем зажатие
                    InputRem:FireServer(tool, true)
                    
                    -- 2. Шлем пакет "Зарядки" (Сервер проверяет Target)
                    ChargeRem:FireServer({
                        ["Target"] = target.Hitbox,
                        ["HitPosition"] = targetPos
                    })
                    
                    -- 3. Ждем время замаха
                    task.wait(cTime + 0.05)
                    
                    -- 4. Наносим урон (Alpha 1)
                    if tool:FindFirstChild("Attack") then
                        tool.Attack:FireServer({
                            ["Alpha"] = 1,
                            ["AnimSpeed"] = 1,
                            ["DamageMultiplier"] = 1
                        })
                        log.Text = "Logs: PERFECT HIT!"
                    end
                    
                    -- 5. "Отжимаем" клик, чтобы сбросить состояние
                    InputRem:FireServer(tool, false)
                    
                    task.wait(cd)
                    isMining = false
                elseif not target then
                    log.Text = "Status: Searching "..oreName
                    if (root.Position - basePos).Magnitude > 5 then
                        root.CFrame = CFrame.new(basePos)
                    end
                end
            end)
        end
    end
end)