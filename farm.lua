local plr = game.Players.LocalPlayer
local oreName = "Stone" -- Твое название для теста
local basePos = Vector3.new(-7120, -680, -2531)
local active = false
local isMining = false -- Флаг, чтобы не спамить удары в одну секунду

-- GUI
local sg = Instance.new("ScreenGui", game.CoreGui)
local bt = Instance.new("TextButton", sg)
bt.Size, bt.Position = UDim2.new(0, 150, 0, 50), UDim2.new(0.5, -75, 0.1, 0)
bt.Text, bt.BackgroundColor3 = "AUTO: OFF", Color3.fromRGB(255, 0, 0)

local log = Instance.new("TextLabel", sg)
log.Size, log.Position = UDim2.new(0, 220, 0, 60), UDim2.new(0.5, -110, 0.1, 60)
log.BackgroundColor3, log.TextColor3, log.BackgroundTransparency = Color3.new(0,0,0), Color3.new(1,1,1), 0.5
log.Text = "Status: Waiting..."

-- События
local Events = game:GetService("ReplicatedStorage"):WaitForChild("Events")
local ChargeRem = Events.Tools.Charge
local InputRem = Events.Tools.ToolInputChanged

bt.MouseButton1Click:Connect(function()
    active = not active
    bt.Text = active and "AUTO: ON" or "AUTO: OFF"
    bt.BackgroundColor3 = active and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
    if not active then
        isMining = false
        if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
            plr.Character.HumanoidRootPart.Anchored = false
        end
    end
end)

-- Поиск инструмента и его статов
local function getToolInfo()
    local c = plr.Character
    local tool = c:FindFirstChild("Iron Pickaxe") or plr.Backpack:FindFirstChild("Iron Pickaxe")
    if tool then
        local data = tool:FindFirstChild("Configuration") and tool.Configuration:FindFirstChild("Data")
        local cTime = (data and data:FindFirstChild("ChargeTime")) and data.ChargeTime.Value or 0.4
        local cd = tool.Configuration:FindFirstChild("Cooldown") and tool.Configuration.Cooldown.Value or 0.5
        return tool, cTime, cd
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
                local tool, chargeTime, cooldown = getToolInfo()
                
                if not tool then log.Text = "Status: No Pickaxe!"; return end
                if tool.Parent ~= char then tool.Parent = char end

                local ores = workspace.WorldSpawn.Ores
                local target = nil
                for _, v in pairs(ores:GetChildren()) do
                    if v.Name == oreName and v:FindFirstChild("Hitbox") then target = v; break end
                end

                if target and not isMining then
                    isMining = true -- Блокируем цикл, пока идет удар
                    root.Anchored = true
                    root.CFrame = target.Hitbox.CFrame * CFrame.new(0, 5, 0)
                    
                    log.Text = "Mining: Charging..."
                    
                    -- 1. Сигнал начала использования
                    InputRem:FireServer(tool, true)
                    
                    -- 2. Начинаем замах
                    ChargeRem:FireServer({
                        ["Target"] = target.Hitbox,
                        ["HitPosition"] = target.Hitbox.Position
                    })
                    
                    -- 3. Ждем идеальный тайминг (из конфига кирки)
                    task.wait(chargeTime + 0.05)
                    
                    -- 4. САМ УДАР (Alpha 1 = 100% урон)
                    if tool:FindFirstChild("Attack") then
                        tool.Attack:FireServer({
                            ["Alpha"] = 1,
                            ["AnimSpeed"] = 1,
                            ["DamageMultiplier"] = 1
                        })
                        log.Text = "Logs: PERFECT HIT!"
                    end
                    
                    -- 5. Ждем Кулдаун
                    task.wait(cooldown)
                    isMining = false -- Разрешаем следующий удар
                    
                elseif not target then
                    log.Text = "Status: Searching "..oreName.."..."
                    if (root.Position - basePos).Magnitude > 5 then
                        root.CFrame = CFrame.new(basePos)
                    end
                end
            end)
        end
    end
end)