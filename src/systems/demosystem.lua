local DemoSystem = {
    uniqueid = 0,
    entities = {},
    recording = false,
    playing = false,
    file = nil,
    filelines = nil,
    updaterate = 15,
    timepassed = 0,
    tick = 0,
    totaltimepassed = 0,
    prevframe = nil,
    nextframe = nil
}

function DemoSystem:compare( a, b )
    if type( a ) == "table" and type( b ) == "table" then
        return table.equals( a, b )
    else
        return a == b
    end
end

function DemoSystem:applyDiff( diff )
    -- This is where we delete everything it asks in the diff
    for i,v in pairs( diff.removed ) do
        -- Given the unique ID's, we should never
        -- have problems from directly removing
        -- entities like this.
        if DemoSystem.entities[ v ] ~= nil then
            DemoSystem.entities[ v ]:remove()
        end
    end
    -- This is where we add everything it asks in the diff
    for i,v in pairs( diff.added ) do
        local ent = Entity( v.__name, v )
        for o,w in pairs( Entities.entities[ ent.__name ].networkinfo ) do
            local val = v[ w ]
            -- Call the coorisponding function to set the
            -- value
            if ent[ o ] == nil then
                error( "Function " .. o .. " does not exist for entity " .. v.__name )
            end
            ent[ o ]( ent, val )
        end
    end
    -- World interpolation and such should be handled elsewhere
end

function DemoSystem:deltanetcopy( a, b )
    local changed = false
    local netcopy = {}
    -- Network only networked vars
    for i,v in pairs( Entities.entities[ b.__name ].networkinfo ) do
        -- but only network the ones that changed
        if not self:compare( a[v], b[v] ) then
            changed = true
            netcopy[v] = b[v]
        end
    end
    if changed then
        return netcopy
    else
        return nil
    end
end

function DemoSystem.netcopy( orig )
    local netcopy = { __name=orig.__name, demoIndex=orig.demoIndex }
    -- Network all networked vars
    for i,v in pairs( Entities.entities[ orig.__name ].networkinfo ) do
        netcopy[v] = orig[v]
    end
    return netcopy
end

function DemoSystem:addEntity( e, uid )
    uid = uid or self.uniqueid
    -- table.insert( self.entities, e )
    -- If our unique ID conflicts with something, remove the old
    -- entity that had the id.
    if self.entities[ uid ] ~= nil then
        self.entities[ uid ]:remove()
    end
    self.entities[ uid ] = e
    e.demoIndex = uid
    if uid > self.uniqueid then
        self.uniqueid = uid + 1
    else
        self.uniqueid = self.uniqueid + 1
    end
end

function DemoSystem:removeEntity( e )
    self.entities[ e.demoIndex ] = nil
end

function DemoSystem:record( filename )
    local i = 0
    local original = "demos/" .. filename
    love.filesystem.createDirectory( "demos/" )
    filename =  "demos/" .. filename .. ".txt"
    -- Make sure we have a file that doesn't exist
    while love.filesystem.exists( filename ) do
        filename = original .. "_" .. tostring( i ) .. ".txt"
        i = i + 1
    end
    print( "Recording demo to " .. filename )
    self.file = love.filesystem.newFile( filename, "w" )
    self.prevframe = self:generateSnapshot( self.tick, self.totaltimepassed )
    local string = Tserial.pack( self:getFull( self.prevframe ) )
    local success, errormsg = self.file:write( string .. "\n" )
    if not success then
        error( errormsg )
    end
    self.recording = true
    self.playing = false
end

function DemoSystem:play( filename )
    if self.recording then
        self:stop()
    end
    filename = "demos/" .. filename .. ".txt"
    self.file = love.filesystem.newFile( filename, "r" )
    self.filelines = self.file:lines()
    self.playing = true
    self.recording = false
    -- FIXME: Assumes file will have more than two lines in it.
    self.prevframe = Tserial.unpack( self.filelines() )
    self.nextframe = Tserial.unpack( self.filelines() )
    self.tick = self.prevframe.tick
    for i,v in pairs( self.prevframe.added ) do
        local ent = Entity:new( v.__name, v )
        for o,w in pairs( Entities.entities[ ent.__name ].networkinfo ) do
            local val = v[ w ]
            -- Call the coorisponding function to set the
            -- value
            if val ~= nil then
                ent[ o ]( ent, val )
            end
        end
        --print( "Created ent", ent.__name, "at", ent:getPos() )
    end
end

-- Creates a delta snapshot based on what has changed, from a previous full snapshot
function DemoSystem:getDiff( a, b )
    if a == nil then
        return self:getFull( b )
    end
    local diffsnapshot = {}
    diffsnapshot["time"] = b.time
    diffsnapshot["tick"] = b.tick
    diffsnapshot["removed"] = {}
    diffsnapshot["added"] = {}
    diffsnapshot["entities"] = {}
    for i,v in pairs( a.entities ) do
        if b.entities[ i ] == nil then
            table.insert( diffsnapshot["removed"], v.demoIndex )
        end
    end
    for i,v in pairs( b.entities ) do
        if a.entities[ i ] == nil then
            table.insert( diffsnapshot["added"], v )
        else
            diffsnapshot["entities"][ v.demoIndex ] = self:deltanetcopy( a.entities[ i ], v )
        end
    end
    return diffsnapshot
end

