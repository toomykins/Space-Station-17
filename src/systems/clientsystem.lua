-- Majority of the work is already done with my demoing system :)

local ClientSystem = {
    running = false,
    time = 0,
    players = nil,
    tick = 0,
    lastrecievetime = 0,
    lastshot = nil,
    prevshot = nil,
    timeout = 10,
    nextshot = nil,
    newesttick = 0,
    id = nil,
    player = nil,
    playermemory = {},
    playeractualpos = Vector( 0, 0 ),
    delay = 0/1000,
    faulttolerance = 0,
    predictionfixspeed = 10,
    client = nil,
    sendtext = {},
    chat = {},
    snapshots = {},
    players = {}
}

function ClientSystem:sendText( text )
    table.insert( self.sendtext, text )
end

function ClientSystem:addText( textarray )
    for i,v in pairs( textarray ) do
        table.insert( self.chat, v )
    end
    if self.onTextReceive then
        self.onTextReceive( textarray )
    end
end

function ClientSystem:setID( id )
    self.id = id
    -- Find our player
    for i,v in pairs( DemoSystem.entities ) do
        if v.playerid == self.id then
            self.player = v
            self.player:setLocalPlayer( true )
        end
    end
end

function ClientSystem:updatePlayers( players )
    if not players then
        return
    end
    if not self.players then
        self.players = {}
        for i,v in pairs( players ) do
            self.players[ v.id ] = v
        end
    else
        for i,v in pairs( players ) do
            self.players[ v.id ] = table.merge( self.players[ v.id ], v )
        end
    end
    if self.onPlayerDataChange then
        self.onPlayerDataChange( self.players )
    end
end

function ClientSystem:startLobby( ip, port )
    Enet.Client:init( ip, port )
    Enet.Client:setCallbacks( self.onLobbyReceive, self.onDisconnect, self.onConnect )
end

function ClientSystem:startGame( snapshot )
    MapSystem:load( snapshot.map )
    Enet.Client:setCallbacks( self.onGameReceive, self.onDisconnect, nil )
    self.time = snapshot.time
    --self.time = snapshot.time - 1
    self.tick = snapshot.tick
    self:saveSnapshot( snapshot.tick, snapshot )
    self.lastshot = self:getSnapshot( snapshot.tick )
    self.prevshot = self:getSnapshot( snapshot.tick )
    self.nextshot = nil
    self.running = true
    -- Add/remove required entities
    DemoSystem:applyDiff( self.prevshot )
    -- Find our player
    for i,v in pairs( DemoSystem.entities ) do
        if v.playerid == self.id then
            self.player = v
            self.player:setLocalPlayer( true )
            self.playerpos = v:getPos()
        end
    end
end

function ClientSystem:fixPredictionError( snapshot, actualpos, actualvel )
    if not self.player then
        return
    end
    if not snapshot then
        return
    end
    -- First we save the player's original position
    local savepos = self.player:getPos()
    -- Here we loop through all dynamic physical bodies and disable them,
    -- this is so that they don't move when we call Physics:update().
    local ents = World:getAllWithComponent( Components.physical )
    for i,v in pairs( ents ) do
        if v.physicstype ~= "static" and v ~= self.player then
            v:setActive( false )
        end
    end
    -- We move the world back in time, so that the player correctly gets
    -- input from the past.
    local realtime = World:getCurrentTime()
    World:setCurrentTime( snapshot.time )

    -- We finally move the player into the past, at the actual position
    -- and velocity
    self.player:setPos( actualpos )
    if not actualvel then
        self.player:setLinearVelocity( snapshot.velocity )
    else
        self.player:setLinearVelocity( actualvel )
    end

    -- Now that our snapshot is correctly set up, we save it.
    self:savePlayerSnapshot( snapshot.tick )
    local tick = snapshot.tick + 1
    -- And then update him.
    local snapnew = self:getPlayerSnapshot( tick )
    local snapold = self:getPlayerSnapshot( tick - 1 )
    while snapnew and snapold do
        local time = snapnew.time - snapold.time
        -- We can't actually update the world, since we only put the
        -- player into the past. So instead we just update the world's
        -- idea of how much time has passed, and update the player alone.
        Physics:update( time )
        -- We can't update the player normally, we just want the
        -- controllable and physical parts updated.
        Components.controllable.update( self.player, time )
        Components.physical.update( self.player, time )
        World:setCurrentTime( snapnew.time )
        self:savePlayerSnapshot( tick )
        tick = tick + 1
        snapnew = self:getPlayerSnapshot( tick )
        snapold = self:getPlayerSnapshot( tick - 1 )
    end
    -- Make sure everything turned out the way it's supposed to.
    local time = realtime - World:getCurrentTime()
    Physics:update( time )
    Components.controllable.update( self.player, time )
    Components.physical.update( self.player, time )
    World:setCurrentTime( realtime )
    self:savePlayerSnapshot( tick )

    -- Then finally unfreeze everything
    for i,v in pairs( ents ) do
        if v.physicstype ~= "static" and v ~= self.player then
            v:setActive( true )
        end
    end
    -- Everything should now be in the correct position!
    -- However to keep things from jumping around, we use a light spring
    -- to influence the player to be in the right position.
    self.playeractualpos = self.player:getPos()
    -- Then we put the player back to its original position.
    self.player:setPos( savepos )
