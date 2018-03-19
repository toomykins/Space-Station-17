Class = require("lib/30log")

Gamestate = require("lib.hump.gamestate")
suit = require("lib.suit")
--require 'enet'
Enet = {
    Client = require( "lib/client" ),
    Server = require( "lib/server" )
}



game = require("game")
menu = require("menu")
game.version="0.0.0"
--nothing works

function love.load(arg)
  if arg[#arg] == "-debug" then require("mobdebug").start() end
  --Gamestate.registerEvents()
  
  Gamestate.switch(menu)
  Gamestate.init()
  
end

function love.update(dt)
  Gamestate.update(dt)
end

function love.textinput(t)
    suit.textinput(t) -- for some fucking reason suit registers 2 inputs.
end
 
function love.keypressed(key)
    suit.keypressed(key)
end


function love.draw()
  suit.draw()
  Gamestate:draw()
end