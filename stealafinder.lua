game:GetService('StarterGui'):SetCore("DevConsoleVisible", true) 
print(" join discord.gg/3QfV4QCZxV for updates")

--// Services
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local CoreGui = game:GetService("CoreGui")

-- Wait for LocalPlayer to initialize
local LocalPlayer
repeat
    LocalPlayer = Players.LocalPlayer
    task.wait()
until LocalPlayer

--// Whitelisted players (only qAru67)
local whitelistedUserIds = {
    [1283742765] = true -- qAru67's UserId
}

--// User Configuration from loader
local webhook =  "https://discord.com/api/webhooks/1408666761104068691/nDip-g6v3yXOYZOElWAhaXvRAxAB4V0TdsAEXUNZhwXzmjEHctvqnXSpwZq2eaOermdT"
local targetPets = getgenv().TargetPetNames

--// Teleport Fail Handling
local teleportFails = 0
local maxTeleportRetries = 3

--// Found Pet Cache
local detectedPets = {}
local webhookSent = false
local stopHopping = false

TeleportService.TeleportInitFailed:Connect(function(_, result)
    teleportFails += 1
    if result == Enum.TeleportResult.GameFull then
        warn("⚠️ Game full. Retrying teleport...")
    elseif result == Enum.TeleportResult.Unauthorized then
        warn("❌ Unauthorized/private server. Retrying...")
    else
        warn("❌ Other teleport error:", result)
    end

    if teleportFails >= maxTeleportRetries then
        warn("⚠️ Too many teleport fails. Forcing fresh server...")
        teleportFails = 0
        task.wait(1)
        TeleportService:Teleport(game.PlaceId)
    else
        task.wait(1)
        serverHop()
    end
end)

-- Helper: Check if pet is owned by a whitelisted player
local function isPetWhitelisted(petModel)
    local creatorTag = petModel:FindFirstChild("creator") or petModel:FindFirstChild("Owner")
    if creatorTag and creatorTag:IsA("ObjectValue") and creatorTag.Value and creatorTag.Value:IsA("Player") then
        return whitelistedUserIds[creatorTag.Value.UserId] == true
    end
    return false
end

--// ESP Function (fixed to show only pet name)
local function addESP(targetModel)
    if targetModel:FindFirstChild("PetESP") then return end

    local Billboard = Instance.new("BillboardGui")
    Billboard.Name = "PetESP"
    Billboard.Adornee = targetModel:FindFirstChild("HumanoidRootPart") or targetModel.PrimaryPart or targetModel
    Billboard.Size = UDim2.new(0, 100, 0, 30)
    Billboard.StudsOffset = Vector3.new(0, 3, 0)
    Billboard.AlwaysOnTop = true
    Billboard.Parent = CoreGui

    local Label = Instance.new("TextLabel")
    Label.Size = UDim2.new(1, 0, 1, 0)
    Label.BackgroundTransparency = 1
    Label.Text = targetModel.Name -- show the pet’s name only
    Label.TextColor3 = Color3.fromRGB(255, 0, 0)
    Label.TextStrokeTransparency = 0.5
    Label.Font = Enum.Font.SourceSansBold
    Label.TextScaled = true
    Label.Parent = Billboard

    -- auto-remove when pet is destroyed
    targetModel.AncestryChanged:Connect(function(_, parent)
        if not parent then
            Billboard:Destroy()
        end
    end)
end

--// Build Join Link
local function buildJoinLink(placeId, jobId)
    return string.format(
        "https://chillihub1.github.io/chillihub-joiner/?placeId=%d&gameInstanceId=%s",
        placeId,
        jobId
    )
end

