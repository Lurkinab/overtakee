-- overtakee.lua
-- A CSP Lua script for Assetto Corsa Content Manager to track overtaking scores

-- Persistent storage file
local storageFile = 'overtakee_scores.json'
local score = 0
local highScore = 0
local slowdownTimer = 0
local leaderboard = {}

-- Load saved data
local function loadLeaderboard()
  local data = ac.load(storageFile)
  if data then
    leaderboard = json.decode(data) or {}
  else
    leaderboard = {}
  end
end

-- Save data to file
local function saveLeaderboard()
  ac.store(storageFile, json.encode(leaderboard))
end

-- Initialize on script load
function script.init()
  loadLeaderboard()
  highScore = leaderboard[ac.getUserName()] or 0
end

function script.update(dt)
  local playerCar = ac.getCar(0)
  if not playerCar then return end

  -- Collision detection
  if playerCar.collision > 0 then
    -- Save score immediately upon collision
    highScore = math.max(highScore, score)
    leaderboard[ac.getUserName()] = highScore
    saveLeaderboard()
    score = 0
    slowdownTimer = 10 -- Start slowdown period
  end

  -- Slowdown logic
  if slowdownTimer > 0 then
    slowdownTimer = slowdownTimer - dt
  else
    -- Accumulate score only when not in slowdown
    score = score + dt * playerCar.speedKmh / 10
  end
end

function script.drawUI()
  ui.beginTransparentWindow('overtakee', vec2(10, 10), vec2(300, 200))
  ui.text("Score: " .. math.floor(score))
  ui.text("High Score: " .. highScore)
  ui.text("Leaderboard:")

  -- Sort and display leaderboard
  local sorted = {}
  for name, s in pairs(leaderboard) do
    table.insert(sorted, {name = name, score = s})
  end
  table.sort(sorted, function(a, b) return a.score > b.score end)

  for i, entry in ipairs(sorted) do
    if i <= 5 then -- Limit to top 5
      ui.text(entry.name .. ": " .. entry.score)
    end
  end
  ui.endTransparentWindow()
end

-- Optional: Handle multiplayer sync (basic example)
function script.onOnlineEvent(event)
  if event.type == 'playerConnected' then
    -- Request leaderboard update from server (requires server-side script)
    ac.sendPacket({type = 'requestLeaderboard'})
  elseif event.type == 'packetReceived' and event.data.type == 'leaderboardUpdate' then
    leaderboard = event.data.leaderboard
    saveLeaderboard()
  end
end
