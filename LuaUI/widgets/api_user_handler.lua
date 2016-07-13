--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name      = "Users Handler",
		desc      = "Handles user visualisation and interaction.",
		author    = "GoogleFrog",
		date      = "11 July 2016",
		license   = "GNU LGPL, v2.1 or later",
		layer     = -100000,
		enabled   = true  --  loaded by default?
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Local Variables

local battleUsers = {}
local channelUsers = {}
local teamUsers = {}

local userListList = {
	battleUsers,
	channelUsers,
	teamUsers
}

local IMAGE_AFK = "luaui/images/away.png"
local IMAGE_BATTLE = "luaui/images/battle.png"
local IMAGE_INGAME = "luaui/images/ingame.png"
local IMAGE_FLAG_UNKNOWN = "luaui/images/flags/unknown.png"
local IMAGE_AUTOHOST = "luaui/images/ranks/robot.png"
local IMAGE_MODERATOR = "luaui/images/ranks/moderator.png"

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Utilities

local function GetUserCountryImage(userName, userControl)
	local userInfo = userControl.lobby:GetUser(userName) or {}
	if userInfo.country then
		local fileName = "luaui/images/flags/" .. string.lower(userInfo.country) .. ".png"
		if VFS.FileExists(fileName) then
			return fileName
		end
	end
	return IMAGE_FLAG_UNKNOWN
end

