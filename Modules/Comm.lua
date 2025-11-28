-- Modules/Comm.lua
-- Handles addon communication for sharing builds with party members
--
-- ARCHITECTURE:
-- Uses "addressed broadcast" pattern - messages are sent to PARTY/RAID channel
-- but include a recipient GUID so only the intended player processes them.
--
-- Message Format: "HEADER,RECIPIENT_GUID,SENDER_GUID,BODY"
-- - HEADER: Message type (SYNC, REQ, RESP, DESYNC)
-- - RECIPIENT_GUID: Target player GUID ("*" = everyone)
-- - SENDER_GUID: Sending player GUID
-- - BODY: Build data

local RAT = _G.RAT
RAT.Comm = {}

local Comm = RAT.Comm

local COMM_PREFIX = "RATv1"

-- Message types
local MSG_TYPE = {
    SYNC = "SYNC",      -- Broadcast build update to everyone
    REQ = "REQ",        -- Request builds + send own build
    RESP = "RESP",      -- Targeted response to request
    DESYNC = "DESYNC",  -- Notify party of build reset/disconnect
}

local BROADCAST_RECIPIENT = "*"

function Comm:Initialize()
    RAT:RegisterComm(COMM_PREFIX, "OnCommReceived")

    RAT:DebugPrint("Comm: Initialized addon communication system (addressed broadcast)")
end

--------------------------------------------------------------------------------
-- Message Sending
--------------------------------------------------------------------------------

--- Send a message to party/raid channel
-- @param msgType string Message type (SYNC, REQ, RESP, DESYNC)
-- @param recipientGUID string Target player GUID or "*" for broadcast
-- @param buildData table|nil Build data payload (nil for DESYNC)
local function SendMessage(msgType, recipientGUID, buildData)
    local playerGUID = UnitGUID("player")
    if not playerGUID then
        RAT:DebugPrint("Comm: Cannot send message - no player GUID")
        return
    end

    local serializedBody = ""
    if buildData then
        serializedBody = RAT:Serialize(buildData)
    end

    -- Format: "HEADER,RECIPIENT,SENDER,BODY"
    local message = string.format("%s,%s,%s,%s", msgType, recipientGUID, playerGUID, serializedBody)

    local channel = IsInRaid() and "RAID" or "PARTY"

    if not IsInRaid() and not IsInGroup() then
        RAT:DebugPrint("Comm: Not in group, skipping " .. msgType .. " broadcast")
        return
    end

    RAT:SendCommMessage(COMM_PREFIX, message, channel)

    local targetStr = recipientGUID == BROADCAST_RECIPIENT and "BROADCAST" or recipientGUID:sub(1, 12)
    RAT:DebugPrint(string.format("Comm: Sent %s to %s via %s", msgType, targetStr, channel))
end