end

function ClientSystem:addSnapshot( snapshot )
    if not snapshot.tick then
        return
    end
    if self.player then
        local p = snapshot.entities[ self.player.demoIndex ]
        if p then
            if p.pos then
                local vec = Vector( p.pos.x, p.pos.y )
                if p.velocity then
                    local vel = Vector( p.velocity.x, p.velocity.y )
                end
                local psnapshot = self:getPlayerSnapshot( snapshot.lastregistered )
                if psnapshot then
                    local diff = vec:dist( psnapshot.pos )
                    -- If our prediction is too far off, we need to do our
                    -- best to correct not only the actual player position,
                    -- but our player position memory as well. So we just
                    -- resimulate all input. :)
                    if diff > self.faulttolerance then
                        self:fixPredictionError( psnapshot, vec, vel )
                    end
                end
            end
        end
    end
    self:saveSnapshot( snapshot.tick, snapshot )
    if self.newesttick < snapshot.tick then
        self.newesttick = snapshot.tick
    end
end

function ClientSystem:stop()
    self.time = 0
    self.lastrecievetime = 0
    self.players = nil
    self.tick = 0
    self.lastshot = nil
    self.prevshot = nil
    self.nextshot = nil
    self.newesttick = 0
    self.id = nil
    self.player = nil
    self.playerpos = Vector( 0, 0 )
    Enet.Client:disconnect()
    self.running = false
end

function ClientSystem:getSnapshot( tick )
    for i,v in pairs( self.snapshots ) do
        if tick == v.tick then
            return v, i
        end
    end
    return nil
end

function ClientSystem:getPlayerSnapshot( tick )
    for i,v in pairs( self.playermemory ) do
        if tick == v.tick then
            return v, i
        end
    end
    return nil
end

function ClientSystem:saveSnapshot( tick, snapshot )
    local v, i = self:getSnapshot( tick )
    if v ~= nil then
        self.snapshots[i] = snapshot
    else
        table.insert( self.snapshots, 1, snapshot )
    end
    table.sort( self.snapshots, function( a, b )
        return a.time > b.time
    end )
    while #self.snapshots > 50 do
        table.remove( self.snapshots )
    end
end

function ClientSystem:savePlayerSnapshot( tick )
    if self.player then
        local v, i = self:getPlayerSnapshot( tick )
        if v ~= nil then
            self.playermemory[i] = { pos = self.player:getPos(), velocity = self.player:getLinearVelocity(), time=World:getCurrentTime(), tick=self.tick }
        else
            table.insert( self.playermemory, 1, { pos = self.player:getPos(), velocity = self.player:getLinearVelocity(), time=World:getCurrentTime(), tick=self.tick } )
        end
    end
    table.sort( self.playermemory, function( a, b )
        return a.time > b.time
    end )
    while #self.playermemory > 50 do
        table.remove( self.playermemory )
    end
