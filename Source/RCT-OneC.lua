--[[
	---------------------------------------------------------
    OneCapacity is a app counting cumulative battery usage.
    
    Model and transmitter can be turned off getween usage
    and OneCapacity telemetry window will always show total
    battery capacity used for all flights until reset switch
    is used or new battery is used.
    
    OneCapacity offers one Lua control to be used for alarms
    or anything else user wants.
    
    OneCapacity works in DC/DS-14/16/24 and requires 
    firmware 4.22 or up. 
    
    German translation by Norbert Kolb
	---------------------------------------------------------
	Localisation-file has to be as /Apps/Lang/RCT-OneC.jsn
	---------------------------------------------------------
	OneCapacity is part of RC-Thoughts Jeti Tools.
	---------------------------------------------------------
	Released under MIT-license by Tero @ RC-Thoughts.com 2017
	---------------------------------------------------------
--]]
collectgarbage()
--------------------------------------------------------------------------------
-- Locals for application
local timeSet, voltSet, capRun, capTot, capBatt = false, false, 0, 0, 0
local voltRun, voltTime, timeNow = 0, 0, 0
local swCap, swRun, capStore, voltStore
local sensorLalist = { "..." }
local sensorIdlist = { "..." }
local sensorPalist = { "..." }
--------------------------------------------------------------------------------
-- Read translations
local function setLanguage()
    local lng = system.getLocale()
    local file = io.readall("Apps/Lang/RCT-OneC.jsn")
    local obj = json.decode(file)
    if(obj) then
        trans13 = obj[lng] or obj[obj.default]
    end
    collectgarbage()
end
----------------------------------------------------------------------
-- Draw telemetry screen for main display
local function printDisplay()
	lcd.drawText(145 - lcd.getTextWidth(FONT_BIG, string.format("%.0f", capTot).. "mAh"), 0, string.format("%.0f", capTot).. "mAh", FONT_BIG)
end
--------------------------------------------------------------------------------
-- Read available sensors for user to select
local function readSensors()
    local sensors = system.getSensors()
    local format = string.format
    local insert = table.insert
    for i, sensor in ipairs(sensors) do
        if (sensor.label ~= "") then
            insert(sensorLalist, format("%s", sensor.label))
            insert(sensorIdlist, format("%s", sensor.id))
            insert(sensorPalist, format("%s", sensor.param))
        end
    end
end
--------------------------------------------------------------------------------
local function sensorChanged(value)
    local pSave = system.pSave
    local format = string.format
    capSe = value
    capSeId = format("%s", sensorIdlist[capSe])
    capSePa = format("%s", sensorPalist[capSe])
    if (capSeId == "...") then
        capSeId = 0
        capSePa = 0 
    end
    pSave("capSe", value)
    pSave("capSeId", capSeId)
    pSave("capSePa", capSePa)
end

local function sensorVoltChanged(value)
    local pSave = system.pSave
    local format = string.format
    voltSe = value
    voltSeId = format("%s", sensorIdlist[voltSe])
    voltSePa = format("%s", sensorPalist[voltSe])
    if (voltSeId == "...") then
        voltSeId = 0
        voltSePa = 0 
    end
    pSave("voltSe", value)
    pSave("voltSeId", voltSeId)
    pSave("voltSePa", voltSePa)
end

local function capBattChanged(value)
    local pSave = system.pSave
	capBatt = value
	pSave("capBatt",value)
end

local function swCapChanged(value)
    local pSave = system.pSave
	swCap = value
	pSave("swCap",value)
end
--------------------------------------------------------------------------------
-- Draw the main form (Application inteface)
local function initForm()
    local form, addRow, addLabel = form, form.addRow ,form.addLabel
    local addIntbox, addSelectbox = form.addIntbox, form.addSelectbox
    local addInputbox = form.addInputbox
    
	addRow(1)
	addLabel({label="---   RC-Thoughts Jeti Tools    ---", font=FONT_BIG})
    
    addRow(2)
    addLabel({label=trans13.capSensor, width=200})
    addSelectbox(sensorLalist, capSe, true, sensorChanged)
    
    addRow(2)
    addLabel({label=trans13.voltSensor, width=220})
    addSelectbox(sensorLalist, voltSe, true, sensorVoltChanged)
	
	addRow(2)
	addLabel({label=trans13.swCap, width=220})
	form.addInputbox(swCap, true, swCapChanged)
    
    addRow(2)
    addLabel({label=trans13.capBatt, width=220})
    addIntbox(capBatt, -0, 10000, 0, 0, 5, capBattChanged)
	
	addRow(1)
	addLabel({label="Powered by RC-Thoughts.com - v."..onecVersion.." ", font=FONT_MINI, alignRight=true})
    collectgarbage()
end
--------------------------------------------------------------------------------
local function loop()
    local swRun = system.getInputsVal(swCap)
    local sensorMah = system.getSensorByID(capSeId, capSePa)
    local sensorVolt = system.getSensorByID(voltSeId, voltSePa)
    if(sensorMah and sensorMah.valid and swRun and swRun < 1) then
        if(sensorMah.unit == "Ah") then
            capRun = sensor.value * 1000
        else
            capRun = sensor.value
        end
        capTot = (capStore + capRun)
        else
        if(capTot > 0 or capStore == 0) then
            capStore = capTot
            system.pSave("capStore", capStore)
        end
        capTot = capStore
    end
    
    if(swRun and swRun == 1) then
        capTot = 0
        capStore = 0
        system.pSave("capStore", capStore)
    end
    
    if(sensorVolt and sensorVolt.valid and sensorVolt.value > 5) then
        voltRun = sensorVolt.value
        timeNow = system.getTimeCounter()
        if(not timeSet) then
            voltTime = timeNow + 3000
            timeSet = true
            else
            if(voltSet and timeNow > voltTime and voltRun > (voltStore * 0.98)) then
                voltStore = voltRun
                system.pSave("voltStore", voltStore)
            end
        end
        if(not voltSet and voltTime > timeNow) then
            if(voltRun > (voltStore * 1.02)) then
                capTot = 0
                capStore = 0
                system.pSave("capStore", capStore)
            end
            voltSet = true
        end
        else
        timeSet = false
        voltSet = false
    end
    
    if(capTot >= capBatt and capBatt > 0) then
        system.setControl(1, 1, 0, 0)
        else
        system.setControl(1, 0, 0, 0)
    end
    collectgarbage()
end
--------------------------------------------------------------------------------
local function init()
    readSensors()
    local pLoad, registerForm = system.pLoad, system.registerForm
    local registerTelemetry, registerControl = system.registerTelemetry, system.registerControl
    registerForm(1, MENU_APPS, trans13.appName, initForm, nil, printForm)
    registerTelemetry(1, trans13.capDsp, 1, printDisplay)
    registerControl(1, trans13.capDsp, trans13.capAlm)
    swCap = pLoad("swCap")
    capSe = pLoad("capSe", 0)
    capSeId = pLoad("capSeId", 0)
    capSePa = pLoad("capSePa", 0)
    capStore = pLoad("capStore", 0)
    capBatt = pLoad("capBatt", 0)
    voltSe = pLoad("voltSe", 0)
    voltSeId = pLoad("voltSeId", 0)
    voltSePa = pLoad("voltSePa", 0)
    voltStore = pLoad("voltStore", 0)
    collectgarbage()
end
--------------------------------------------------------------------------------
onecVersion = "1.3"
setLanguage()
collectgarbage()
return {init=init, loop=loop, author="RC-Thoughts", version=onecVersion, name="OneCapacity"}
