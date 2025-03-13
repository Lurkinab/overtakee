-- Event configuration:
local requiredSpeed = 80

-- Collision cooldown state
local collisionCooldown = 0 -- Cooldown timer
local collisionCooldownDuration = 2 -- Cooldown duration in seconds

-- Combo multiplier cap
local maxComboMultiplier = 10 -- Maximum combo multiplier

-- Collision counter and score reset logic
local collisionCounter = 0 -- Tracks the number of collisions
local maxCollisions = 5 -- Maximum allowed collisions before score reset

-- This function is called before event activates. Once it returns true, it’ll run:
function script.prepare(dt)
  ac.debug('speed', ac.getCarState(1).speedKmh)
  return ac.getCarState(1).speedKmh > 60
end

-- Event state:
local timePassed = 0
local totalScore = 0
local comboMeter = 1
local comboColor = 0
local highestScore = 0
local dangerouslySlowTimer = 0
local carsState = {}
local wheelsWarningTimeout = 0
local playerPreCollisionSpeed = 0 -- Track player's speed before collision

-- Helper function to reset score
local function resetScore()
  if totalScore > highestScore then
    highestScore = math.floor(totalScore)
    ac.sendChatMessage("Scored " .. totalScore .. " points.")
  end
  totalScore = 0
  comboMeter = 1
end

-- Function to handle collisions
local function handleCollision(player, otherCar)
  if collisionCooldown > 0 then return end -- Skip if cooldown is active

  -- Deduct 1000 points per collision
  totalScore = math.max(0, totalScore - 1000)
  comboMeter = 1
  collisionCounter = collisionCounter + 1

  -- Reset score if collision counter reaches maxCollisions
  if collisionCounter >= maxCollisions then
    resetScore()
    collisionCounter = 0 -- Reset collision counter
    addMessage('Too many collisions! Score reset.', -1)
  else
    addMessage('Collision: Lost 1000 points. Collisions: ' .. collisionCounter .. '/' .. maxCollisions, -1)
  end

  -- Start cooldown
  collisionCooldown = collisionCooldownDuration
end

-- Function to check if a car is nearby (within 1 meter for multipliers)
local function isCarNearby(player, car, radius)
  return car.pos:closerToThan(player.pos, radius)
end

function script.update(dt)
  if timePassed == 0 then
    addMessage('Let’s go!', 0)
  end

  local player = ac.getCarState(1)
  local sim = ac.getSimState()

  -- Reset score if engine is dead
  if player.engineLifeLeft < 1 then
    resetScore()
    return
  end

  timePassed = timePassed + dt

  -- Update collision cooldown
  if collisionCooldown > 0 then
    collisionCooldown = collisionCooldown - dt
  end

  -- Cap the combo multiplier at maxComboMultiplier
  comboMeter = math.min(comboMeter, maxComboMultiplier)

  -- Combo fading rate based on speed and wheels outside
  local comboFadingRate = 0.5 * math.lerp(1, 0.1, math.lerpInvSat(player.speedKmh, 80, 200)) + player.wheelsOutside
  comboMeter = math.max(1, comboMeter - dt * comboFadingRate)

  -- Check if player is too slow
  if player.speedKmh < requiredSpeed then 
    if dangerouslySlowTimer > 10 then    
      resetScore()
    else
      if dangerouslySlowTimer == 0 then addMessage('Too slow!', -1) end
    end
    dangerouslySlowTimer = dangerouslySlowTimer + dt
    comboMeter = 1
    return
  else 
    dangerouslySlowTimer = 0
  end

  -- Update player's pre-collision speed
  playerPreCollisionSpeed = player.speedKmh

  -- Check for nearby cars and handle collisions/near-misses
  for i = 1, sim.carsCount do 
    local car = ac.getCarState(i)
    local state = carsState[i] or {}

    if isCarNearby(player, car, 10) then
      local drivingAlong = math.dot(car.look, player.look) > 0.2
      if not drivingAlong then
        state.drivingAlong = false

        -- Near miss logic (within 1 meter for multipliers)
        if not state.nearMiss and isCarNearby(player, car, 1) then
          state.nearMiss = true
          comboMeter = comboMeter + 1
          addMessage('Near miss: bonus combo', 0)
        end
      end

      -- Collision logic
      if car.collidedWith == 0 and collisionCooldown <= 0 then
        handleCollision(player, car) -- Handle collision
        state.collided = true
      end
    else
      state.drivingAlong = true
      state.nearMiss = false
      state.collided = false
    end
    carsState[i] = state
  end
