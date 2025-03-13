-- Event configuration
local requiredSpeed = 80

-- Collision cooldown state
local collisionCooldown = 0 -- Cooldown timer
local collisionCooldownDuration = 2 -- Cooldown duration in seconds

-- Combo multiplier cap
local maxComboMultiplier = 10 -- Maximum combo multiplier

-- This function is called before the event activates. Once it returns true, it'll run:
function script.prepare(dt)
  ac.debug('speed', ac.getCarState(1).speedKmh)
  return ac.getCarState(1).speedKmh > 60
end

-- Event state:
local eventState = {
  timePassed = 0,
  totalScore = 0,
  comboMeter = 1,
  comboColor = 0,
  highestScore = 0,
  dangerouslySlowTimer = 0,
  carsState = {},
  wheelsWarningTimeout = 0,
  playerPreCollisionSpeed = 0, -- Track player's speed before collision
  messages = {}, -- Message queue
  glitter = {}, -- Glitter particles
  glitterCount = 0, -- Number of active glitter particles
  crashCount = 0, -- Track number of crashes
  lastCollisionCarIndex = -1, -- Track the last car involved in a collision
}

-- Function to handle collisions
local function handleCollision(player, otherCar, carIndex)
  -- Check if the collision is with the same car and within cooldown
  if eventState.lastCollisionCarIndex == carIndex and collisionCooldown > 0 then
    return -- Ignore repeated collisions with the same car during cooldown
  end

  local speedLoss = eventState.playerPreCollisionSpeed - player.speedKmh
  ac.debug('Collision detected!', 'Speed loss: ' .. speedLoss)

  -- Increment crash count
  eventState.crashCount = eventState.crashCount + 1

  -- Update highest score before resetting
  if eventState.totalScore > eventState.highestScore then
    eventState.highestScore = eventState.totalScore
    ac.sendChatMessage("New high score: " .. eventState.highestScore)
  end

  if eventState.crashCount >= 5 then
    -- Reset score and crash count after 5 crashes
    eventState.totalScore = 0
    eventState.crashCount = 0
    eventState.comboMeter = 1
    addMessage('5 CRASHES! Score reset.', -1)
  else
    -- Deduct points for each crash
    eventState.totalScore = math.max(0, eventState.totalScore - 1000)
    addMessage('Collision! Lost 1000 points. Crashes: ' .. eventState.crashCount, -1)
  end

  -- Start collision cooldown
  collisionCooldown = collisionCooldownDuration
  eventState.lastCollisionCarIndex = carIndex -- Track the last car involved in a collision
end

