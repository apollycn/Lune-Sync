local fs = require("@lune/fs") :: any
local roblox = require("@lune/roblox") :: any
local process = require("@lune/process") :: any
local net = require("@lune/net") :: any

if #process.args == 0 then error("Did not provide a place") end
local placeFile = process.args[1] .. ".rbxl"
assert(table.find(fs.readDir("mantle/places"), placeFile), "File " .. placeFile .. " does not exist.")

type script = Script | LocalScript | ModuleScript

placeFile = fs.readFile("mantle/places/" .. placeFile)
local game = roblox.deserializePlace(placeFile)
local scriptDir = "places/" .. process.args[1] .. "/"
local projectFile = (if process.args[2] then process.args[2] else "default") .. ".project.json"
local projectTree = net.jsonDecode(fs.readFile(scriptDir .. projectFile)).tree
local Instance = roblox.Instance

--[[
	[Lowest]
	0: Only telling you when sync starts and ends
	1: Displays top level Services and its properties
	2: Displays rojo project files -- DEFAULT
	3: Displays everything
	[Highest]
--]]
local debugLevel = 2

print("Syncing started...")

function getScriptType(fileName: string): string | nil
    if fileName:match("%.server%.lua[u]?$") then
        return "Script"
    elseif fileName:match("%.client%.lua[u]?$") then
        return "LocalScript"
    elseif fileName:match("%.lua[u]?$") then
        return "ModuleScript"
    end
    return nil
end

function getScript(fileName: string): script | nil
	local scriptType = getScriptType(fileName)
	if scriptType == nil then return nil end
	return Instance.new(scriptType)
end

function getInitFile(files: {string}): string | nil
    for i, file in files do
		local start, _ = file:find("init.")
        if start == 1 and getScriptType(file) then
			table.remove(files, i)
            return file
        end
    end
    return nil
end

function getFileExtension(fileName: string): string | nil
    return fileName:match("%.client%.luau$") or fileName:match("%.server%.luau$") 
        or fileName:match("%.client%.lua$") or fileName:match("%.server%.lua$") 
        or fileName:match("%.luau$") or fileName:match("%.lua$")
end

function getFileNameWithoutExtension(fileName: string): string
    local extensions = { ".client.lua", ".server.lua", ".client.luau", ".server.luau", ".lua", ".luau" }

    for _, ext in ipairs(extensions) do
        if fileName:sub(-#ext) == ext then
            return fileName:sub(1, -(#ext + 1))
        end
    end

    return fileName
end

function createScript(filePath: string, file: string, parent: Instance): script
	local script = getScript(filePath)
	assert(script ~= nil, "Invalid file type")
	local name = getFileNameWithoutExtension(file)

	script.Name = name
	script.Source = fs.readFile(filePath)
	script.Parent = parent

	return script
end

function isEmptyFolder(directory: string): boolean
    directory = directory .. "/"
    for _, v in fs.readDir(directory) do
        local fullPath = directory .. v
        if getScriptType(v) ~= nil or v:sub(-5) == ".rbxm" then
            return false
        elseif fs.isDir(fullPath) then
            if not isEmptyFolder(fullPath) then
                return false
            end
        end
    end
    return true
end

function syncFilePath(path: string, parent: Instance, spaces: string)
	if path:sub(-5) == ".rbxm" then 
		local instances = roblox.deserializeModel(fs.readFile(path))
		for i, v in instances do v.Parent = parent.Parent end
		parent:Destroy()
		return
	end

	path = path .. "/"

	local dir = fs.readDir(path)
	local initFile = getInitFile(dir)
	if initFile and parent:IsA("Folder") then
		local parentOfParent = parent.Parent :: Instance
		local parentName = parent.Name
		parent:Destroy()
		parent = createScript(path .. initFile, parentName .. getFileExtension(initFile), parentOfParent)
	end
	
	for _, fileOrDir in dir do 
		local path2 = path .. fileOrDir
		if getScriptType(path2) then
			createScript(path2, fileOrDir, parent)
			if debugLevel >= 3 then print(spaces .. "└──Syncing", fileOrDir) end
		elseif fs.isDir(path2) then	
			if isEmptyFolder(path2) then continue end

			local folder = Instance.new("Folder") :: Folder
			folder.Name = fileOrDir
			folder.Parent = parent
			if debugLevel >= 3 then print(spaces .. "└──Syncing", fileOrDir) end
			
			syncFilePath(path2, folder, spaces .. "│    ")
		elseif fileOrDir:sub(-5) == ".rbxm" then
			local instances = roblox.deserializeModel(fs.readFile(path2))
			for i, v in instances do v.Parent = parent end
		end
	end
end

function syncProject(parent: any, data: any, spaces: string)
	for name, data2 in data do
		if name == "$className" then continue end
		if name == "$properties" then
			if debugLevel >= 1 then print(spaces .. "└──Properties") end
			for property, value in data2 do
				if debugLevel >= 1 then print(`{spaces}│    └── {property}: {parent[property]} -> {value}`) end
				parent[property] = value
			end
			continue
		end

		local instance = parent

		if name == "$path" then
			local path = scriptDir .. data["$path"]
			if debugLevel >= 2 then print(spaces .. "└──Syncing", data["$path"]) end

			if path:sub(-5) ~= ".rbxm" then
				local initFile = getInitFile(fs.readDir(path))
				if initFile then 
					instance = createScript(path .. "/" .. initFile, initFile, parent) 
				end
			end

			syncFilePath(path, instance, "│    " .. spaces)
		else
			local className = data2["$className"] or "Folder"
			instance = Instance.new(className) :: Instance
			instance.Name = name
			instance.Parent = parent

			if debugLevel >= 2 then print(spaces .. "└──Syncing", name) end
			syncProject(instance, data2, spaces .. "│    ")
		end
	end
end

for serviceName, data in projectTree do 
	if serviceName == "$className" then continue end
	local service = game:GetService(serviceName)

	if debugLevel >= 1 then	print("\nSyncing service:", serviceName) end
	for _, v: Instance in service:GetChildren() do
		v:Destroy()
	end
	syncProject(service, data, "")
end

placeFile = roblox.serializePlace(game)
local placeFilePath = "mantle/places/" .. process.args[1] .. ".rbxl"
fs.writeFile(placeFilePath, placeFile)

print("\nFinished syncing project", placeFilePath)