end

function ClientSystem:update( dt )
    Enet.Client:update()
    if self.lastrecievetime and self.time - self.lastrecievetime > 2 then
        if not self.warntext then
            self.warntext = loveframes.Create( "text" )
            self.warntext:SetDefaultColor( 255, 0, 0, 255 )
            self.warntext:SetPos( 0, 0 )
        end
        self.warntext:SetText( "Connection Error: " .. math.floor( self.time - self.lastrecievetime ) .. " / " .. self.timeout )
    elseif self.warntext then
        self.warntext:Remove()
    end
    if self.lastrecievetime and self.time - self.lastrecievetime > self.timeout then
        self:stop()
        StateMachine.switch( State.menu )
    end
    self.time = self.time + dt
    if not self.running then
        return
    end
    -- Use a light spring to fix prediction errors
    if self.player ~= nil and self.playeractualpos ~= nil then
        local diff = self.playeractualpos - self.player:getPos()
        diff:normalize_inplace()
        local dist = self.player:getPos():dist( self.playeractualpos )
        if dist > 128 then
            self.player:setPos( self.playeractualpos )
        else
            self.player:setPos( self.player:getPos() + ( diff * dist * dt * self.predictionfixspeed ) )
        end
    end
    if self.player then
        self.player:addControlSnapshot( BindSystem:getControls(), World:getCurrentTime() )
    end
    Physics:update( dt )
    World:update( dt )

    -- We shouldn't do anything as long as we're too far in the
    -- past
    if self.time < self.prevshot.time + self.delay then
        return
    end
    -- If our next snapshot doesn't exist, try to find it
    if self.nextshot == nil then
        for i = self.tick + 1, self.tick + 10, 1 do
            self.nextshot = self:getSnapshot( i )
            if self.nextshot ~= nil then
                break
            end
        end
        -- If we couldn't find a snapshot, we need to extrapolate
        if self.nextshot == nil then
            local x = ( self.time - self.prevshot.time + self.delay ) / (30/1000 )
            -- Interpolate with a x > 1 makes it extrapolate
            self.interpolate( self.lastshot, self.prevshot, x )
            return
        end
    end
    -- If we're in between the two we interpolate the world
    if self.time > self.prevshot.time + self.delay and self.time < self.nextshot.time + self.delay then
        -- Uses linear progression
        local x = ( self.time - ( self.prevshot.time + self.delay ) ) / ( ( self.nextshot.time + self.delay ) - ( self.prevshot.time + self.delay ) )
        self.interpolate( self.prevshot, self.nextshot, x )
        return
    end
    -- If we're past the next frame, we up our tick and re-run ourselves.
    if self.time > self.nextshot.time + self.delay then
        -- First we really need to make sure our interpolation finished completely
        for i,v in pairs( self.nextshot.entities ) do
            local ent = DemoSystem.entities[ i ]
            if ent and ent.playerid == ClientSystem.id then
            elseif ent then
                for o,w in pairs( Entities.entities[ ent.__name ].networkinfo ) do
                    local val = v[ w ]
                    -- Call the coorisponding function to set the value
                    if not ent[ o ] then
                        error( "Entity " .. ent.__name .. " is missing function " .. o .. "!" )
                    end
                    if val then
                        ent[ o ]( ent, val )
                    end
                end
            end
        end
        -- Here we send our current controls to the server
        self:sendUpdate()
        self.tick = self.nextshot.tick
        self.lastshot = self.prevshot
        self.prevshot = self.nextshot
        self.nextshot = nil
        -- This is where we delete/add everything it asks
        DemoSystem:applyDiff( self.prevshot )
        -- Find our player
        for i,v in pairs( DemoSystem.entities ) do
            if v.playerid == self.id then
                self.player = v
                self.player:setLocalPlayer( true )
                self.playerpos = v:getPos()
            end
        end
        -- This is where we interpolate forward a bit
        self:update( 0 )
        return
    end
end

