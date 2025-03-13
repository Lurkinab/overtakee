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

-- Base64-encoded image (replace this with your actual base64-encoded image)
local backgroundImageBase64 = "data:image/png;base64,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ANEAQDQAEA0ARAMA0QBANABANAAQDQBEAwDRAEA0ABANAEQDAEQDANEAQDQAEA0ARAMA0QAA0QBANAAQDQBEAwDRAEA0AEA0ABANAEQDANEAQDQAEA0AEA0ARAMA0QBANAAQDQBEAwDRAADRAEA0ABANAEQDANEAQDQAQDQAEA0ARAMA0QBANAAQDQAQDQBEAwDRAEA0ABANAEQDANEAANEAQDQAEA0ARAMA0QBANABANAAQDQBEAwDRAEA0ABANABANAEQDANEAQDQAEA0ARAMARAMA0QBANAAQDQBEAwDRAEA0AEA0ABANAEQDANEAQDQAEA0AEA0ARAMA0QBANAAQDQBEAwBEAwDRAEA0ABANAEQDANEAQDQAQDQAEA0ARAMA0QBANAAQDQAQDQBEAwDRAEA0ABANAEQDAEQDANEAQDQAEA0ARAMA0QBANPwIABANAEQDANEAQDQAEA0ARAMARAMA0QBANAAQDQBEAwDRAADRAEA0ABANAEQDANEAQDQAQDQAEA0ARAMA0QBANAAQDQBEAwBEAwDRAEA0ABANAEQDANEAANEAQDQAEA0ARAMA0QBANABANAAQDQBEAwDRAEA0ABANAEQDAEQDANEAQDQAEA0ARAMA0QAA0QBANAAQDQBEAwDRAEA0AEA0ABANAEQDANEAQDQAEA0AEA0ARAMA0QBANAAQDQBEAwDRAADRAEA0ABANAEQDANEAQDQAQDQAEA0ARAMA0QBANAAQDQAQDQBEAwDRAEA0ABANAEQDANEAANEAQDQAEA0ARAMA0QBANABANAAQDQBEAwDRAEA0ABANABANAEQDANEAQDQAEA0ARAMA/AgAEA0ARAMA0QBANAAQDQBEAwBEAwDRAEA0ABANAEQDANEAANEAQDQAEA0ARAMA0QBANABANAAQDQBEAwDRAEA0ABANAEQDAEQDANEAQDQAEA0ARAMA0QAA0QBANAAQDQBEAwDRAEA0AEA0ABANAEQDANEAQDQAEA0ARAMARAMA0QBANAAQDQBEAwDRAADRAEA0ABANAEQDANEAQDQAQDQAEA0ARAMA0QBANAAQDQAQDQBEAwDRAEA0ABANAEQDANEAANEAQDQAEA0ARAMA0QBANABANAAQDQBEAwDRAEA0ABANABANAEQDANEAQDQAEA0ARAMA0QAA0QBANAAQDQBEAwDRAEA0AEA0ABANAEQDANEAQDQAEA0AEA0ARAMA0QBANAAQDQBEAwBEAwDRAEA0ABANAEQDANEAQDQAQDQAEA0ARAMA0QBANAAQDQAQDQBEAwDRAEA0ABANAEQDAEQDANEAQDQAEA0ARAMA0QBANABANAAQDQBEAwDRAEA0ABANABANAEQDANEAQDQAEA0ARAMARAMA0QBANAAQDQBEAwDRAEA0/AgAEA0ARAMA0QBANAAQDQBEAwBEAwDRAEA0ABANAEQDANEAANEAQDQAEA0ARAMA0QBANABANAAQDQBEAwDRAEA0ABANAEQDAEQDANEAQDQAEA0ARAMA0QAA0QBANAAQDQBEAwDRAEA0AEA0ABANAEQDANEAQDQAEA0ARAMARAOAPvbfY7WkjQqsCZkAAAAASUVORK5CYII=" -- Replace with your full base64 string

-- Load the background image from base64
local backgroundImage = ui.loadImageFromMemory(backgroundImageBase64)

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

-- Function to handle collisions
local function handleCollision(player, otherCar)
  if collisionCooldown > 0 then return end -- Skip if cooldown is active

  -- Deduct 1000 points per collision
  totalScore = math.max(0, totalScore - 1000)
  comboMeter = 1
  collisionCounter = collisionCounter + 1

  -- Reset score if collision counter reaches maxCollisions
  if collisionCounter >= maxCollisions then
    if totalScore > highestScore then
      highestScore = math.floor(totalScore)
      ac.sendChatMessage("Scored " .. totalScore .. " points before reset due to collisions.")
    end
    totalScore = 0
    collisionCounter = 0 -- Reset collision counter
    addMessage('Too many collisions! Score reset.', -1)
  else
    addMessage('Collision: Lost 1000 points. Collisions: ' .. collisionCounter .. '/' .. maxCollisions, -1)
  end

  -- Start cooldown
  collisionCooldown = collisionCooldownDuration
end

