Class = require("lib/30log")

StateMachine = require("lib.hump.gamestate")
suit = require("lib.suit")

Vector = require( "lib/hump/vector" )
Timer = require( "lib/hump/timer" )


World = require( "src/systems/world" )
Renderer = require( "src/systems/renderer" )
CameraSystem = require( "src/systems/camerasystem" )
DemoSystem = require( "src/systems/demosystem" )
Physics = require( "src/systems/physics" )
MapSystem = require( "src/systems/mapsystem" )
--BindSystem = require( "src/systems/bindsystem" ) rewrite this
Network = require( "src/systems/networksystem" )
ClientSystem = require( "src/systems/clientsystem" )
OptionSystem = require( "src/systems/optionsystem" )
Components = require( "src/systems/components" )
Entities = require( "src/systems/entities" )
--Gamemode = require( "src/systems/gamemode" )
--Gamemode:setGamemode( "default" )









--require 'enet'
Enet = {
    Client = require( "lib/client" ),
    Server = require( "lib/server" )
}



game = require("game")
menu = require("menu")
game.version="0.0.0"
fuck = 0
--nothing works

function love.load(arg)
  if arg[#arg] == "-debug" then require("mobdebug").start() end
  --Gamestate.registerEvents()
  
  love.math.setRandomSeed( love.timer.getTime() )
  OptionSystem:load()
  love.window.setMode( 800, 600, { resizable=true, vsync=true } )
  Renderer:load()
  --BindSystem:load()
  Physics:load()
  
  
  
  StateMachine.switch(menu)
  StateMachine.init()
  
end

function love.update(dt)
  StateMachine.update(dt)
end

function love.textinput(t)
    suit.textinput(t) -- for some fucking reason suit registers 2 inputs whenusing registerEvents(), so i'm just registering manually.
end
 
function love.keypressed(key)
    suit.keypressed(key)
end


function love.draw()
  suit.draw()
  StateMachine:draw()
end

function love.wheelmoved(x,y)
  StateMachine.wheelmoved(x,y)
  end