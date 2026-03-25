-- Определяем, куда вставлять GUI (защита от того, чтобы окно не пропало)

local parent = (gethui and gethui()) or game:GetService("CoreGui")



-- Удаляем старую версию, чтобы не накладывались при перезапуске

if parent:FindFirstChild("MyTPGui") then parent.MyTPGui:Destroy() end



local ScreenGui = Instance.new("ScreenGui")

ScreenGui.Name = "MyTPGui"

ScreenGui.Parent = parent

ScreenGui.ResetOnSpawn = false



-- Функция для создания кнопок с ТВОЕЙ логикой + добавлен параметр angle

local function createTeleportButton(name, pos, coords, angle, color)

    local Button = Instance.new("TextButton")

    Button.Parent = ScreenGui

    Button.Size = UDim2.new(0, 120, 0, 50)

    Button.Position = pos

    Button.Text = name

    Button.BackgroundColor3 = color

    Button.TextColor3 = Color3.new(1, 1, 1)

    Button.Font = Enum.Font.SourceSansBold

    Button.TextSize = 20



    Button.MouseButton1Click:Connect(function()

        local plr = game.Players.LocalPlayer

        if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then

            -- Логика телепорта + поворот на заданный угол

            plr.Character.HumanoidRootPart.CFrame = CFrame.new(coords) * CFrame.Angles(0, math.rad(angle), 0)

            

            -- Остановка персонажа (чтобы не кикнуло)

            plr.Character.HumanoidRootPart.Velocity = Vector3.new(0, 0, 0)

        end

        

        Button.Text = "OK!"

        task.wait(0.3)

        Button.Text = name

    end)

end



-- Создаем кнопки (ПИРС - 0, ПРОДАЖА - 90, ВУЛКАН - -80)

createTeleportButton("ФИОЛ", UDim2.new(0.2, 0, 0.5, 0), Vector3.new(-7120, -680, -2531), 15, Color3.fromRGB(52, 152, 219))

createTeleportButton("ПРОДАЖА", UDim2.new(0.2, 0, 0.6, 0), Vector3.new(940, 55, -680), 70, Color3.fromRGB(46, 204, 113))

createTeleportButton("ВУЛКАН РУДА", UDim2.new(0.2, 0, 0.7, 0), Vector3.new(-7054, -529, -2769), -50, Color3.fromRGB(231, 80, 60)) 


---------------------------------------------------------

-- ДОПОЛНИТЕЛЬНЫЕ ОКНА ДЛЯ ПОЗИЦИИ И УГЛА (СПРАВА)

---------------------------------------------------------



local PosLabel = Instance.new("TextLabel")

PosLabel.Parent = ScreenGui

PosLabel.Size = UDim2.new(0, 200, 0, 40)

PosLabel.Position = UDim2.new(0.7, 0, 0.5, 0)

PosLabel.BackgroundColor3 = Color3.new(0, 0, 0)

PosLabel.BackgroundTransparency = 0.5

PosLabel.TextColor3 = Color3.new(1, 1, 1)

PosLabel.Text = "POS: Ожидание..."

PosLabel.TextSize = 14



local AngleLabel = Instance.new("TextLabel")

AngleLabel.Parent = ScreenGui

AngleLabel.Size = UDim2.new(0, 200, 0, 40)

AngleLabel.Position = UDim2.new(0.7, 0, 0.56, 0)

AngleLabel.BackgroundColor3 = Color3.new(0, 0, 0)

AngleLabel.BackgroundTransparency = 0.5

AngleLabel.TextColor3 = Color3.new(1, 1, 1)

AngleLabel.Text = "ANGLE: Ожидание..."

AngleLabel.TextSize = 14



-- Безопасный цикл обновления данных

task.spawn(function()

    while true do

        task.wait(0.1)

        -- Используем pcall как "Try", чтобы ошибка не ломала скрипт

        pcall(function()

            local plr = game.Players.LocalPlayer

            local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")

            if root then

                local p = root.Position

                local a = root.Orientation

                PosLabel.Text = string.format("POS: %.1f, %.1f, %.1f", p.X, p.Y, p.Z)

                AngleLabel.Text = string.format("ANGLE Y: %.1f", a.Y)

            end

        end)

    end

end)



print("GUI загружено в " .. parent.Name)