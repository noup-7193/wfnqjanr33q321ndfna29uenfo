local plr = game.Players.LocalPlayer
local oreName = "Abyssalite"
local basePos = Vector3.new(-7120, -680, -2531)
local active = false
local isMining = false -- Флаг зажатия кнопки

-- GUI (Твой рабочий стиль)
local sg = Instance.new("ScreenGui", game.CoreGui)
local bt = Instance.new("TextButton", sg)
bt.Size, bt.Position = UDim2.new(0, 150, 0, 50), UDim2.new(0.5, -75, 0.1, 0)
bt.Text, bt.BackgroundColor3 = "AUTO: OFF", Color3.fromRGB(255, 0, 0)

local log = Instance.new("TextLabel", sg)
log.Size, log.Position = UDim2.new(0, 220, 0, 60), UDim2.new(0.5, -110, 0.1, 60)
log.BackgroundColor3, log.TextColor3, log.BackgroundTransparency = Color3.new(0,0,0), Color3.new(1,1,1), 0.5
log.Text = "Status: Waiting..."

-- События из ReplicatedStorage
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

-- Поиск бура
local function getTool()
    local c = plr.Character
    if not c then return end
    return c:FindFirstChild("Industrial Drill") or plr.Backpack:FindFirstChild("Industrial Drill")
end

task.spawn(function()
    while task.wait(0.2) do -- Проверка состояния каждые 0.2 сек
        if active then
            pcall(function()
                local char = plr.Character
                local root = char.HumanoidRootPart
                local tool = getTool()
                
                if not tool then log.Text = "Status: No Drill found!"; return end
                if tool.Parent ~= char then tool.Parent = char end

                local ores = workspace.WorldSpawn.Ores
                local target = nil
                for _, v in pairs(ores:GetChildren()) do
                    if v.Name == oreName and v:FindFirstChild("Hitbox") then target = v; break end
                end

                if target then
                    root.Anchored = true
                    root.CFrame = target.Hitbox.CFrame * CFrame.new(0, 5, 0)
                    
                    -- Если мы еще не "зажали" кнопку — зажимаем
                    if not isMining then
                        isMining = true
                        InputRem:FireServer(tool, true) -- Сигнал: "Кнопка нажата"
                        log.Text = "Mining: Holding Drill..."
                    end
                    
                    -- Постоянно шлем координаты бурения (как это делает реальный бур)
                    ChargeRem:FireServer({
                        ["Target"] = target.Hitbox,
                        ["HitPosition"] = target.Hitbox.Position
                    })
                else
                    -- Руды нет: "отжимаем" кнопку
                    if isMining then
                        isMining = false
                        InputRem:FireServer(tool, false) -- Сигнал: "Кнопка отпущена"
                    end
                    
                    log.Text = "Status: Searching Abyssalite..."
                    if (root.Position - basePos).Magnitude > 5 then
                        root.CFrame = CFrame.new(basePos)
                    end
                end
            end)
        end
    end
end)