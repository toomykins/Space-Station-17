local text = ""
-- TODO
-- 1# fix the walking timer system
-- 2# UI and inventories
-- 3# A T M O S
require("assets")
require("util")
require("presetsfile")
flux = require("lib.flux")
hump = require("lib.hump")
Camera = require("lib.hump.camera")

function game:init()
    
    love.window.setMode(love.graphics.getWidth(),love.graphics.getHeight(),{resizable = true},true,8)
   screen = {
      width = love.graphics.getWidth(),
      height = love.graphics.getHeight()
   }
   

   map = {}
   items = {}
   load_images()
   load_presets()
   loadmap_box()
   players = {
      {x = 1,y = 1,race = human,quad = "south",timer = {max = 100,counter = -1}}
   }
   framecount = 0
   mainplayer = 1
   --camera = {dx = (players[mainplayer].x + 16) * 32,dy = (players[mainplayer].y + 16) * 32}
   
   camera = Camera.new(players[mainplayer].x,players[1].y);
   camera.x,camera.y = players[1].x,players[1].y
end

function game:update(dt)
   

   if (framecount == 0) then
	  	
	  	end
	  	
	  	
	  	if players[mainplayer].timer.counter < 0 then
        
          
          if love.keyboard.isDown("w") then
             players[mainplayer].y = players[mainplayer].y - 1
             players[mainplayer].quad = "north"
             players[mainplayer].timer.counter = players[mainplayer].timer.max
          elseif love.keyboard.isDown("s") then
             players[mainplayer].y = players[mainplayer].y + 1
             players[mainplayer].quad = "south"
             players[mainplayer].timer.counter = players[mainplayer].timer.max
          elseif love.keyboard.isDown("a") then
             players[mainplayer].x = players[mainplayer].x - 1
             players[mainplayer].quad = "west"
             players[mainplayer].timer.counter = players[mainplayer].timer.max
          elseif love.keyboard.isDown("d") then
             players[mainplayer].x = players[mainplayer].x + 1
             players[mainplayer].quad = "east"
             players[mainplayer].timer.counter = players[mainplayer].timer.max
          end
	if love.keyboard.isDown("g") then
		flux.to(players[1],5,{x=50, y=50})
          end

--camera.lookAt(players[1].x,players[1].y)
camera.x,camera.y = players[1].x*32,players[1].y*32

    end
	  	players[mainplayer].timer.counter = players[mainplayer].timer.counter - 1
	  	
	  	
	  	
	  	
	  	
	   
	  	framecount = framecount + 1
	  	
	  	--camera.dx = (-players[mainplayer].x + 16)* 32
	  	--camera.dy = (-players[mainplayer].y + 16)* 32
    flux.update(dt)
end



function game:draw()
  camera:attach()
   local drawsize = math.floor(((screen.height / 32) / 32) + 0.5)

  -- love.graphics.translate(camera.dx * drawsize,camera.dy * drawsize)
   for x = players[mainplayer].x - 16,players[mainplayer].x + 16,1 do
      if not(map[x] == nil) then
         for y = players[mainplayer].x - 16,players[mainplayer].y + 16,1 do
            if not(map[x][y] == nil) then
               love.graphics.draw(map[x][y].image,map[x][y].quad,x * 32 + drawsize,y * 32 + drawsize,0,drawsize,drawsize,32 / 2 + drawsize,32 / 2 + drawsize)
            end
         end
      end
   	end
   	
   	for i,obj in ipairs(items) do
   	   if obj.x >= players[mainplayer].x - 16 and obj.x <= players[mainplayer].x + 16 and obj.y >= players[mainplayer].y - 16 and obj.y <= players[mainplayer].y + 16 then
   	      love.graphics.draw(obj.image,obj.quad,obj.x * 32 + drawsize,obj.y * 32 + drawsize,0,drawsize,drawsize,32 / 2 + drawsize,32 / 2 + drawsize)
   	   end
   	end
   	
   	
   	for i,obj in ipairs(players) do
   	   love.graphics.draw(obj.race.image,obj.race[obj.quad],obj.x * 32 + drawsize,obj.y * 32 + drawsize,0,drawsize,drawsize,32 / 2 + drawsize,32 / 2 + drawsize)
   	end
   	
   	
  
    camera:detach();
   	love.graphics.print(players[1].x .. " " .. players[1].y .. " " .. players[1].timer.counter,0,0,0,3)
   	love.graphics.print(camera.scale,0,40)
end

function game:wheelmoved(x,y)
if y > 0 then
  text = y
  camera.scale = camera.scale + 0.5
  elseif y <0 then
    text = y
    --camera.scale = camera.scale - 0.1
    flux.to(camera,0.2,{scale = math.floor(camera.scale,0) -0.5})
    else text = "mouse no"
  end
end