function Comm:BroadcastBuild()
    local guid = UnitGUID("player")
    if not guid then return end

    local talents = RAT.State.inspectedTalents and RAT.State.inspectedTalents[guid] or {}
    local trinkets = RAT.State.inspectedTrinkets and RAT.State.inspectedTrinkets[guid] or {}
    local mysticEnchants = RAT.State.inspectedMysticEnchants and RAT.State.inspectedMysticEnchants[guid] or {}

    local talentCount = 0
    for _ in pairs(talents) do talentCount = talentCount + 1 end

    if talentCount == 0 and #trinkets == 0 and #mysticEnchants == 0 then
        RAT:DebugPrint("Comm: No build data to broadcast")
        return
    end

    local buildData = {
        talents = talents,
        trinkets = trinkets,
        mysticEnchants = mysticEnchants,
        version = RAT.Version,
    }

    SendMessage(MSG_TYPE.SYNC, BROADCAST_RECIPIENT, buildData)
    RAT:DebugPrint(string.format("Comm: Broadcasted SYNC (talents=%d, trinkets=%d, mystics=%d)",
        talentCount, #trinkets, #mysticEnchants))
end

function Comm:RequestBuilds()
    if not IsInRaid() and not IsInGroup() then
        RAT:DebugPrint("Comm: Not in group, skipping REQ broadcast")
        return
    end

    local guid = UnitGUID("player")
    if not guid then return end

    local talents = RAT.State.inspectedTalents and RAT.State.inspectedTalents[guid] or {}
    local trinkets = RAT.State.inspectedTrinkets and RAT.State.inspectedTrinkets[guid] or {}
    local mysticEnchants = RAT.State.inspectedMysticEnchants and RAT.State.inspectedMysticEnchants[guid] or {}

    local buildData = {
        talents = talents,
        trinkets = trinkets,
        mysticEnchants = mysticEnchants,
        version = RAT.Version,
    }

    local numMembers = GetNumRaidMembers()
    if numMembers == 0 then
        numMembers = GetNumPartyMembers()
    end

    local delay = 0
    if numMembers > 10 then
        delay = math.random(0, 100) * 0.1
        RAT:DebugPrint(string.format("Comm: Staggering REQ broadcast by %.1fs (raid size: %d)", delay, numMembers))
    elseif numMembers > 5 then
        delay = math.random(0, 20) * 0.1
        RAT:DebugPrint(string.format("Comm: Staggering REQ broadcast by %.1fs (party size: %d)", delay, numMembers))
    end

    RAT:ScheduleTimer("comm_req_stagger", delay, function()
        SendMessage(MSG_TYPE.REQ, BROADCAST_RECIPIENT, buildData)

        local talentCount = 0
        for _ in pairs(talents) do talentCount = talentCount + 1 end
        RAT:DebugPrint(string.format("Comm: Sent REQ (talents=%d, trinkets=%d, mystics=%d)",
            talentCount, #trinkets, #mysticEnchants))
    end)
end

--- Send desync notification to party
function Comm:SendDesync()
    SendMessage(MSG_TYPE.DESYNC, BROADCAST_RECIPIENT, nil)
    RAT:DebugPrint("Comm: Sent DESYNC notification")
end

--------------------------------------------------------------------------------
-- Message Reception
--------------------------------------------------------------------------------

--- Handle incoming addon messages
-- @param prefix string Communication prefix
-- @param message string Raw message
-- @param distribution string Distribution type (PARTY, RAID, etc)
-- @param sender string Sender name
function RAT:OnCommReceived(prefix, message, distribution, sender)
    if prefix ~= COMM_PREFIX then return end

    -- Parse message: "HEADER,RECIPIENT,SENDER_GUID,BODY"
    local header, recipient, senderGUID, body = message:match("^([^,]+),([^,]+),([^,]+),(.*)$")

    if not header or not recipient or not senderGUID then
        self:DebugPrint("Comm: Malformed message from " .. sender)
        return
    end

    -- Check if message is for us
    local playerGUID = UnitGUID("player")
    if recipient ~= BROADCAST_RECIPIENT and recipient ~= playerGUID then
        return
    end

    -- Don't process our own messages
    if senderGUID == playerGUID then
        return
    end

    self:DebugPrint(string.format("Comm: Received %s from %s", header, sender))

    -- Route to appropriate handler
    if header == MSG_TYPE.SYNC then
        Comm:OnSyncReceived(senderGUID, body, sender)
    elseif header == MSG_TYPE.REQ then
        Comm:OnReqReceived(senderGUID, body, sender)
    elseif header == MSG_TYPE.RESP then
        Comm:OnRespReceived(senderGUID, body, sender)
    elseif header == MSG_TYPE.DESYNC then
        Comm:OnDesyncReceived(senderGUID, sender)
    else
        self:DebugPrint("Comm: Unknown message type: " .. header)
    end
end

--- Handle SYNC message (build update broadcast)
-- @param senderGUID string Sender's GUID
-- @param body string Serialized build data
-- @param sender string Sender name
function Comm:OnSyncReceived(senderGUID, body, sender)
    local buildData = self:DeserializeAndStore(senderGUID, body, sender)
    if buildData then
        -- Mark as synced
        RAT.State.syncedPartyMembers[senderGUID] = true
    end
end

--- Handle REQ message (build request + sender's build)
-- @param senderGUID string Sender's GUID
-- @param body string Serialized build data
-- @param sender string Sender name
function Comm:OnReqReceived(senderGUID, body, sender)
    local buildData = self:DeserializeAndStore(senderGUID, body, sender)
    if not buildData then return end

    RAT.State.syncedPartyMembers[senderGUID] = true

    -- Always respond to REQ messages with our build data
    -- REQ means the sender explicitly needs our data
    RAT:DebugPrint(string.format("Comm: Responding to REQ from %s", sender))

    local guid = UnitGUID("player")
    if guid then
        local talents = RAT.State.inspectedTalents and RAT.State.inspectedTalents[guid] or {}
        local trinkets = RAT.State.inspectedTrinkets and RAT.State.inspectedTrinkets[guid] or {}
        local mysticEnchants = RAT.State.inspectedMysticEnchants and RAT.State.inspectedMysticEnchants[guid] or {}

        local respData = {
            talents = talents,
            trinkets = trinkets,
            mysticEnchants = mysticEnchants,
            version = RAT.Version,
        }

        SendMessage(MSG_TYPE.RESP, senderGUID, respData)
    end
end

--- Handle RESP message (targeted response to request)
-- @param senderGUID string Sender's GUID
-- @param body string Serialized build data
-- @param sender string Sender name
function Comm:OnRespReceived(senderGUID, body, sender)
    local buildData = self:DeserializeAndStore(senderGUID, body, sender)
    if buildData then
        RAT.State.syncedPartyMembers[senderGUID] = true
    end
end

--- Handle DESYNC message (player leaving or resetting build)
-- @param senderGUID string Sender's GUID
-- @param sender string Sender name
function Comm:OnDesyncReceived(senderGUID, sender)
    RAT:DebugPrint(string.format("Comm: %s desynced, clearing build data", sender))

    RAT.State.syncedPartyMembers[senderGUID] = nil

    if RAT.State.inspectedTalents then
        RAT.State.inspectedTalents[senderGUID] = nil
    end
    if RAT.State.inspectedTrinkets then
        RAT.State.inspectedTrinkets[senderGUID] = nil
    end
    if RAT.State.inspectedMysticEnchants then
        RAT.State.inspectedMysticEnchants[senderGUID] = nil
    end

    if RAT.Icons then
        RAT.Icons:RefreshAllDisplays()
    end
end

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------

--- Deserialize build data and store in state
-- @param senderGUID string Sender's GUID
-- @param body string Serialized build data
-- @param sender string Sender name
-- @return table|nil Deserialized build data or nil on error
function Comm:DeserializeAndStore(senderGUID, body, sender)
    local success, buildData = RAT:Deserialize(body)
    if not success or type(buildData) ~= "table" then
        RAT:DebugPrint(string.format("Comm: Failed to deserialize from %s", sender))
        return nil
    end

    local talents = buildData.talents or {}
    local trinkets = buildData.trinkets or {}
    local mysticEnchants = buildData.mysticEnchants or {}

    local talentCount = 0
    for _ in pairs(talents) do talentCount = talentCount + 1 end

    RAT:DebugPrint(string.format("Comm: Storing build from %s (GUID: %s) - talents=%d, trinkets=%d, mystics=%d",
        sender, senderGUID:sub(1, 12), talentCount, #trinkets, #mysticEnchants))

    if not RAT.State.inspectedTalents then
        RAT.State.inspectedTalents = {}
    end
    RAT.State.inspectedTalents[senderGUID] = talents

    if not RAT.State.inspectedTrinkets then
        RAT.State.inspectedTrinkets = {}
    end
    RAT.State.inspectedTrinkets[senderGUID] = trinkets

    if not RAT.State.inspectedMysticEnchants then
        RAT.State.inspectedMysticEnchants = {}
    end
    RAT.State.inspectedMysticEnchants[senderGUID] = mysticEnchants

    if RAT.Spells and RAT.Units then
        local trackedUnits = RAT.Units:GetAllUnits()
        for unitGuid, unitData in pairs(trackedUnits) do
            if unitGuid == senderGUID then
                RAT.Spells:UpdateUnitSpells(senderGUID, unitData)
                break
            end
        end
    end

    if RAT.Icons then
        RAT.Icons:RefreshAllDisplays()
    end

    return buildData
end
