require("input")
vx = 1.25
difficulty = "Medium"
isMuted = false
world = require("world")
state = require("state")
score = require("entities/score")
button = require("entities/button")
buttons = {}

local basket = require("entities/trash_basket")
local menus = require("menus")
local ground = require("entities/ground")
local obstacles = {} --'triangle(x, y)' is how you add a triangle
local apples = {}
local spawnTrashBag = require("entities/trash_bag")
local apple = require("entities/greenApple")
local velocityChange = 0
local spawnCooldown = 0
local circleCooldown = 10

love.load = function ()

    print("Game has finished loading!")
    print("Use arrow keys to move")
    print("Press escape to pause, r to force restart")

    --Loads the main menu on startup
    if state.main_menu then
        table.insert(buttons, button(300, 60, "Start Game"))
        table.insert(buttons, button(300, 185, "Options"))
        table.insert(buttons, button(300, 310, "Tutorial"))
        table.insert(buttons, button(300, 435, "Exit Game"))
    end

    math.randomseed(os.time())
    musicTrack = love.audio.newSource("assets/bensound-funnysong.mp3", "stream")
    musicTrack:setVolume(0.5)
    musicTrack:setLooping(true)
end

--Functions that spawn trash bags and apples at random x coordinates
enemySpawner = function ()
    table.insert(obstacles, spawnTrashBag(love.math.random(-50, 700), -100))
end

appleSpawner = function ()
    obstacles = {} --Empties the obstacles table, no triangles fall at the same time as apples
    table.insert(apples, apple(love.math.random(0, 700), -100))
end

love.draw = function()

    local font = love.graphics.newFont("assets/OpenSans-Bold.ttf", 20)
    love.graphics.setBackgroundColor(0, 0, 15)
    love.graphics.setFont(font)

    menus:draw()

    love.graphics.setColor(255, 255, 255)
    if state.paused then
        love.graphics.print("PAUSED", 320, 0, 0, 2, 2)
    end

    love.graphics.setColor(0, 15, 0)
    love.graphics.polygon("fill", ground.body:getWorldPoints(ground.shape:getPoints()))
    love.graphics.setColor(255,255,255)

    --Shows some settings
     if state.main_menu or state.options or state.paused then
        love.graphics.setColor(255,255,255)
        love.graphics.print("Difficulty is set to " .. difficulty, 270, 550)
        if isMuted then
            love.graphics.print("Game is muted", 320, 570)
        end
    end
    
    --What to draw in gameplay
    if not (state.main_menu or state.options or state.game_over or state.tutorial) then
        love.graphics.print("Score: " .. score, 0, 0, 0, 1.5, 1.5)
        love.graphics.print("Speed multiplier: " .. vx, 0, 30)
        love.graphics.print("Protect Sreks lawn!", 300, 50)
        love.graphics.setColor(255, 0, 0)

        --draw all triangles in obstacles table
        for _, trashBag in ipairs(obstacles) do
            if trashBag.draw then trashBag:draw() end
        end
        --draw all apples in apples table
        for _, greenApple in ipairs(apples) do
            if greenApple.draw then greenApple:draw() end
        end
        love.graphics.setColor(255,255,255)
        basket:draw()
    end

    --Only display buttons in these states
    if state.main_menu or state.options or state.paused or state.game_over or state.tutorial then
        for _, button in ipairs(buttons) do
            if button.draw then button:draw() end
        end
    end

end

love.update = function (dt)
    --Ends the love.update function early if these states are true, which stops world:update (time) function
    if state.paused or state.game_over or state.main_menu or state.options or state.tutorial then
        return
    end

    --Moves basket if arrow keys are pressed
    local self_x, self_y = basket.body:getPosition()
    if love.keyboard.isDown("right") and self_x < 800 then
        basket.body:setPosition(self_x + 10*vx, self_y)
    elseif love.keyboard.isDown("left") and self_x > 0 then
        basket.body:setPosition(self_x - 10*vx, self_y)
    end

    dt = dt * vx --World speed is determined by 'vx'
    world:update(dt)


    spawnCooldown = spawnCooldown - dt --decreases with time
    circleCooldown = circleCooldown - dt --decreases with time

    --Spawns trash bag and apple when respective cooldowns are lower than- or equal to zero
    while spawnCooldown <= 0 do
        spawnCooldown = spawnCooldown + 2
        enemySpawner()
    end
    if difficulty == "Medium" or difficulty == "Hard" then --No apples on easy mode!
        while circleCooldown <= 0 do
            circleCooldown = circleCooldown + 10
            appleSpawner()
        end
    end

    --increases game by 5% speed every 5 points to increase difficulty over time
    while velocityChange >= 5 do
        velocityChange = 0
        vx = vx + 0.05*vx
    end

    --Run checkCollision function for all trash bags in obstacles table.
    for i, trashBag in ipairs(obstacles) do
        if checkCollision(trashBag.fixture, ground.fixture) then
            state.game_over = true
            table.insert(buttons, button(300, 200, 'Main Menu'))
            table.insert(buttons, button(300, 350, 'Exit Game'))
            if (score > saveData.easyHS) and difficulty == 'Easy' then
                saveData.easyHS = score
                love.filesystem.write("assets/savedata.txt", saveData.easyHS)
                --[[file:open("w")
                file:write(saveData.easyHS)
                file:close()]]
             elseif (score > saveData.mediumHS) and (difficulty == 'Medium') and state.game_over then
                saveData.mediumHS = score
                love.filesystem.write("assets/savedata.txt", saveData.mediumHS)
                --[[file:open("w")
                file:write(saveData.mediumHS)
                file:close()]]
             elseif score > saveData.hardHS and difficulty == 'Hard' and state.game_over then
                saveData.hardHS = score
                love.filesystem.write("assets/savedata.txt", saveData.hardHS)
                --[[file:open("w")
                file:write(saveData.hardHS)
                file:close()]]
             end
        end
        if checkCollision(trashBag.fixture, basket.fixture) then
            table.remove(obstacles, i) --removes colliding triangle from obstacles table
            trashBag.body:destroy() --destroys the colliding triangles fixture
            score = score + 1
            velocityChange = velocityChange + 1
        end
    end

    --Run checkCollision function for all apples in apples table.
    for i, greenApple in ipairs(apples) do
        if checkCollision(greenApple.fixture, ground.fixture) then -- gain a point when apple falls on ground
            table.remove(apples, i)
            greenApple.body:setPosition(-200, 600) --temporary solution to a bug, not sure if effective.
            score = score + 1
            velocityChange = velocityChange + 1
        end
        if checkCollision(greenApple.fixture, basket.fixture) then --lose a point when you pick apple up
            table.remove(apples, i)
            greenApple.body:destroy()
            score = score - 1
        end
    end

end
