Gamestate = require("lib.hump.gamestate")
suit = require("lib.suit")
require 'enet'
Enet = {
    Client = require( "lib/client" ),
    Server = require( "lib/server" )
}
menu = {}
game = {}
game.version="0.0.0"

dofile("game.lua")
dofile("menu.lua") -- do not work do not try
--copy shit from the other project since you're useless
--also get better at coding you shit

--nothing works

function love.load(arg)
  if arg[#arg] == "-debug" then require("mobdebug").start() end
  Gamestate.registerEvents()
  Gamestate.switch(menu)
  Gamestate.init()
  
end

function love.update(dt)
  Gamestate.update(dt)
end
function love.draw()
  Gamestate.draw()
  suit.draw()
end

function love.keypressed(key)
  Gamestate.keypressed(key)
end
function love.textedited(text, start, length)
  Gamestate.textedited(text,start,length)
end
function love.textinput(t)
  Gamestate.textinput(t)
end
function love.wheelmoved(x,y)
  Gamestate.wheelmoved(x,y)
end