end

-- UI and message handling
local messages = {}
local glitter = {}
local glitterCount = 0

function addMessage(text, mood)
  if #messages >= 4 then
    table.remove(messages, 4)
  end
  table.insert(messages, 1, { text = text, age = 0, targetPos = 1, currentPos = 1, mood = mood })

  -- Add glitter for positive messages
  if mood == 1 then
    for i = 1, 30 do -- Reduced number of particles
      local dir = vec2(math.random() - 0.5, math.random() - 0.5)
      glitterCount = glitterCount + 1
      glitter[glitterCount] = { 
        color = rgbm.new(hsv(math.random() * 360, 1, 1):rgb(), 1), 
        pos = vec2(80, 140) + dir * vec2(40, 20),
        velocity = dir:normalize():scale(0.2 + math.random()),
        life = 0.5 + 0.5 * math.random()
      }
    end
  end
end

local function updateMessages(dt)
  comboColor = comboColor + dt * 10 * comboMeter
  if comboColor > 360 then comboColor = comboColor - 360 end
  for i = 1, #messages do
    local m = messages[i]
    m.age = m.age + dt
    m.currentPos = math.applyLag(m.currentPos, m.targetPos, 0.8, dt)
  end
  for i = glitterCount, 1, -1 do
    local g = glitter[i]
    g.pos:add(g.velocity)
    g.velocity.y = g.velocity.y + 0.02
    g.life = g.life - dt
    g.color.mult = math.saturate(g.life * 4)
    if g.life < 0 then
      if i < glitterCount then
        glitter[i] = glitter[glitterCount]
      end
      glitterCount = glitterCount - 1
    end
  end
end

function script.drawUI()
  local uiState = ac.getUiState()
  updateMessages(uiState.dt)

  -- UI colors
  local backgroundColor = rgbm(1, 1, 1, 0.9) -- White background with 90% opacity
  local textColor = rgbm(0, 0, 0, 1) -- Black text
  local comboColorUI = rgbm.new(hsv(comboColor, math.saturate(comboMeter / 10), 1):rgb(), math.saturate(comboMeter / 4))

  -- Draw the score and collision counter
  ui.beginTransparentWindow('overtakeScore', vec2(uiState.windowSize.x * 0.5 - 200, 100), vec2(400, 300))
  ui.beginOutline()

  -- Draw background
  ui.drawRectFilled(vec2(0, 0), vec2(400, 300), backgroundColor, 1)

  -- Score and combo
  ui.pushFont(ui.Font.Huge)
  ui.textColored(totalScore .. ' pts', textColor)
  ui.sameLine(0, 40)
  ui.beginRotation()
  ui.textColored(math.ceil(comboMeter * 10) / 10 .. 'x', comboColorUI)
  if comboMeter > 20 then
    ui.endRotation(math.sin(comboMeter / 180 * 3141.5) * 3 * math.lerpInvSat(comboMeter, 20, 30) + 90)
  end
  ui.popFont()

  -- Collision counter
  ui.offsetCursorY(20)
  ui.pushFont(ui.Font.Main)
  ui.textColored('Collisions: ' .. collisionCounter .. '/' .. maxCollisions, rgbm(1, 0, 0, 1)) -- Red text for collisions
  ui.popFont()

  -- Messages
  ui.offsetCursorY(20)
  ui.pushFont(ui.Font.Main)
  for i = 1, #messages do
    local m = messages[i]
    ui.setCursor(vec2(20, 100 + (i - 1) * 30))
    ui.textColored(m.text, m.mood == 1 and rgbm(0, 1, 0, 1) or m.mood == -1 and rgbm(1, 0, 0, 1) or textColor)
  end
  ui.popFont()

  -- Glitter effects
  for i = 1, glitterCount do
    local g = glitter[i]
    if g then
      ui.drawLine(g.pos, g.pos + g.velocity * 4, g.color, 2)
    end
  end

  ui.endOutline(rgbm(0, 0, 0, 0.3))
  ui.endTransparentWindow()
end
