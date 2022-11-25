if not LibStub then error("FastMail requires LibStub") end
local L = LibStub("AceLocale-3.0"):GetLocale("FastMail", false)

local pName = "FastMail"
local f = CreateFrame("frame")
local ldb = LibStub:GetLibrary("LibDataBroker-1.1")
local files = {
	iconNoMail = "Interface\\Minimap\\Tracking\\Mailbox",
	iconNewMail = "Interface\\Minimap\\Tracking\\Mailbox",
}
local colors = {
	["mail_expected"] = "|cff00ff00",
	["mail_none"] = "|ccccccccc",
}

local dataobj = ldb:GetDataObjectByName(pName) or ldb:NewDataObject(pName, {
	type = "data source",
	text = "FastMail",
	icon = files["iconNoMail"]
})

local previousEvent = "none"

local mailExpected = false
local mailSenders = {}
local mailNew = 0
local mailUnread = 0
local mailRead = 0
local mailKnown = 0
local mailExpectedFromLastThree = 0;

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("UPDATE_PENDING_MAIL")
f:RegisterEvent("MAIL_INBOX_UPDATE")
f:RegisterEvent("MAIL_SHOW")
f:RegisterEvent("MAIL_CLOSED")

local function saveVars()
	_G["FastMailCounter"] = {
		["mailUnread"] = mailUnread,
		["mailRead"] = mailRead,
		["mailKnown"] = mailKnown,
	}
end

local function updateTooltip()
	if mailExpected then
		dataobj.text = colors["mail_expected"]..L["NEW"]..FONT_COLOR_CODE_CLOSE
		dataobj.icon = files["iconNewMail"]
	elseif mailUnread > 0 then
		dataobj.text = colors["mail_none"]..L["OLD"]..FONT_COLOR_CODE_CLOSE
		dataobj.icon = files["iconNoMail"]
	else
		dataobj.text = colors["mail_none"]..L["NONE"]..FONT_COLOR_CODE_CLOSE
		dataobj.icon = files["iconNoMail"]
	end
end

local function matchSystemMessage(arg1, arg2)
	arg2 = strsplit("%%s", arg2)
	return strfind(arg1, arg2)
end

local function getMailCountFromBlizz()
	local senders = {GetLatestThreeSenders()}
	if not senders[1] then
		return 0
	end
	return table.getn(senders)
end

local function getMailSendersFromBlizz()
	local senders = {GetLatestThreeSenders()}
	if not senders[1] then
		return nil
	end
	return senders
end

local function FastMailInitialize()
	if HasNewMail() then
		mailExpected = true
		mailSenders = getMailSendersFromBlizz()
		mailExpectedFromLastThree = getMailCountFromBlizz()
	end
	if _G["FastMailCounter"] ~= nil then
		mailUnread = _G["FastMailCounter"]["mailUnread"]
		mailRead = _G["FastMailCounter"]["mailRead"]
		mailKnown = _G["FastMailCounter"]["mailKnown"]
	end
	updateTooltip()
end

local function FastMailEvent(event, arg1)
	if event == "MAIL_SHOW" then
	elseif event == "MAIL_INBOX_UPDATE" then
		accurateMailNumbers = true
		_,totalMailCount = GetInboxNumItems()
		mailNew = totalMailCount - mailKnown
		mailExpected = false
		mailSenders = getMailSendersFromBlizz()
		mailExpectedFromLastThree = getMailCountFromBlizz() > totalMailCount and getMailCountFromBlizz() or totalMailCount
	  mailKnown = totalMailCount
		mailUnread = 0
		mailRead = 0
		for i = 1, mailKnown do
			local _, _, _, _, _, _, _, _, wasRead, _, _, _, _ = GetInboxHeaderInfo(i)
			if wasRead then
				mailRead = mailRead + 1
			else
				mailUnread = mailUnread + 1
			end
		end
	elseif event == "UPDATE_PENDING_MAIL" then
		if HasNewMail() then
			mailExpected = true
			mailSenders = getMailSendersFromBlizz()
			mailExpectedFromLastThree = getMailCountFromBlizz()
		end
	end
	saveVars()
	previousEvent = event
end

function dataobj.OnTooltipShow(tip)
	if not tip or not tip.AddLine or not tip.AddDoubleLine then
		return
	end
	if HasNewMail() then
		local tmpmailcount = getMailCountFromBlizz()
		if tmpmailcount > 0 then
			tip:AddDoubleLine(colors["mail_none"]..string.format(L["ATLEAST"], mailExpectedFromLastThree)..FONT_COLOR_CODE_CLOSE)
			for i=1,tmpmailcount do
				tip:AddDoubleLine(colors["mail_expected"]..mailSenders[i]..FONT_COLOR_CODE_CLOSE)
			end
			tip:AddDoubleLine(" ")
		end
	end
	tip:AddDoubleLine(colors["mail_none"]..L["KNOWN"]..FONT_COLOR_CODE_CLOSE, mailKnown)
	tip:AddDoubleLine(colors["mail_none"]..L["UNREAD"]..FONT_COLOR_CODE_CLOSE, mailUnread)
	tip:AddDoubleLine(colors["mail_none"]..L["READ"]..FONT_COLOR_CODE_CLOSE, mailRead)

end

f:SetScript("OnEvent", function(self, event, arg1, ...)
	if event == "ADDON_LOADED" and arg1 == pName then
		previousEvent = "ADDON_LOADED"
		FastMailInitialize()
	else
		FastMailEvent(event, arg1)
	end
	updateTooltip()
end)