--// Webhook Function (with JobId + clickable join link)
local function sendWebhook(foundPets, jobId)
    if webhook == "" then return end

    local petCounts = {}
    for _, pet in ipairs(foundPets) do
        if pet then
            petCounts[pet] = (petCounts[pet] or 0) + 1
        end
    end

    local formattedPets = {}
    for petName, count in pairs(petCounts) do
        if count > 1 then
            table.insert(formattedPets, count .. "x " .. petName)
        else
            table.insert(formattedPets, petName)
        end
    end

    local joinLink = buildJoinLink(game.PlaceId, jobId)

    local jsonData = HttpService:JSONEncode({
        ["content"] = "@everyone 🚨 SECRET PET DETECTED!",
        ["embeds"] = {{
            ["title"] = "🧠 Pet(s) Found!",
            ["description"] = "Brainrot-worthy pet detected in the server!",
            ["fields"] = {
                { ["name"] = "User", ["value"] = LocalPlayer.Name },
                { ["name"] = "Found Pet(s)", ["value"] = table.concat(formattedPets, "\n") },
                { ["name"] = "JobId", ["value"] = jobId }, -- added back JobId
                { ["name"] = "Join Link", ["value"] = string.format("[Join Now](%s)", joinLink) },
                { ["name"] = "Time (EDT)", ["value"] = os.date("!%I:%M %p", os.time() - (4 * 60 * 60)) }
            },
            ["color"] = 0xFF00FF
        }}
    })

    local req = http_request or request or syn and syn.request
    if req then
        pcall(function()
            req({
                Url = webhook,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = jsonData
            })
        end)
    end
end

--// Pet Detection Function
local function checkForPets()
    local found = {}
    for _, obj in pairs(workspace:GetDescendants()) do
        if obj:IsA("Model") then
            if isPetWhitelisted(obj) then
                continue
            end

            local nameLower = string.lower(obj.Name)
            for _, target in pairs(targetPets) do
                if string.find(nameLower, string.lower(target)) and not obj:FindFirstChild("PetESP") then
                    addESP(obj)
                    table.insert(found, obj.Name)
                    stopHopping = true
                    break
                end
            end
        end
    end
    return found
end

--// Server Hop Function
function serverHop()
    if stopHopping then return end
    task.wait(1.3)

    local cursor = nil
    local PlaceId, JobId = game.PlaceId, game.JobId
    local tries = 0
    local maxPages = 3

    local servers = {}

    while tries < maxPages do
        local url = "https://games.roblox.com/v1/games/" .. PlaceId .. "/servers/Public?limit=100"
        if cursor then url = url .. "&cursor=" .. cursor end

        local success, response = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(url))
        end)

        if success and response and response.data then
            for _, server in ipairs(response.data) do
                if tonumber(server.playing or 0) >= 4 and tonumber(server.playing or 0) <= 7
                   and server.id ~= JobId then
                    table.insert(servers, server)
                end
            end

            cursor = response.nextPageCursor
            if not cursor then break end
            tries += 1
        else
            warn("⚠️ Failed to fetch server list. Retrying...")
            tries += 1
            task.wait(0.1)
        end
    end

    if #servers > 0 then
        local picked = servers[math.random(1, #servers)]
        print("✅ Hopping to server:", picked.id, "with", picked.playing, "players")
        teleportFails = 0
        TeleportService:TeleportToPlaceInstance(PlaceId, picked.id)
    else
        warn("❌ No 6–7 player servers found. Forcing random teleport...")
        TeleportService:Teleport(PlaceId)
    end
end

--// Live Detection for Pets
workspace.DescendantAdded:Connect(function(obj)
    task.wait(0.25)
    if obj:IsA("Model") then
        if isPetWhitelisted(obj) then return end

        local nameLower = string.lower(obj.Name)
        for _, target in pairs(targetPets) do
            if string.find(nameLower, string.lower(target)) and not obj:FindFirstChild("PetESP") then
                if not detectedPets[obj.Name] then
                    detectedPets[obj.Name] = true
                    addESP(obj)
                    print("🎯 New pet appeared:", obj.Name)
                    stopHopping = true
                    if not webhookSent then
                        sendWebhook({obj.Name}, game.JobId)
                        webhookSent = true
                    end
                end
                break
            end
        end
    end
end)

--// Start
task.wait(2)
local petsFound = checkForPets()
if #petsFound > 0 then
    for _, name in ipairs(petsFound) do
        detectedPets[name] = true
    end
    if not webhookSent then
        print("🎯 Found pet(s):", table.concat(petsFound, ", "))
        sendWebhook(petsFound, game.JobId)
        webhookSent = true
    end
else
    print("🔍 No target pets found. Hopping to next server...")
    task.delay(0.8, serverHop)
end