local function GetUserComboBoxOptions(userName, isInBattle, userControl)
	local userInfo = userControl.lobby:GetUser(userName) or {}
	local userBattleInfo = userControl.lobby:GetUserBattleStatus(userName) or {}
	local myUserName = userControl.lobby:GetMyUserName()
	local comboOptions = {}
	if (not userBattleInfo.aiLib) and userName ~= myUserName then
		comboOptions[#comboOptions + 1] = "Message"
		
		if (not isInBattle) and userInfo.battleID then
			comboOptions[#comboOptions + 1] = "Join Battle"
		end
		
		if userInfo.myFriend then -- TODO: Implement
			comboOptions[#comboOptions + 1] = "De-Friend"
		else
			comboOptions[#comboOptions + 1] = "Friend"
		end
		comboOptions[#comboOptions + 1] = "Report"
	end
	
	if (userBattleInfo.aiLib and userBattleInfo.owner == myUserName) or userControl.lobby:GetMyIsAdmin() then
		comboOptions[#comboOptions + 1] = "Kick"
	end
	
	if #comboOptions == 0 then
		comboOptions[1] = Label:New {
			x = 0,
			y = 0,
			width = 100,
			height = 30,
			font = WG.Chobby.Configuration:GetFont(1),
			caption = "No Actions",
		}
	end
	
	return comboOptions
end

local function GetUserRankImageName(userName, userControl)
	local userInfo = userControl.lobby:GetUser(userName) or {}
	if userInfo.isBot or userInfo.aiLib then
		return IMAGE_AUTOHOST
	elseif userInfo.isAdmin then
		return IMAGE_MODERATOR
	elseif userInfo.level then
		local rankBracket = math.min(8, math.floor(userInfo.level/10)) + 1
		return "luaui/images/ranks/" .. rankBracket .. ".png"
	end
end

local function GetUserStatusImages(userName, isInBattle, userControl)
	local userInfo = userControl.lobby:GetUser(userName) or {}
	if userInfo.isInGame or (userInfo.battleID and not isInBattle) then
		if userInfo.isInGame then
			return IMAGE_INGAME, (userInfo.isAway and IMAGE_AFK)
		else
			return IMAGE_BATTLE, (userInfo.isAway and IMAGE_AFK)
		end
	elseif userInfo.isAway then
		return IMAGE_AFK
	end
end

local function UpdateUserActivity(listener, userName)
	for i = 1, #userListList do
		local userList = userListList[i]
		if userList[userName] then
			local status1, status2 = GetUserStatusImages(userName, userList[userName].isInBattle, userList[userName])
			userList[userName].mainControl.items = GetUserComboBoxOptions(userName, userList[userName].isInBattle, userList[userName])
			userList[userName].statusFirst.file = status1
			userList[userName].statusSecond.file = status2
			userList[userName].statusFirst:Invalidate()
			userList[userName].statusSecond:Invalidate()
		end
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Control Handling

local function GetUserControls(userName, isInBattle, lobbyToUse, reinitialize)
	local userControls = reinitialize or {}
	
	userControls.isInBattle = isInBattle
	userControls.lobby = lobbyToUse or lobby
	
	if reinitialize then
		userControls.mainControl:ClearChildren()
	else
		userControls.mainControl = ComboBox:New {
			name = userName,
			x = 0,
			y = 0,
			right = 0,
			height = 23,
			backgroundColor = {0, 0, 0, 0},
			borderColor = {0, 0, 0, 0},
			padding = {0, 0, 0, 0},
			caption = "",
			ignoreItemCaption = true,
			selectByName = true,
			itemFontSize = WG.Chobby.Configuration:GetFont(2).size,
			itemHeight = 30,
			selected = 0,
			maxDropDownWidth = 120,
			minDropDownHeight = 0,
			items = GetUserComboBoxOptions(userName, isInBattle, userControls),
			OnSelectName = {
			function (obj, selectedName)
					if selectedName == "Message" then
						WG.Chobby.interfaceRoot.GetChatWindow():GetPrivateChatConsole(userName)
					elseif selectedName == "Kick" then
						local userBattleInfo = userControls.lobby:GetUserBattleStatus(userName) or {}
						if userBattleInfo and userBattleInfo.aiLib then
							userControls.lobby:RemoveAi(userName)
						else
							Spring.Echo("TODO - Implement player kick.")
						end
					elseif selectedName == "Friend" then
						Spring.Echo("TODO - Be Friends.")
					elseif selectedName == "Join Battle" then
						local userInfo = userControls.lobby:GetUser(userName) or {}
						if userInfo.battleID then
							-- TODO: Passworded battles
							WG.BattleRoomWindow.LeaveBattle()
							userControls.lobby:JoinBattle(userInfo.battleID)
						end
					elseif selectedName == "Report" then
						Spring.Echo("TODO - Open the right webpage")
					end
				end
			},
			parent = screen0
		}
	end
	
	userControls.country = Image:New {
		name = "country",
		x = 1,
		y = 3,
		width = 21,
		height = 19,
		parent = userControls.mainControl,
		keepAspect = true,
		file = GetUserCountryImage(userName, userControls),
	}
	userControls.level = Image:New {
		name = "level",
		x = 26,
		y = 3,
		width = 19,
		height = 19,
		parent = userControls.mainControl,
		keepAspect = true,
		file = GetUserRankImageName(userName, userControls),
	}
	userControls.name = TextBox:New {
		name = "name",
		x = 50,
		y = 6,
		right = 0,
		bottom = 2,
		align = "left",
		parent = userControls.mainControl,
		fontsize = WG.Chobby.Configuration:GetFont(2).size,
		text = userName,
	}
	
	local status1, status2 = GetUserStatusImages(userName, isInBattle, userControls)
	
	userControls.statusFirst = Image:New {
		name = "statusFirst",
		x = 50 + userControls.name.font:GetTextWidth(userControls.name.text) + 3,
		y = 3,
		width = 19,
		height = 19,
		parent = userControls.mainControl,
		keepAspect = true,
		file = status1,
	}
	
	userControls.statusSecond = Image:New {
		name = "statusSecond",
		x = 50 + userControls.name.font:GetTextWidth(userControls.name.text) + 3 + 21,
		y = 3,
		width = 19,
		height = 19,
		parent = userControls.mainControl,
		keepAspect = true,
		file = status2,
	}
	
	-- This is always checked against main lobby.
	userControls.needReinitialization = lobby.status ~= "connected"
	
	return userControls
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- External Functions
local userHandler = {}

function userHandler.GetBattleUser(userName, lobbyToUse)
	if battleUsers[userName] then
		battleUsers[userName].lobby = lobbyToUse
		if battleUsers[userName].needReinitialization then
			battleUsers[userName] = GetUserControls(userName, true, lobbyToUse, battleUsers[userName])
		end
		return battleUsers[userName].mainControl
	end
	
	battleUsers[userName] = GetUserControls(userName, true, lobbyToUse)
	return battleUsers[userName].mainControl
end

function userHandler.GetChannelUser(userName)		
	if channelUsers[userName] then
		if channelUsers[userName].needReinitialization then
			channelUsers[userName] = GetUserControls(userName, false, false, channelUsers[userName])
		end
		return channelUsers[userName].mainControl
	end
	
	channelUsers[userName] = GetUserControls(userName)
	return channelUsers[userName].mainControl
end

function userHandler.GetTeamUser(userName)		
	if teamUsers[userName] then
		if teamUsers[userName].needReinitialization then
			teamUsers[userName] = GetUserControls(userName, false, false, teamUsers[userName])
		end
		return teamUsers[userName].mainControl
	end
	
	teamUsers[userName] = GetUserControls(userName)
	return teamUsers[userName].mainControl
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Connection

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Listeners

local function AddListeners()
	lobby:AddListener("OnUpdateUserStatus", UpdateUserActivity)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Widget Interface

function widget:Initialize()
	CHOBBY_DIR = "LuaUI/widgets/chobby/"
	VFS.Include("LuaUI/widgets/chobby/headers/exports.lua", nil, VFS.RAW_FIRST)
	
	AddListeners()
	
	WG.UserHandler = userHandler
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------