-- Function to add a message to the message queue
local function addMessage(text, mood)
  for i = math.min(#eventState.messages + 1, 4), 2, -1 do
    eventState.messages[i] = eventState.messages[i - 1]
    eventState.messages[i].targetPos = i
  end
  eventState.messages[1] = { text = text, age = 0, targetPos = 1, currentPos = 1, mood = mood }

  if mood == 1 then
    for i = 1, 60 do
      local dir = vec2(math.random() - 0.5, math.random() - 0.5)
      eventState.glitterCount = eventState.glitterCount + 1
      eventState.glitter[eventState.glitterCount] = {
        color = rgbm.new(hsv(math.random() * 360, 1, 1):rgb(), 1),
        pos = vec2(80, 140) + dir * vec2(40, 20),
        velocity = dir:normalize():scale(0.2 + math.random()),
        life = 0.5 + 0.5 * math.random()
      }
    end
  end
end

-- Function to update messages and glitter particles
local function updateMessages(dt)
  eventState.comboColor = eventState.comboColor + dt * 10 * eventState.comboMeter
  if eventState.comboColor > 360 then eventState.comboColor = eventState.comboColor - 360 end

  for i = 1, #eventState.messages do
    local m = eventState.messages[i]
    m.age = m.age + dt
    m.currentPos = math.applyLag(m.currentPos, m.targetPos, 0.8, dt)
  end

  for i = eventState.glitterCount, 1, -1 do
    local g = eventState.glitter[i]
    g.pos:add(g.velocity)
    g.velocity.y = g.velocity.y + 0.02
    g.life = g.life - dt
    g.color.mult = math.saturate(g.life * 4)
    if g.life < 0 then
      if i < eventState.glitterCount then
        eventState.glitter[i] = eventState.glitter[eventState.glitterCount]
      end
      eventState.glitterCount = eventState.glitterCount - 1
    end
  end

  if eventState.comboMeter > 10 and math.random() > 0.98 then
    for i = 1, math.floor(eventState.comboMeter) do
      local dir = vec2(math.random() - 0.5, math.random() - 0.5)
      eventState.glitterCount = eventState.glitterCount + 1
      eventState.glitter[eventState.glitterCount] = {
        color = rgbm.new(hsv(math.random() * 360, 1, 1):rgb(), 1),
        pos = vec2(195, 75) + dir * vec2(40, 20),
        velocity = dir:normalize():scale(0.2 + math.random()),
        life = 0.5 + 0.5 * math.random()
      }
    end
  end
end

function script.update(dt)
  if eventState.timePassed == 0 then
    addMessage("Let's go!", 0)
  end

  local player = ac.getCarState(1)
  if not player or player.engineLifeLeft < 1 then
    if eventState.totalScore > eventState.highestScore then
      eventState.highestScore = math.floor(eventState.totalScore)
      ac.sendChatMessage("Scored " .. eventState.totalScore .. " points.")
    end
    eventState.totalScore = 0
    eventState.comboMeter = 1
    eventState.crashCount = 0 -- Reset crash count
    return
  end

  eventState.timePassed = eventState.timePassed + dt

  -- Update collision cooldown
  if collisionCooldown > 0 then
    collisionCooldown = collisionCooldown - dt
  end

  -- Cap the combo multiplier at maxComboMultiplier
  eventState.comboMeter = math.min(eventState.comboMeter, maxComboMultiplier)

  -- Update combo meter decay
  local comboFadingRate = 0.5 * math.lerp(1, 0.1, math.lerpInvSat(player.speedKmh, 80, 200))
  eventState.comboMeter = math.max(1, eventState.comboMeter - dt * comboFadingRate)

  -- Update player's pre-collision speed
  eventState.playerPreCollisionSpeed = player.speedKmh

  -- Handle dangerously slow speed
  if player.speedKmh < requiredSpeed then
    eventState.dangerouslySlowTimer = eventState.dangerouslySlowTimer + dt
    if eventState.dangerouslySlowTimer > 10 then
      if eventState.totalScore > eventState.highestScore then
        eventState.highestScore = math.floor(eventState.totalScore)
        ac.sendChatMessage("New high score: " .. eventState.highestScore)
      end
      eventState.totalScore = 0
      eventState.comboMeter = 1
      eventState.crashCount = 0 -- Reset crash count
      addMessage('Too slow! Score reset.', -1)
      eventState.dangerouslySlowTimer = 0 -- Reset the timer
    end
  else
    eventState.dangerouslySlowTimer = 0 -- Reset the timer if speed is above required
  end

  -- Handle collisions, near misses, and overtakes
  for i = 1, ac.getSimState().carsCount do
    local car = ac.getCarState(i)
    local state = eventState.carsState[i] or {}
    eventState.carsState[i] = state

    if car.pos:closerToThan(player.pos, 10) then
      -- Check for collisions
      if car.collidedWith == 0 and collisionCooldown <= 0 then
        handleCollision(player, car, i) -- Pass car index to handleCollision
        state.collided = true
      end

      -- Check for near misses
      local drivingAlong = math.dot(car.look, player.look) > 0.2
      if not drivingAlong and not state.collided then
        state.drivingAlong = false

        if not state.nearMiss and car.pos:closerToThan(player.pos, 2.5) then
          state.nearMiss = true
          eventState.comboMeter = eventState.comboMeter + 1
          addMessage('Near miss: bonus combo', 0)
        end
      end

      -- Check for overtakes
      if not state.overtaken and not state.collided and state.drivingAlong then
        local posDir = (car.pos - player.pos):normalize()
        local posDot = math.dot(posDir, car.look)
        state.maxPosDot = math.max(state.maxPosDot, posDot)
        if posDot < -0.5 and state.maxPosDot > 0.5 then
          eventState.totalScore = eventState.totalScore + math.ceil(10 * eventState.comboMeter)
          eventState.comboMeter = eventState.comboMeter + 1
          eventState.comboColor = eventState.comboColor + 90
          addMessage('Overtake', eventState.comboMeter > 20 and 1 or 0)
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
function script.drawUI()
  local uiState = ac.getUiState()
  updateMessages(uiState.dt)

  local speedRelative = math.saturate(math.floor(ac.getCarState(1).speedKmh) / requiredSpeed)
  local speedWarning = math.applyLag(0, speedRelative < 1 and 1 or 0, 0.5, uiState.dt)

  local colorDark = rgbm(0.4, 0.4, 0.4, 1)
  local colorGrey = rgbm(0.7, 0.7, 0.7, 1)
  local colorAccent = rgbm.new(hsv(speedRelative * 120, 1, 1):rgb(), 1)
  local colorCombo = rgbm.new(hsv(eventState.comboColor, math.saturate(eventState.comboMeter / 10), 1):rgb(), math.saturate(eventState.comboMeter / 4))

  local function speedMeter(ref)
    ui.drawRectFilled(ref + vec2(0, -4), ref + vec2(180, 5), colorDark, 1)
    ui.drawLine(ref + vec2(0, -4), ref + vec2(0, 4), colorGrey, 1)
    ui.drawLine(ref + vec2(requiredSpeed, -4), ref + vec2(requiredSpeed, 4), colorGrey, 1)

    local speed = math.min(ac.getCarState(1).speedKmh, 180)
    if speed > 1 then
      ui.drawLine(ref + vec2(0, 0), ref + vec2(speed, 0), colorAccent, 4)
    end
  end

  ui.beginTransparentWindow('overtakeScore', vec2(uiState.windowSize.x * 0.5 - 600, 100), vec2(400, 400))
  ui.beginOutline()

  ui.pushStyleVar(ui.StyleVar.Alpha, 1 - speedWarning)
  ui.pushFont(ui.Font.Title)
  ui.text('Highest Score: ' .. eventState.highestScore)
  ui.popFont()
  ui.popStyleVar()

  ui.pushFont(ui.Font.Huge)
  ui.text(eventState.totalScore .. ' pts')
  ui.sameLine(0, 40)
  ui.beginRotation()
  ui.textColored(math.ceil(eventState.comboMeter * 10) / 10 .. 'x', colorCombo)
  ui.textColored(' (' .. eventState.crashCount .. '/5)', rgbm(1, 0, 0, 1)) -- Display crash count
  if eventState.comboMeter > 20 then
    ui.endRotation(math.sin(eventState.comboMeter / 180 * 3141.5) * 3 * math.lerpInvSat(eventState.comboMeter, 20, 30) + 90)
  end
  ui.popFont()
  ui.endOutline(rgbm(0, 0, 0, 0.3))

  ui.offsetCursorY(20)
  ui.pushFont(ui.Font.Title)
  local startPos = ui.getCursor()
  for i = 1, #eventState.messages do
    local m = eventState.messages[i]
    local f = math.saturate(4 - m.currentPos) * math.saturate(8 - m.age)
    ui.setCursor(startPos + vec2(20 + math.saturate(1 - m.age * 10) ^ 2 * 100, (m.currentPos - 1) * 30))
    ui.textColored(m.text, m.mood == 1 and rgbm(0, 1, 0, f) or m.mood == -1 and rgbm(1, 0, 0, f) or rgbm(1, 1, 1, f))
  end
  for i = 1, eventState.glitterCount do
    local g = eventState.glitter[i]
    if g ~= nil then
      ui.drawLine(g.pos, g.pos + g.velocity * 4, g.color, 2)
    end
  end
  ui.popFont()
  ui.setCursor(startPos + vec2(0, 4 * 30))

  ui.pushStyleVar(ui.StyleVar.Alpha, speedWarning)
  ui.setCursorY(0)
  ui.pushFont(ui.Font.Main)
  ui.textColored('Keep speed above ' .. requiredSpeed .. ' km/h:', colorAccent)
  speedMeter(ui.getCursor() + vec2(-9, 4))
  ui.popFont()
  ui.popStyleVar()

  ui.endTransparentWindow()
end
