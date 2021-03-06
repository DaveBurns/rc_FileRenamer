--[[
        Init.lua (plugin initialization module)
--]]


-- Unstrictify _G
local mt = getmetatable( _G ) or {}
mt.__newIndex = function( t, n, v )
    rawset( t, n, v )
end
mt.__index = function( t, n )
    return rawget( t, n )
end
setmetatable( _G, mt )



--   I N I T I A L I Z E   L O A D E R
do
    -- step 0: replace load-file/do-file with versions that will work with non-ascii characters in path.
    local LrPathUtils = import 'LrPathUtils'
    local LrFileUtils = import 'LrFileUtils'
    
    -- this may not be a strict requirement for every plugin, but advanced debug requires it for logging, as does exiftool session, and it's required for 'Preferences', etc..
    if not LrFileUtils.isWritable( _PLUGIN.path ) then -- typically due to being located in Windows "Program Files" dir or Mac's "Applications" folder.
        error( "Plugin directory must be writable, '".._PLUGIN.path.."' is not. Remedy by re-locating to writable user folder like \"Documents\"." ) -- filename/line-no prefix ok.
    end
    
    _G.loadfile = function( file )
        -- Note: file is optional, and if not provided means stdin.
        -- Shouldn't happen in Lr env(?) but just in case...
        if file == nil then
            return nil, "load-file from stdin not supported in Lr env."
        end
        local filename = LrPathUtils.leafName( file )
        local status, contents = pcall( LrFileUtils.readFile, file ) -- lr-doc says nothing about throwing errors, or if contents returned could be nil: best to play safe...
        if status then
            if contents then
                local func, err = loadstring( contents, filename ) -- returns nil, errm if any troubles: no need for pcall (short chunkname required for debug).
                if func then
                    return func
                else
                    --return nil, "loadstring was unable to load contents returned from: " .. tostring( file or 'nil' ) .. ", error message: " .. err -- lua guarantees a non-nil error message string.
                    local x = err:find( filename )
                    if x then
                        err = err:sub( x ) -- strip the funny business at the front: just get the good stuff...
                    elseif err:len() > 77 then -- dunno if same on Mac ###2
                        err = err:sub( -77 )
                    end
                    return nil, err -- return *short* error message
                end
            else
                -- return nil, "Unable to obtain contents from file: " .. tostring( file ) -- probably also too long.
                return nil, "No contents in: " .. filename
            end
        else
            -- return nil, "Unable to read file: " .. tostring( file ) .. ", error message: " .. tostring( contents or 'nil' ) -- probably also too long.
            return nil, "Unable to read file: " .. filename
        end
    end
    _G.dofile = function( file )
        local func, err = loadfile( file ) -- returns nil, errm if any problems.
        if func then
            local result = {}
            result[1], result[2], result[3], result[4], result[5], result[6], result[7], result[8], result[9], result[10], result[11], result[12], result[13], result[14], result[15], result[16], result[17], result[18], result[19], result[20], result[21] = func() -- throw error, if any.
            if result[21] ~= nil then
                error( "Modified dofile only supports 20 return values" )
            else
                return unpack( result )
            end
        else
            error( err ) -- error message guaranteed.
        end
    end
    local LrPathUtils = import 'LrPathUtils'
    local frameworkDir = LrPathUtils.child( _PLUGIN.path, "Framework" )
    local reqFile = frameworkDir .. "/System/Require.lua"
    local status, result1, result2 = pcall( dofile, reqFile ) -- gives good "file-not-found" error - no reason to check first (and is ok with forward slashes).
    if status then
        _G.Require = result1
        _G.Debug = result2
        assert( Require ~= nil, "no require" )
        assert( Debug ~= nil, "no debug" )
        assert( require == Require.require, "'require' is not what's expected" ) -- synonym: helps remind that its not vanilla 'require'.
    else
        error( result1 ) -- we can trust pcall+dofile to return a non-nil error message.
    end
    if _PLUGIN.path:sub( -12 ) == '.lrdevplugin' then
        Require.path( frameworkDir )
    else
        assert( _PLUGIN.path:sub( -9 ) == '.lrplugin', "Invalid plugin extension" )
        Require.path( 'Framework' ) -- relative to lrplugin dir.
    end
end




--   S E T   S T R I C T   G L O B A L   P O L I C Y
_G.Globals = require( 'System/Globals' )
_G.gbl = Globals:new{ strict = true } -- strict from here on out for everything *except* statements in this module.



--   I N I T I A L I Z E   F R A M E W O R K
_G.Object = require( 'System/Object' )                         -- base class of base object factory.
_G.ObjectFactory = require( 'System/ObjectFactory' )           -- base class of special object factory.
_G.InitFramework = require( 'System/InitFramework' )           -- class of object used for initialization.
_G.ExtendedObjectFactory = require( 'ExtendedObjectFactory' )    -- class of object used to create objects of classes not mandated by the framework.
_G.objectFactory = ExtendedObjectFactory:new()               -- object used to create objects of classes not mandated by the framework.
_G.init = InitFramework:new()                               -- create initializer object, of class specified here.
init:framework()                                            -- initialize framwork, relying on object factory to create framework objects of proper class.



--   P L U G I N   S P E C I F I C   I N I T
_G.LrExportSettings = import 'LrExportSettings'
_G.LrXml = import 'LrXml'
_G.XmlRpc = require( "Communication/XmlRpc" )
_G.ExtendedManager = require( "ExtendedManager" )
_G.ExifTool = require( "ExternalApps/ExifTool" )
_G.exifTool = ExifTool:new{ optional=str:fmtx( "Exiftool is required for some renaming presets (e.g. Exif Rename), but not others (e.g. Search and Replace).\n \nIf, after installing exiftool in the default location, ^1 can still not find it, then please let me know, and/or if installing to non-default location, edit \"advanced settings\" (plugin manager, preset manager section - drop-down menu) end enter directly the correct path to the exiftool executable file.", app:getAppName() ) }
_G.ExtendedBackground = require( 'ExtendedBackground' ) -- base class is loaded by framework.
_G.background = ExtendedBackground:new()
_G.Lightroom = require( 'Lightroom/Lightroom' ) -- not included in framework by default, yet.
_G.lightroom = Lightroom:new()
_G.Renamer = require( "Renamer" )
_G.renamer = Renamer:new()



--   I N I T I A T E   A S Y N C H R O N O U S   I N I T   A N D   B A C K G R O U N D   T A S K
ExtendedManager.initPrefs() -- remember to include all dependent plugin prefs (plugin generator is not helping in this regard, yet)
app:initDone() -- synchronous init done.
-- Consider async init/background task.
if background then -- not strict in here.
    background:start() -- by default just does init then quits - consider using pref to enable/disable background if optional, else force continuation into background processing...
end



-- the end.