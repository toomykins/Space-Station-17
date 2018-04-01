local Entities = { entities = {} }

function Entities:load( dir, packlocation )
    local files = love.filesystem.getDirectoryItems( dir )
    for i,v in pairs( files ) do
        local s = string.find( v, "%.lua" )
        if s then
            local str = string.sub( v, 0, s - 1 )
            PackLocation = packlocation
            local ents = require( dir .. str )
            if type( ents ) == "boolean" then
                error( "Failed to load entities " .. dir .. v .. " nothing was returned!" )
            end
            for o,ent in pairs( ents ) do
                if not ent.__name then
                    print( "Failed to load entity " .. dir .. v .. " __name not supplied" )
                else
                    if self.entities[ ent.__name ] ~= nil then
                        print( "Overriden entity " .. ent.__name .. " with " .. v )
                    end
                    self.entities[ ent.__name ] = ent
                end
            end
        else
            print( "Skipped " .. dir .. v .. " because it's not a lua file..." )
        end
    end
    self:generateNetworkInfo()
end

function Entities:generateNetworkInfo()
    for i,ent in pairs( self.entities ) do
        if type( ent ) == "table" then
            ent.networkinfo = {}
            for o,comp in pairs( ent.components ) do
                table.merge( ent.networkinfo, comp.networkinfo )
            end
        end
    end
end

return Entities
