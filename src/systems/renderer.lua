-- System that handles drawing entities to the screen, uses a layer system to manage depth.
-- Adds several values to the entity that shouldn't be altered manually: rendererIndex, layer
-- The values are used to locate the entity within the table.

local Renderer = {
    uid = 0,
    layers={
        floor={},
        normal={},
        special={},
        space={}
    },
    lights={},
    glowables={},
    lines={},
    debugs={},
    worldcanvas=nil,
    lightcanvas=nil,
    shadowcanvas=nil,
    fullbright=false,
    maskshader=nil
}

function Renderer:addDebugEntity( e )
    self.debugs[ self.uid ] = e
    e.debugrendererIndex = self.uid
    self.uid = self.uid + 1
end

function Renderer:removeDebugEntity( e )
    self.debugs[ e.debugrendererIndex ] = nil
end

function Renderer:addEntity( e )
    if not self.layers[ e.layer ] then
        error( "Layer " .. e.layer .. " doesn't exist!" )
    end
    self.layers[ e.layer ][ self.uid ] = e
    e.rendererIndex = self.uid
    self.uid = self.uid + 1
end

function Renderer:removeEntity( e )
    self.layers[ e.layer ][ e.rendererIndex ] = nil
end

function Renderer:addGlowable( e )
    self.glowables[ self.uid ] = e
    e.glowableIndex = self.uid
    self.uid = self.uid + 1
end

function Renderer:removeGlowable( e )
    self.glowables[ e.glowableIndex ] = nil
end

function Renderer:addLine( e )
    self.lines[ self.uid ] = e
    e.lineIndex = self.uid
    self.uid = self.uid + 1
end

function Renderer:removeLine( e )
    self.lines[ e.lineIndex ] = nil
end

function Renderer:addLight( e )
    self.lights[ self.uid ] = e
    e.lightIndex = self.uid
    self.uid = self.uid + 1
end

function Renderer:removeLight( e )
    self.lights[ e.lightIndex ] = nil
end

function Renderer:setFullbright( fullbright )
    self.fullbright = fullbright
end

function Renderer:getFullbright()
    return self.fullbright
end

function Renderer:toggleFullbright()
    self.fullbright = not self.fullbright
end


function Renderer:updateLights( e )
    for i,v in pairs( self.lights ) do
        v.changed = true
    end
end

function Renderer:load()
    self.maskshader = love.graphics.newShader( [[
        vec4 effect ( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords ) {
            // a discarded fragment will fail the stencil test.
            if ( Texel( texture, texture_coords ).a == 0.0)
                discard;
            return vec4(1.0);
        }
    ]] )
    self.shadowshader = love.graphics.newShader( [[
        vec4 effect ( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords ) {
            // We use hot pink to indicate the inverse stencil
            // Hope that we don't have anything else be this specific shade of hot pink!
            if ( Texel( texture, texture_coords ).rgb != vec3( 255.0/255.0, 105.0/255.0, 180.0/255.0 ) )
                discard;
            return vec4(1.0);
        }
    ]] )
    self.lightshader = love.graphics.newShader( [[
        vec4 effect ( vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords ) {
            // We need to be capable of overbright, so we just multiply
            // everything by 2
            vec4 realcolor = Texel( texture, texture_coords ) * color * 2;
            return vec4( realcolor.rgb, color.a );
        }
    ]] )
    self.lightcanvas = love.graphics.newCanvas( love.graphics.getDimensions() )
    self.worldcanvas = love.graphics.newCanvas( love.graphics.getDimensions() )
    self.shadowcanvas = love.graphics.newCanvas( love.graphics.getDimensions() )
end

function Renderer:resize( w, h )
    self.lightcanvas = love.graphics.newCanvas( w, h )
    self.worldcanvas = love.graphics.newCanvas( w, h )
    self.shadowcanvas = love.graphics.newCanvas( w, h )
end