function ClientSystem:sendUpdate()
    local t = {}
    --t.tick = self.newesttick - 1
    t.tick = self.tick
    t.control = BindSystem:getControls()
    if #self.sendtext > 0 then
        t.chat = self.sendtext[ 1 ]
        table.remove( self.sendtext, 1 )
    end
    if t.chat then
        Enet.Client:send( Tserial.pack( t ), 0, "reliable" )
    else
        Enet.Client:send( Tserial.pack( t ) )
    end
    self:savePlayerSnapshot( self.tick )
end

function ClientSystem.interpolate( prevshot, nextshot, x )
    for i,v in pairs( DemoSystem.entities ) do
        local pent = prevshot.entities[ v.demoIndex ]
        local fent = nextshot.entities[ v.demoIndex ]
        -- We do NOT extrapolate/interpolate our player
        -- Since it's so important to have it be responsive
        -- as well as smooth, we use a light spring instead to fix
        -- prediction errors
        if v.playerid == ClientSystem.id then
            return
        end
        -- Since everything is delta-compressed, only a nil future entity
        -- would indicate that the entity didn't change.
        -- So we're going to have to fill in the past entity snapshot
        -- with some information if it doesn't exist.
        if pent == nil and fent ~= nil then
            local copy = {}
            for o,w in pairs( Entities.entities[ v.__name ].networkinfo ) do
                copy[w] = v[w]
            end
            prevshot.entities[ v.demoIndex ] = copy
            pent = copy
        end
        -- Make sure the entity is changing somehow
        if pent ~= nil and fent ~= nil then
            for o,w in pairs( Entities.entities[ v.__name ].networkinfo ) do
                local pastval = pent[w]
                local futureval = fent[w]
                -- ANGLE, needs special care
                if w == "rot" then
                    if pastval and futureval then
                        if math.abs( pastval - futureval ) > math.pi then
                            if pastval < futureval then
                                pastval = pastval + math.pi * 2
                            else
                                futureval = futureval + math.pi * 2
                            end
                        end
                    end
                end

                -- Call the coorisponding function to set the
                -- interpolated value (which can be a table)
                if pastval ~= nil then
                    v[ o ]( v, DemoSystem:interpolate( pastval, futureval, x ) )
                end
            end
        elseif fent ~= nil then
            error( "Something is dramatically wrong I think, I don't remember why I have this error here." )
        end
    end
end

function ClientSystem.onConnect()
    Enet.Client:send( Tserial.pack( { name=OptionSystem.options.playername, avatar=OptionSystem.options.playeravatar } ), 0, "reliable" )
end

function ClientSystem.onLobbyReceive( data )
    local t = Tserial.unpack( data )
    if t.clientid then
        ClientSystem:setID( t.clientid )
    end
    if t.map then
        StateMachine.switch( State.client )
        -- We have to load everything after, else we may remove GUI elements
        ClientSystem:startGame( t )
    end
    if t.players then
        ClientSystem:updatePlayers( t.players )
    end
    ClientSystem.lastrecievetime = ClientSystem.time
end

function ClientSystem.onDisconnect()
    ClientSystem:stop()
    StateMachine.switch( State.menu )
    local frame = loveframes.Create( "frame" )
    frame:SetName( "Disconnected..." )
    frame:Center()
    local text = loveframes.Create( "text", frame )
    text:SetText( "We got disconnected from the server!" )
    text:Center()
    local button = loveframes.Create( "button", frame )
    button:SetText( "Ok" )
    button:Center()
    button:SetY( button:GetY() + 100 )
    button.frame = frame
    button.OnClick = function( object, x, y )
        object.frame:Remove()
    end
end

function ClientSystem.onGameReceive( data )
    local t = Tserial.unpack( data )
    if t.clientid then
        ClientSystem:setID( t.clientid )
    end
    if t.map then
        MapSystem:load( t.map )
    end
    if t.players then
        ClientSystem:updatePlayers( t.players )
    end
    if t.chat then
        ClientSystem:addText( t.chat )
    end
    ClientSystem:addSnapshot( t )
    ClientSystem.lastrecievetime = ClientSystem.time
end


return ClientSystem
