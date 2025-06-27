-- FastMail (The War Within Retail)
-- TOC:
-- ## SavedVariables: FastMailCounter

if not LibStub then error("FastMail requires LibStub") end
local L    = LibStub("AceLocale-3.0"):GetLocale("FastMail", false)
local ldb  = LibStub:GetLibrary("LibDataBroker-1.1")

-- Frame & DataObject
local f = CreateFrame("Frame")
local dataobj = ldb:GetDataObjectByName("FastMail") or ldb:NewDataObject("FastMail", {
    type = "data source",
    text = "FastMail",
    icon = "Interface\\Minimap\\Tracking\\Mailbox",
})

-- Icons
local icons = {
    noMail  = "Interface\\Minimap\\Tracking\\Mailbox",
    newMail = "Interface\\Minimap\\Tracking\\MailNew",
}

-- Farben
local colors = {
    mailExpected = "|cFF00FF00",
    mailNone     = "|cFF808080",
}

-- Mail-Stats
local mailExpected, mailKnown, mailUnread, mailRead = false, 0, 0, 0
local mailSenders, mailExpectedFromLastThree = {}, 0

-- SavedVariables initialisieren
FastMailCounter = FastMailCounter or { mailUnread = 0, mailRead = 0, mailKnown = 0 }

-- Wrapper für Inbox-APIs (Fällt zurück auf alte Globals, wenn C_Mail noch nicht da)
local function GetInboxCounts()
    if C_Mail and C_Mail.GetInboxNumItems then
        return C_Mail.GetInboxNumItems()          -- totalCount, canDeliver
    else
        return GetInboxNumItems()                  -- totalCount, totalItems
    end
end

local function GetInboxInfo(i)
    if C_Mail and C_Mail.GetInboxHeaderInfo then
        return C_Mail.GetInboxHeaderInfo(i)       -- gibt Tabelle mit .sender, .isRead etc.
    else
        -- Globale API gibt mehrere Rückgabewerte; wir brauchen nur Sender & wasRead
        local sender, _, _, _, _, _, _, _, wasRead = GetInboxHeaderInfo(i)
        return { sender = sender, isRead = wasRead }
    end
end

-- Persistenz
local function saveVars()
    FastMailCounter.mailUnread = mailUnread
    FastMailCounter.mailRead   = mailRead
    FastMailCounter.mailKnown  = mailKnown
end

-- Tooltip & Broker-Text updaten
local function updateTooltipAndIcon()
    if mailExpected then
        dataobj.text = colors.mailExpected .. L["NEW"] .. "|r"
        dataobj.icon = icons.newMail
    elseif mailUnread > 0 then
        dataobj.text = colors.mailNone .. L["OLD"] .. "|r"
        dataobj.icon = icons.noMail
    else
        dataobj.text = colors.mailNone .. L["NONE"] .. "|r"
        dataobj.icon = icons.noMail
    end
end

-- Haupt-Funktion zum Einlesen der Mail-Daten
local function UpdateMailData()
    local total, _ = GetInboxCounts()
    mailKnown = total or 0
    mailRead, mailUnread = 0, 0

    for i = 1, mailKnown do
        local info = GetInboxInfo(i)
        if info.isRead then mailRead = mailRead + 1
        else mailUnread = mailUnread + 1 end
    end

    mailExpected = HasNewMail() and true or false
    if mailExpected then
        mailSenders = { GetLatestThreeSenders() }
        mailExpectedFromLastThree = #mailSenders
    else
        mailSenders = {}
        mailExpectedFromLastThree = 0
    end

    saveVars()
    updateTooltipAndIcon()
end

-- Tooltip-Handler
function dataobj.OnTooltipShow(tt)
    if not tt or not tt.AddLine then return end

    if mailExpected and mailExpectedFromLastThree > 0 then
        tt:AddLine(colors.mailNone .. string.format(L["ATLEAST"], mailExpectedFromLastThree) .. "|r")
        for i = 1, mailExpectedFromLastThree do
            local sender = mailSenders[i] or UNKNOWN
            tt:AddDoubleLine(colors.mailExpected .. sender .. "|r", "")
        end
        tt:AddLine(" ")
    end

    tt:AddDoubleLine(colors.mailNone .. L["KNOWN"] .. "|r", mailKnown)
    tt:AddDoubleLine(colors.mailNone .. L["UNREAD"] .. "|r", mailUnread)
    tt:AddDoubleLine(colors.mailNone .. L["READ"] .. "|r", mailRead)
end

-- Events
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("UPDATE_PENDING_MAIL")
f:RegisterEvent("MAIL_INBOX_UPDATE")

f:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "FastMail" then
        -- Vorsichtig initialisieren
        mailUnread = FastMailCounter.mailUnread or 0
        mailRead   = FastMailCounter.mailRead   or 0
        mailKnown  = FastMailCounter.mailKnown  or 0
    elseif event == "PLAYER_LOGIN"
        or event == "UPDATE_PENDING_MAIL"
        or event == "MAIL_INBOX_UPDATE" then
        UpdateMailData()
    end
end)
