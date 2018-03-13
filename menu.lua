-- suit up
local suit = require 'lib.suit'
--Gamestate = require("lib.hump.gamestate")
-- storage for text input
local input = {text = ""}

-- make love use font which support CJK text
function menu:init()
end

-- all the UI is defined in love.update or functions that are called from here
function menu:update(dt)
	-- put the layout origin at position (100,100)
	-- the layout will grow down and to the right from this point
	suit.layout:reset(100,100)

	-- put an input widget at the layout origin, with a cell size of 200 by 30 pixels
	suit.Input(input, suit.layout:row(200,30))

	-- put a label that displays the text below the first cell
	-- the cell size is the same as the last one (200x30 px)
	-- the label text will be aligned to the left
	suit.Label("Hello, "..input.text, {align = "left"}, suit.layout:row())

	-- put an empty cell that has the same size as the last cell (200x30 px)
	suit.layout:row()

	-- put a button of size 200x30 px in the cell below
	-- if the button is pressed, quit the game
	if suit.Button("Close", suit.layout:row()).hit then
		Gamestate.switch(game)
    Gamestate.init()
    love.window.setTitle("ive showed you my dick now answer me")
	end
end

function menu:draw()
	-- draw the gui
	
end

function menu:textedited(text, start, length)
    -- for IME input
    suit.textedited(text, start, length)
end

function menu:textinput(t)
	-- forward text input to SUIT
	suit.textinput(t)
end

function menu:keypressed(key)
	-- forward keypresses to SUIT
	suit.keypressed(key)
end