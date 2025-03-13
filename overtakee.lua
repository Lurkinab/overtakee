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
  end

  -- Start cooldown
  collisionCooldown = collisionCooldownDuration
end

-- Function to check if a car is nearby (within 1 meter for multipliers)
local function isCarNearby(player, car, radius)
  return car.pos:closerToThan(player.pos, radius)
end

function script.update(dt)
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
        end
      end

      -- Collision logic
      if car.collidedWith == 0 and collisionCooldown <= 0 then
        handleCollision(player, car) -- Handle collision
        state.collided = true
      end

      -- Overtaking logic
      if not state.overtaken and not state.collided and state.drivingAlong then
        local posDir = (car.pos - player.pos):normalize()
        local posDot = math.dot(posDir, car.look)
        state.maxPosDot = math.max(state.maxPosDot, posDot)
        if posDot < -0.5 and state.maxPosDot > 0.5 then
          totalScore = totalScore + math.ceil(10 * comboMeter)
          comboMeter = comboMeter + 1
          comboColor = comboColor + 90
          state.overtaken = true
        end
      end

    else
      state.maxPosDot = -1
      state.overtaken = false
      state.collided = false
      state.drivingAlong = true
      state.nearMiss = false
    end
    carsState[i] = state
  end
end

-- UI and message handling
function script.drawUI()
  local uiState = ac.getUiState()

  -- UI colors
  local backgroundColor = rgbm(0.1, 0.1, 0.1, 0.9) -- Dark background
  local textColor = rgbm(1, 1, 1, 1) -- White text
  local comboColorUI = rgbm.new(hsv(comboColor, math.saturate(comboMeter / 10), 1):rgb(), math.saturate(comboMeter / 4))

  -- Draw the score and collision counter
  ui.beginTransparentWindow('overtakeScore', vec2(uiState.windowSize.x * 0.5 - 150, 100), vec2(300, 150))
  ui.beginOutline()

  -- Draw background
  ui.drawRectFilled(vec2(0, 0), vec2(300, 150), backgroundColor, 1)

  -- Multipliers side by side
  ui.pushFont(ui.Font.Main)
  ui.setCursor(vec2(10, 10))
  ui.textColored('1.0X Speed', textColor)
  ui.sameLine(0, 20)
  ui.textColored('1.0X Proximity', textColor)
  ui.sameLine(0, 20)
  ui.textColored(math.ceil(comboMeter * 10) / 10 .. 'X Combo', comboColorUI)
  ui.popFont()

  -- Score
  ui.offsetCursorY(20)
  ui.pushFont(ui.Font.Huge)
  ui.textColored(totalScore .. ' pts', textColor)
  ui.popFont()

  -- Collision counter
  ui.offsetCursorY(10)
  ui.pushFont(ui.Font.Main)
  ui.textColored(collisionCounter .. '/' .. maxCollisions, rgbm(1, 0, 0, 1)) -- Red text for collisions
  ui.popFont()

  ui.endOutline(rgbm(0, 0, 0, 0.3))
  ui.endTransparentWindow()
end
