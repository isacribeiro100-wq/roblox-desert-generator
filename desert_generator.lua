--[[
    GERADOR DE DESERTO PROCEDURAL INFINITO - SPAWN NO TOPO DA AREIA
    Gera terreno procedural centrado no spawn e coloca player no topo
]]

local DesertGenerator = {}
DesertGenerator.seed = 12345
DesertGenerator.scale = 50
DesertGenerator.amplitude = 20
DesertGenerator.octaves = 4
DesertGenerator.persistence = 0.5
DesertGenerator.lacunarity = 2.0
DesertGenerator.chunkSize = 50
DesertGenerator.renderDistance = 300

local function hash(x, y)
    local n = math.sin(x * 12.9898 + y * 78.233) * 43758.5453
    return n - math.floor(n)
end

local function smoothstep(t)
    return t * t * (3 - 2 * t)
end

local function perlinNoise(x, y, seed)
    local xi = math.floor(x)
    local yi = math.floor(y)
    local xf = x - xi
    local yf = y - yi
    
    local n00 = hash(xi, yi + seed)
    local n10 = hash(xi + 1, yi + seed)
    local n01 = hash(xi, yi + 1 + seed)
    local n11 = hash(xi + 1, yi + 1 + seed)
    
    local u = smoothstep(xf)
    local v = smoothstep(yf)
    
    local nx0 = n00 + u * (n10 - n00)
    local nx1 = n01 + u * (n11 - n01)
    
    return nx0 + v * (nx1 - nx0)
end

local function fractalNoise(x, y, octaves, persistence, lacunarity, seed)
    local value = 0
    local amplitude = 1
    local frequency = 1
    local maxValue = 0
    
    for i = 1, octaves do
        value = value + perlinNoise(x * frequency, y * frequency, seed + i) * amplitude
        maxValue = maxValue + amplitude
        amplitude = amplitude * persistence
        frequency = frequency * lacunarity
    end
    
    return value / maxValue
end

function DesertGenerator:getHeight(x, z)
    local noise = fractalNoise(
        x / self.scale,
        z / self.scale,
        self.octaves,
        self.persistence,
        self.lacunarity,
        self.seed
    )
    return noise * self.amplitude
end

function DesertGenerator:generateChunk(chunkX, chunkZ, partSize)
    local parts = {}
    
    local startX = chunkX * self.chunkSize
    local startZ = chunkZ * self.chunkSize
    
    for x = startX, startX + self.chunkSize - partSize, partSize do
        for z = startZ, startZ + self.chunkSize - partSize, partSize do
            local height = self:getHeight(x, z)
            
            local part = Instance.new("Part")
            part.Size = Vector3.new(partSize, math.max(1, height + 10), partSize)
            part.Position = Vector3.new(x + partSize/2, (height + 10)/2, z + partSize/2)
            part.Name = "Sand"
            part.CanCollide = true
            part.Material = Enum.Material.Sand
            part.TopSurface = Enum.SurfaceType.Smooth
            part.BottomSurface = Enum.SurfaceType.Smooth
            
            local colorVariation = math.abs(height) / self.amplitude
            if colorVariation < 0.3 then
                part.Color = Color3.fromRGB(238, 214, 175)
            elseif colorVariation < 0.6 then
                part.Color = Color3.fromRGB(220, 200, 160)
            else
                part.Color = Color3.fromRGB(210, 180, 140)
            end
            
            table.insert(parts, part)
        end
    end
    
    return parts
end

function DesertGenerator:createChunk(chunkX, chunkZ, partSize)
    local parts = self:generateChunk(chunkX, chunkZ, partSize)
    
    local chunkFolder = Instance.new("Folder")
    chunkFolder.Name = "Chunk_" .. chunkX .. "_" .. chunkZ
    chunkFolder.Parent = workspace
    
    for _, part in ipairs(parts) do
        part.Parent = chunkFolder
    end
    
    return chunkFolder
end

DesertGenerator.loadedChunks = {}

function DesertGenerator:getChunkCoords(position)
    local chunkX = math.floor(position.X / self.chunkSize)
    local chunkZ = math.floor(position.Z / self.chunkSize)
    return chunkX, chunkZ
end

function DesertGenerator:isChunkLoaded(chunkX, chunkZ)
    local key = chunkX .. "," .. chunkZ
    return self.loadedChunks[key] ~= nil
end

function DesertGenerator:loadChunksAroundPlayer(playerPosition, partSize)
    partSize = partSize or 5
    
    local playerChunkX, playerChunkZ = self:getChunkCoords(playerPosition)
    local loadDistance = math.ceil(self.renderDistance / self.chunkSize)
    
    for x = playerChunkX - loadDistance, playerChunkX + loadDistance do
        for z = playerChunkZ - loadDistance, playerChunkZ + loadDistance do
            local key = x .. "," .. z
            if not self:isChunkLoaded(x, z) then
                self:createChunk(x, z, partSize)
                self.loadedChunks[key] = true
            end
        end
    end
    
    for key, _ in pairs(self.loadedChunks) do
        local coords = string.split(key, ",")
        local chunkX = tonumber(coords[1])
        local chunkZ = tonumber(coords[2])
        
        local distance = math.sqrt((chunkX - playerChunkX)^2 + (chunkZ - playerChunkZ)^2)
        
        if distance > loadDistance + 1 then
            local chunkFolder = workspace:FindFirstChild("Chunk_" .. chunkX .. "_" .. chunkZ)
            if chunkFolder then
                chunkFolder:Destroy()
            end
            self.loadedChunks[key] = nil
        end
    end
end

-- ============ EXECUTAR AQUI ============

local player = game.Players:GetPlayers()[1]

if player and player.Character then
    print("✓ Iniciando deserto procedural dinâmico...")
    
    local spawnLocation = workspace:FindFirstChild("Spawnlocation")
    local spawnPosX = 0
    local spawnPosZ = 0
    
    if spawnLocation then
        spawnPosX = spawnLocation.Position.X
        spawnPosZ = spawnLocation.Position.Z
        print("✓ Spawn encontrado em: X=" .. spawnPosX .. ", Z=" .. spawnPosZ)
    else
        print("⚠️ Spawn não encontrado! Usando posição padrão (0, 0)")
    end
    
    -- Gerar areia PRIMEIRO - grade 5x5 centrada no spawn
    print("✓ Gerando areia...")
    task.wait(0.5)
    for i = -2, 2 do
        for j = -2, 2 do
            DesertGenerator:createChunk(i, j, 5)
        end
    end
    print("✓ Areia gerada ao redor do spawn!")
    
    task.wait(2)  -- Aguarda mais tempo para a areia gerar
    
    -- DEPOIS teletransportar
    local heightAtSpawn = DesertGenerator:getHeight(spawnPosX, spawnPosZ)
    local topOfSand = heightAtSpawn + 15
    
    if player.Character:FindFirstChild("HumanoidRootPart") then
        player.Character.HumanoidRootPart.Position = Vector3.new(spawnPosX, topOfSand, spawnPosZ)
        print("✓ Player spawnou no TOPO DA AREIA! Altura: " .. topOfSand)
    end
    
    print("✓ Deserto pronto! Movimente-se para gerar mais...")
    
    while true do
        if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
            local playerPos = player.Character.HumanoidRootPart.Position
            DesertGenerator:loadChunksAroundPlayer(playerPos, 5)
        end
        task.wait(0.5)
    end
end