function Renderer:draw( debug )
    -- Before we draw our normal layer we depth sort it.
    local sortedstuff = {}
    for i,v in pairs( self.layers.normal ) do
        table.insert( sortedstuff, v )
    end
    table.sort( sortedstuff, function( a, b )
        return a and b and a.pos.y<b.pos.y
    end )
    debug = debug or false
    -- Draw world to world canvas
    CameraSystem:attach()
    love.graphics.setCanvas( self.worldcanvas )
    self.worldcanvas:clear()
    for o,w in pairs( self.layers.floor ) do
        love.graphics.setColor( w.color )
        love.graphics.draw( w.drawable, w.pos.x, w.pos.y, w.rot, w.scale.x, w.scale.y, w.originoffset.x, w.originoffset.y )
        love.graphics.setColor( 255, 255, 255, 255 )
    end
    for o,w in pairs( self.lines ) do
        love.graphics.setColor( w.color )
        love.graphics.setLineWidth( w.linewidth )
        love.graphics.line( w.linepoints )
    end
    for o,w in pairs( sortedstuff ) do
        love.graphics.setColor( w.color )
        love.graphics.draw( w.drawable, w.pos.x, w.pos.y, w.rot, w.scale.x, w.scale.y, w.originoffset.x, w.originoffset.y )
        love.graphics.setColor( 255, 255, 255, 255 )
    end
    love.graphics.setCanvas()
    CameraSystem:detach()

    -- Draw lights to light canvas
    if not self.fullbright then
        love.graphics.setBlendMode( "additive" )
        love.graphics.setCanvas( self.lightcanvas )
        self.lightcanvas:clear()
        CameraSystem:attach()
        for i,v in pairs( self.lights ) do
            -- Use stencils to create shadows
            if v.shadowmeshdraw ~= nil then
                love.graphics.setBlendMode( "alpha" )
                love.graphics.setCanvas( self.shadowcanvas )
                self.shadowcanvas:clear()
                love.graphics.setColor( 255, 105, 180, 255 )
                love.graphics.draw( v.shadowmeshdraw )
                love.graphics.setBlendMode( "additive" )
                love.graphics.setColor( 255, 255, 255, 255 )
                for o,w in pairs( v.shadowobjects ) do
                    love.graphics.draw( w.drawable, w.pos.x, w.pos.y, w.rot, w.scale.x, w.scale.y, w.originoffset.x, w.originoffset.y )
                end
                love.graphics.setBlendMode( "additive" )
                love.graphics.setCanvas( self.lightcanvas )
                love.graphics.setInvertedStencil( function()
                    love.graphics.setShader( self.shadowshader )
                    love.graphics.setColor( 255, 255, 255, 255 )
                    CameraSystem:detach()
                    love.graphics.draw( self.shadowcanvas )
                    CameraSystem:attach()
                    love.graphics.setShader()
                end )
            end
            love.graphics.setShader( self.lightshader )
            love.graphics.setColor( 255, 255, 255, 255 * v.lightintensity )
            love.graphics.draw( v.lightdrawable, v.pos.x, v.pos.y, v.lightrot, v.lightscale.x, v.lightscale.y, v.lightoriginoffset.x, v.lightoriginoffset.y )
            love.graphics.setColor( 255, 255, 255, 255 )
            love.graphics.setShader()
        end
        love.graphics.setInvertedStencil()

        -- Draw glowables to the light canvas
        for i,v in pairs( self.glowables ) do
            love.graphics.draw( v.glowdrawable, v.pos.x, v.pos.y, v.rot, v.scale.x, v.scale.y, v.gloworiginoffset.x, v.gloworiginoffset.y )
        end

        love.graphics.setCanvas()
        CameraSystem:detach()
    end
    -- Draw world to screen
    love.graphics.setBlendMode( "alpha" )
    love.graphics.draw( self.worldcanvas )

    -- Multiply the light canvas to the world, but only if we have fullbright disabled
    if not self.fullbright then
        love.graphics.setBlendMode( "multiplicative" )
        love.graphics.draw( self.lightcanvas )
        love.graphics.setBlendMode( "alpha" )
    end

    -- Now draw the space layer behind everything using stencils
    -- Things drawn in space are always fullbright
    love.graphics.setInvertedStencil( function()
        -- Shader is required to discard completely transparent fragments
        love.graphics.setShader( self.maskshader )
        love.graphics.draw( self.worldcanvas )
        love.graphics.setShader()
    end )
    for i,v in pairs( self.layers.space ) do
        love.graphics.setColor( v.color )
        love.graphics.draw( v.drawable, v.pos.x, v.pos.y, v.rot, v.scale.x, v.scale.y, v.originoffset.x, v.originoffset.y )
        love.graphics.setColor( 255, 255, 255, 255 )
    end
    love.graphics.setInvertedStencil()

    CameraSystem:attach()
    -- Draw special top-layer that's always fullbright, for things like ghosts and such
    for i,v in pairs( self.layers.special ) do
        love.graphics.setColor( v.color )
        love.graphics.draw( v.drawable, v.pos.x, v.pos.y, v.rot, v.scale.x, v.scale.y, v.originoffset.x, v.originoffset.y )
        love.graphics.setColor( 255, 255, 255, 255 )
    end
    if debug then
        love.graphics.setColor( 255, 255, 255, 155 )
        for i,v in pairs( self.debugs ) do
            local p = v:getPos()
            love.graphics.line( p.x-5, p.y-5, p.x+5, p.y+5 )
            love.graphics.line( p.x+5, p.y-5, p.x-5, p.y+5 )
            love.graphics.print( v.__name, p.x, p.y+10 )
        end
    end
    CameraSystem:detach()
end

return Renderer
