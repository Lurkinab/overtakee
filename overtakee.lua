-- Event configuration:
local requiredSpeed = 50

-- Collision cooldown state
local collisionCooldown = 0 -- Cooldown timer
local collisionCooldownDuration = 2 -- Cooldown duration in seconds

-- Combo multiplier cap
local maxComboMultiplier = 10 -- Maximum combo multiplier

-- Strike system state
local collisionStrikes = 0 -- Number of collisions in the current strike cycle

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

-- Function to handle collisions based on the strike system
local function handleCollision(player, otherCar)
  collisionStrikes = collisionStrikes + 1

  if collisionStrikes == 1 then
    -- First collision: deduct 750 points
    totalScore = math.max(0, totalScore - 750)
    comboMeter = 1
    addMessage('First collision! Lost 750 points.', -1)
  elseif collisionStrikes == 2 then
    -- Second collision: deduct 2000 points
    totalScore = math.max(0, totalScore - 2000)
    comboMeter = 1
    addMessage('Second collision! Lost 2000 points.', -1)
  elseif collisionStrikes == 3 then
    -- Third collision: deduct 5000 points
    totalScore = math.max(0, totalScore - 5000)
    comboMeter = 1
    addMessage('Third collision! Lost 5000 points.', -1)
  else
    -- Fourth collision: reset score to 0
    if totalScore > highestScore then
      highestScore = math.floor(totalScore)
      ac.sendChatMessage("Scored " .. totalScore .. " points before wipeout.")
    end
    totalScore = 0
    comboMeter = 1
    collisionStrikes = 0 -- Reset strike counter
    addMessage('Total wipeout! Score reset.', -1)
  end
end

function script.update(dt)
  if timePassed == 0 then
    addMessage('Let’s go!', 0)
  end

  local player = ac.getCarState(1)
  if player.engineLifeLeft < 1 then
    if totalScore > highestScore then
      highestScore = math.floor(totalScore)
      ac.sendChatMessage("scored " .. totalScore .. " points.")
    end
    totalScore = 0
    comboMeter = 1
    collisionStrikes = 0 -- Reset strike counter
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
        ac.sendChatMessage("scored " .. totalScore .. " points.")
      end
      totalScore = 0
      comboMeter = 1
      collisionStrikes = 0 -- Reset strike counter
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
        handleCollision(player, car) -- Handle collision severity
        state.collided = true
        collisionCooldown = collisionCooldownDuration -- Start cooldown
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

-- Rest of the script (UI and message handling) remains unchanged

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

  local speedRelative = math.saturate(math.floor(ac.getCarState(1).speedKmh) / requiredSpeed)
  speedWarning = math.applyLag(speedWarning, speedRelative < 1 and 1 or 0, 0.5, uiState.dt)

  local colorDark = rgbm(0.4, 0.4, 0.4, 1)
  local colorGrey = rgbm(0.7, 0.7, 0.7, 1)
  local colorAccent = rgbm.new(hsv(speedRelative * 120, 1, 1):rgb(), 1)
  local colorCombo = rgbm.new(hsv(comboColor, math.saturate(comboMeter / 10), 1):rgb(), math.saturate(comboMeter / 4))

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
  else
    ui.endRotation(0)
  end
  ui.popFont()
  
  -- Display current strikes
  ui.offsetCursorY(5)
  ui.pushFont(ui.Font.Main)
  local strikeColor = strikes == 0 and rgbm(0.2, 1, 0.2, 1) or 
                     strikes == 1 and rgbm(1, 0.8, 0.2, 1) or
                     strikes == 2 and rgbm(1, 0.5, 0.2, 1) or
                     rgbm(1, 0.2, 0.2, 1)
  ui.textColored('Strikes: ' .. strikes .. '/' .. maxStrikes, strikeColor)
  ui.popFont()
  
  ui.endOutline(rgbm(0, 0, 0, 0.3))
  
  ui.offsetCursorY(20)
  ui.pushFont(ui.Font.Title)
  local startPos = ui.getCursor()
  for i = 1, #messages do
    local m = messages[i]
    local f = math.saturate(4 - m.currentPos) * math.saturate(8 - m.age)
    ui.setCursor(startPos + vec2(20 + math.saturate(1 - m.age * 10) ^ 2 * 100, (m.currentPos - 1) * 30))
    ui.textColored(m.text, m.mood == 1 and rgbm(0, 1, 0, f) 
      or m.mood == -1 and rgbm(1, 0, 0, f) or rgbm(1, 1, 1, f))
  end
  for i = 1, glitterCount do
    local g = glitter[i]
    if g ~= nil then
      ui.drawLine(g.pos, g.pos + g.velocity * 4, g.color, 2)
    end
  end
  ui.popFont()
  ui.setCursor(startPos + vec2(0, 4 * 30))

  ui.pushStyleVar(ui.StyleVar.Alpha, speedWarning)
  ui.setCursorY(0)
  ui.pushFont(ui.Font.Main)
  ui.textColored('Keep speed above '..requiredSpeed..' km/h:', colorAccent)
  speedMeter(ui.getCursor() + vec2(-9, 4))
  ui.popFont()
  ui.popStyleVar()

  ui.endTransparentWindow()
end