-- Creates a delta snapshot that only detects additions/removals of entities
function DemoSystem:getCheapDiff( a, b )
    if a == nil then
        return self:getFull( b )
    end
    local diffsnapshot = {}
    diffsnapshot["time"] = b.time
    diffsnapshot["tick"] = b.tick
    diffsnapshot["removed"] = {}
    diffsnapshot["added"] = {}
    diffsnapshot["entities"] = {}
    for i,v in pairs( a.entities ) do
        if b.entities[ i ] == nil then
            table.insert( diffsnapshot["removed"], v.demoIndex )
        end
    end
    for i,v in pairs( b.entities ) do
        if a.entities[ i ] == nil then
            table.insert( diffsnapshot["added"], v )
        end
    end
    return diffsnapshot
end

-- Get the difference between a nil snapshot to a snapshot
function DemoSystem:getFull( a )
    local snapshot = {}
    snapshot["time"] = a.time
    snapshot["tick"] = a.tick
    snapshot["removed"] = {}
    snapshot["added"] = {}
    snapshot["entities"] = {}
    for i,v in pairs( a.entities ) do
        table.insert( snapshot["added"], v )
    end
    return snapshot
end

-- Gets a snapshot of the current State. of the Game
-- Manually specify the tick and time so that other systems
-- Can generate snapshots
function DemoSystem:generateSnapshot( tick, time )
    local snapshot = {}
    snapshot["time"] = time
    snapshot["tick"] = tick
    snapshot["removed"] = {}
    snapshot["added"] = {}
    snapshot["entities"] = {}
    for i,v in pairs( self.entities ) do
        snapshot["entities"][ v.demoIndex ] = self.netcopy( v )
    end
    return snapshot
end

function DemoSystem:generatePlayerSnapshot( tick, time )
    local snapshot = {}
    snapshot["time"] = time
    snapshot["tick"] = tick
    snapshot["removed"] = {}
    snapshot["added"] = {}
    snapshot["entities"] = {}
    for i,v in pairs( self.entities ) do
        if v.__name == "player" or v:hasComponent( Components.isitem ) then
            snapshot["entities"][ v.demoIndex ] = self.netcopy( v )
        end
    end
    return snapshot
end

function DemoSystem:stop()
    if self.file ~= nil then
        self.file:close()
        self.file = nil
    end
    self.recording = false
    self.tick = 0
    self.totaltimepassed = 0
    self.timepassed = 0
    print( "Recording/Playback stopped!" )
end

function DemoSystem:leave()
    self:stop()
end

function DemoSystem:interpolate( pt, ft, x )
    if ft == nil then
        return pt
    end
    if type( pt ) == "table" then
        local t = {}
        for i,v in pairs( pt ) do
            local pastval = v
            local futureval = ft[i]
            if type( pastval ) == "table" then
                t[i] = self:interpolate( pastval, futureval, x )
            else
                t[i] = pastval + ( futureval - pastval ) * x
            end
        end
        return t
    else
        local pastval = pt
        local futureval = ft
        return pastval + ( futureval - pastval ) * x
    end
end

function DemoSystem:update( dt )
    if self.recording and self.file ~= nil then
        self.totaltimepassed = self.totaltimepassed + dt
        self.timepassed = self.timepassed + dt * 1000
        while self.timepassed > self.updaterate do
            self.tick = self.tick + 1
            self.timepassed = self.timepassed - self.updaterate
            local snapshot = self:generateSnapshot( self.tick, self.totaltimepassed )
            local string = Tserial.pack( self:getDiff( self.prevframe, snapshot ) )
            local success, errormsg = self.file:write( string .. "\n" )
            if not success then
                error( errormsg )
            end
            self.prevframe = snapshot
        end
    elseif self.playing and self.file ~= nil then
        self.totaltimepassed = self.totaltimepassed + dt
        while self.totaltimepassed > self.nextframe.time do
            self.tick = self.tick + 1
            --print( "Moved to tick", self.tick )
            self.prevframe = self.nextframe
            -- This is where we delete everything it asks
            for i,v in pairs( self.prevframe.removed ) do
                --print( "Removed ent", v )
                -- Given the unique ID's, we should never
                -- have problems from directly removing
                -- entities like this.
                if self.entities[ v ] ~= nil then
                    self.entities[ v ]:remove()
                end
            end
            -- This is where we add everything it asks
            for i,v in pairs( self.prevframe.added ) do
                local ent = Entity( v.__name, v )
                for o,w in pairs( Entities.entities[ ent.__name ].networkinfo ) do
                    local val = v[ w ]
                    -- Call the coorisponding function to set the
                    -- value
                    if val ~= nil then
                        ent[ o ]( ent, val )
                    end
                end
                --print( "Created ent", ent.demoIndex, ent.__name, "at", ent:getPos() )
            end
            local test = self.filelines()
            if test == nil then
                self:stop()
                return
            end
            self.nextframe = Tserial.unpack( test )
        end
        -- Uses linear progression
        local x = ( self.totaltimepassed - self.prevframe.time ) / self.nextframe.time
        for i,v in pairs( self.entities ) do
            local pent = self.prevframe.entities[ v.demoIndex ]
            local fent = self.nextframe.entities[ v.demoIndex ]
            -- Make sure the entity is changing somehow
            if pent ~= nil and fent ~= nil then
                for o,w in pairs( Entities.entities[ v.__name ].networkinfo ) do
                    local pastval = pent[ w ]
                    local futureval = fent[ w ]
                    -- Call the coorisponding function to set the
                    -- interpolated value (which can be a table)
                    if pastval ~= nil then
                        v[ o ]( v, self:interpolate( pastval, futureval, x ) )
                    end
                end
            end
        end
    end
end

return DemoSystem