function script.update(dt)
  if timePassed == 0 then
    addMessage('Let’s go!', 0)
  end

  local player = ac.getCarState(1)
  if player.engineLifeLeft < 1 then
    if totalScore > highestScore then
      highestScore = math.floor(totalScore)
      ac.sendChatMessage("Scored " .. totalScore .. " points.")
    end
    totalScore = 0
    comboMeter = 1
    return
  end

  timePassed = timePassed + dt

  -- Update collision cooldown
  if collisionCooldown > 0 then
    collisionCooldown = collisionCooldown - dt
  end

  -- Cap the combo multiplier at maxComboMultiplier
  comboMeter = math.min(comboMeter, maxComboMultiplier)

  local comboFadingRate = 0.5 * math.lerp(1, 0.1, math.lerpInvSat(player.speedKmh, 80, 200)) + player.wheelsOutside
  comboMeter = math.max(1, comboMeter - dt * comboFadingRate)

  local sim = ac.getSimState()
  while sim.carsCount > #carsState do
    carsState[#carsState + 1] = {}
  end

  if wheelsWarningTimeout > 0 then
    wheelsWarningTimeout = wheelsWarningTimeout - dt
  elseif player.wheelsOutside > 0 then
    if wheelsWarningTimeout == 0 then
    end
    addMessage('Car is outside', -1)
    wheelsWarningTimeout = 60
  end

  if player.speedKmh < requiredSpeed then 
    if dangerouslySlowTimer > 10 then    
      if totalScore > highestScore then
        highestScore = math.floor(totalScore)
        ac.sendChatMessage("Scored " .. totalScore .. " points.")
      end
      totalScore = 0
      comboMeter = 1
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

  for i = 1, ac.getSimState().carsCount do 
    local car = ac.getCarState(i)
    local state = carsState[i]

    if car.pos:closerToThan(player.pos, 10) then
      local drivingAlong = math.dot(car.look, player.look) > 0.2
      if not drivingAlong then
        state.drivingAlong = false

        if not state.nearMiss and car.pos:closerToThan(player.pos, 3) then
          state.nearMiss = true

          if car.pos:closerToThan(player.pos, 2.5) then
            comboMeter = comboMeter + 3
            addMessage('Very close near miss!', 1)
          else
            comboMeter = comboMeter + 1
            addMessage('Near miss: bonus combo', 0)
          end
        end
      end

      if car.collidedWith == 0 and collisionCooldown <= 0 then
        handleCollision(player, car) -- Handle collision
        state.collided = true
      end

      if not state.overtaken and not state.collided and state.drivingAlong then
        local posDir = (car.pos - player.pos):normalize()
        local posDot = math.dot(posDir, car.look)
        state.maxPosDot = math.max(state.maxPosDot, posDot)
        if posDot < -0.5 and state.maxPosDot > 0.5 then
          totalScore = totalScore + math.ceil(10 * comboMeter)
          comboMeter = comboMeter + 1
          comboColor = comboColor + 90
          addMessage('Overtake', comboMeter > 20 and 1 or 0)
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
  end
end

-- UI and message handling
local messages = {}
local glitter = {}
local glitterCount = 0

function addMessage(text, mood)
  for i = math.min(#messages + 1, 4), 2, -1 do
    messages[i] = messages[i - 1]
    messages[i].targetPos = i
  end
  messages[1] = { text = text, age = 0, targetPos = 1, currentPos = 1, mood = mood }
  if mood == 1 then
    for i = 1, 60 do
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
  if comboMeter > 10 and math.random() > 0.98 then
    for i = 1, math.floor(comboMeter) do
      local dir = vec2(math.random() - 0.5, math.random() - 0.5)
      glitterCount = glitterCount + 1
      glitter[glitterCount] = { 
        color = rgbm.new(hsv(math.random() * 360, 1, 1):rgb(), 1), 
        pos = vec2(195, 75) + dir * vec2(40, 20),
        velocity = dir:normalize():scale(0.2 + math.random()),
        life = 0.5 + 0.5 * math.random()
      }
    end
  end
end

local speedWarning = 0
function script.drawUI()
  local uiState = ac.getUiState()
  updateMessages(uiState.dt)

  -- Draw the background image
  if backgroundImage ~= nil then
    ui.drawImage(backgroundImage, vec2(0, 0), uiState.windowSize, rgbm(1, 1, 1, 0.7)) -- Adjust transparency (0.7) as needed
  end

  local speedRelative = math.saturate(math.floor(ac.getCarState(1).speedKmh) / requiredSpeed)
  speedWarning = math.applyLag(speedWarning, speedRelative < 1 and 1 or 0, 0.5, uiState.dt)

  local colorDark = rgbm(0.4, 0.4, 0.4, 1)
  local colorGrey = rgbm(0.7, 0.7, 0.7, 1)
  local colorAccent = rgbm.new(hsv(speedRelative * 120, 1, 1):rgb(), 1)
  local colorCombo = rgbm.new(hsv(comboColor, math.saturate(comboMeter / 10), 1):rgb(), math.saturate(comboMeter / 4))

  -- Draw the score and collision counter
  ui.beginTransparentWindow('overtakeScore', vec2(uiState.windowSize.x * 0.5 - 600, 100), vec2(400, 400))
  ui.beginOutline()

  ui.pushStyleVar(ui.StyleVar.Alpha, 1 - speedWarning)
  ui.pushFont(ui.Font.Title)
  ui.text('Highest Score: ' .. highestScore)
  ui.popFont()
  ui.popStyleVar()

  ui.pushFont(ui.Font.Huge)
  ui.text(totalScore .. ' pts')
  ui.sameLine(0, 40)
  ui.beginRotation()
  ui.textColored(math.ceil(comboMeter * 10) / 10 .. 'x', colorCombo)
  if comboMeter > 20 then
    ui.endRotation(math.sin(comboMeter / 180 * 3141.5) * 3 * math.lerpInvSat(comboMeter, 20, 30) + 90)
  end
  ui.popFont()

  -- Draw collision counter
  ui.offsetCursorY(20)
  ui.pushFont(ui.Font.Main)
  ui.textColored('Collisions: ' .. collisionCounter .. '/' .. maxCollisions, rgbm(1, 0, 0, 1))
  ui.popFont()

  ui.endOutline(rgbm(0, 0, 0, 0.3))
  ui.endTransparentWindow()
end
