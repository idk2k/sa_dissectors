

-- Доступные типы: "u8", "u16", "i16", "u32", "i32", "hex32", "float", "bool",
--                 "str8", "str16", "str32", "quat", "vec3", "hp_ap_8", "hp_ap_16"

local M = {}
M.packet_names = {
    [6]   = "ID_INTERNAL_PING",
    [7]   = "ID_PING",
    [8]   = "ID_PING_OPEN_CONNECTIONS",
    [9]   = "ID_CONNECTED_PONG",
    [10]  = "ID_REQUEST_STATIC_DATA",
    [11]  = "ID_CONNECTION_REQUEST",
    [12]  = "ID_AUTH_KEY",
    [17]  = "ID_RPC_MAPPING",
    [20]  = "ID_RPC",
    [23]  = "ID_DETECT_LOST_CONNECTIONS",
    [24]  = "ID_OPEN_CONNECTION_REQUEST",
    [25]  = "ID_OPEN_CONNECTION_REPLY",
    [26]  = "ID_OPEN_CONNECTION_COOKIE",
    [29]  = "ID_CONNECTION_ATTEMPT_FAILED",
    [30]  = "ID_NEW_INCOMING_CONNECTION",
    [31]  = "ID_NO_FREE_INCOMING_CONNECTIONS",
    [32]  = "ID_DISCONNECTION_NOTIFICATION",
    [33]  = "ID_CONNECTION_LOST",
    [34]  = "ID_CONNECTION_REQUEST_ACCEPTED",
    [35]  = "ID_CONNECTION_FAILED",
    [36]  = "ID_CONNECTION_BANNED",
    [37]  = "ID_INVALID_PASSWORD",
    [38]  = "ID_MODIFIED_PACKET",
    [40]  = "ID_TIMESTAMP",
    [41]  = "ID_RECEIVED_STATIC_DATA",
    [42]  = "ID_REMOTE_DISCONNECTION_NOTIFICATION",
    [43]  = "ID_REMOTE_CONNECTION_LOST",
    [44]  = "ID_REMOTE_NEW_INCOMING_CONNECTION",
    [45]  = "ID_REMOTE_EXISTING_CONNECTION",
    [46]  = "ID_REMOTE_STATIC_DATA",
    [200] = "ID_VEHICLE_SYNC (InCar)",
    [201] = "ID_RCON_COMMAND",
    [202] = "ID_RCON_RESPONCE",
    [203] = "ID_AIM_SYNC",
    [204] = "ID_WEAPONS_UPDATE",
    [205] = "ID_STATS_UPDATE",
    [206] = "ID_BULLET_SYNC",
    [207] = "ID_PLAYER_SYNC (OnFoot)",
    [208] = "ID_MARKERS_SYNC",
    [209] = "ID_UNOCCUPIED_SYNC",
    [210] = "ID_TRAILER_SYNC",
    [211] = "ID_PASSENGER_SYNC",
    [212] = "ID_SPECTATOR_SYNC"
}


M.rpc_names = {}
M.rpc_names[11] = "SetPlayerName"
M.rpc_names[12] = "SetPlayerPos"
M.rpc_names[13] = "SetPlayerPosFindZ"
M.rpc_names[14] = "SetPlayerHealth"
M.rpc_names[15] = "TogglePlayerControllable"
M.rpc_names[16] = "PlaySound"
M.rpc_names[17] = "SetPlayerWorldBounds"
M.rpc_names[18] = "GivePlayerMoney"
M.rpc_names[19] = "SetPlayerFacingAngle"
M.rpc_names[20] = "ResetPlayerMoney"
M.rpc_names[21] = "ResetPlayerWeapons"
M.rpc_names[22] = "GivePlayerWeapon"
M.rpc_names[24] = "SetVehicleParamsEx"
M.rpc_names[25] = "CancelEdit"
M.rpc_names[29] = "SetPlayerTime"
M.rpc_names[30] = "ToggleClock"
M.rpc_names[32] = "WorldPlayerAdd"
M.rpc_names[33] = "SetPlayerShopName"
M.rpc_names[34] = "SetPlayerSkillLevel"
M.rpc_names[35] = "SetPlayerDrunkLevel"
M.rpc_names[36] = "Create3DTextLabel"
M.rpc_names[37] = "DisableCheckpoint"
M.rpc_names[38] = "SetRaceCheckpoint"
M.rpc_names[39] = "DisableRaceCheckpoint"
M.rpc_names[40] = "GameModeRestart"
M.rpc_names[41] = "PlayAudioStreamForPlayer"
M.rpc_names[42] = "StopAudioStreamForPlayer"
M.rpc_names[43] = "RemoveBuildingForPlayer"
M.rpc_names[44] = "CreateObject"
M.rpc_names[45] = "SetObjectPos"
M.rpc_names[46] = "SetObjectRot"
M.rpc_names[47] = "DestroyObject"
M.rpc_names[55] = "DeathMessage"
M.rpc_names[56] = "SetPlayerMapIcon"
M.rpc_names[57] = "RemoveVehicleComponent"
M.rpc_names[58] = "Update3DTextLabel"
M.rpc_names[59] = "ChatBubble"
M.rpc_names[60] = "UpdateSystemTime"
M.rpc_names[61] = "ShowDialog"
M.rpc_names[63] = "DestroyPickup"
M.rpc_names[65] = "LinkVehicleToInterior"
M.rpc_names[66] = "SetPlayerArmour"
M.rpc_names[67] = "SetPlayerArmedWeapon"
M.rpc_names[68] = "SetSpawnInfo"
M.rpc_names[69] = "SetPlayerTeam"
M.rpc_names[70] = "PutPlayerInVehicle"
M.rpc_names[71] = "RemovePlayerFromVehicle"
M.rpc_names[72] = "SetPlayerColor"
M.rpc_names[73] = "DisplayGameText"
M.rpc_names[74] = "ForceClassSelection"
M.rpc_names[75] = "AttachObjectToPlayer"
M.rpc_names[76] = "InitMenu"
M.rpc_names[77] = "ShowMenu"
M.rpc_names[78] = "HideMenu"
M.rpc_names[79] = "CreateExplosion"
M.rpc_names[80] = "ShowPlayerNameTagForPlayer"
M.rpc_names[81] = "AttachCameraToObject"
M.rpc_names[82] = "InterpolateCamera"
M.rpc_names[84] = "SetObjectMaterial"
M.rpc_names[85] = "GangZoneStopFlash"
M.rpc_names[86] = "ApplyAnimation"
M.rpc_names[87] = "ClearAnimations"
M.rpc_names[88] = "SetPlayerSpecialAction"
M.rpc_names[89] = "SetPlayerFightingStyle"
M.rpc_names[90] = "SetPlayerVelocity"
M.rpc_names[91] = "SetVehicleVelocity"
M.rpc_names[93] = "ClientMessage"
M.rpc_names[94] = "SetWorldTime"
M.rpc_names[95] = "CreatePickup"
M.rpc_names[99] = "MoveObject"
M.rpc_names[104] = "EnableStuntBonusForAll"
M.rpc_names[105] = "TextDrawSetString"
M.rpc_names[107] = "SetCheckpoint"
M.rpc_names[108] = "GangZoneCreate"
M.rpc_names[112] = "PlayCrimeReport"
M.rpc_names[113] = "SetPlayerAttachedObject"
M.rpc_names[120] = "GangZoneDestroy"
M.rpc_names[121] = "GangZoneFlash"
M.rpc_names[122] = "StopObject"
M.rpc_names[123] = "SetNumberPlate"
M.rpc_names[124] = "TogglePlayerSpectating"
M.rpc_names[126] = "PlayerSpectatePlayer"
M.rpc_names[127] = "PlayerSpectateVehicle"
M.rpc_names[133] = "SetPlayerWantedLevel"
M.rpc_names[134] = "ShowTextDraw"
M.rpc_names[135] = "TextDrawHideForPlayer"
M.rpc_names[137] = "ServerJoin"
M.rpc_names[138] = "ServerQuit"
M.rpc_names[139] = "InitGame"
M.rpc_names[144] = "RemovePlayerMapIcon"
M.rpc_names[145] = "SetPlayerAmmo"
M.rpc_names[146] = "SetPlayerGravity"
M.rpc_names[147] = "SetVehicleHealth"
M.rpc_names[148] = "AttachTrailerToVehicle"
M.rpc_names[149] = "DetachTrailerFromVehicle"
M.rpc_names[152] = "SetWeather"
M.rpc_names[153] = "SetPlayerSkin"
M.rpc_names[154] = "SetPlayerInterior"
M.rpc_names[156] = "SetPlayerCameraPos"
M.rpc_names[157] = "SetPlayerCameraLookAt"
M.rpc_names[159] = "SetVehiclePos"
M.rpc_names[160] = "SetVehicleZAngle"
M.rpc_names[161] = "SetVehicleParamsForPlayer"
M.rpc_names[162] = "SetCameraBehindPlayer"
M.rpc_names[163] = "WorldPlayerRemove"
M.rpc_names[164] = "WorldVehicleAdd"
M.rpc_names[165] = "WorldVehicleRemove"
M.rpc_names[166] = "WorldPlayerDeath"
M.rpc_names[173] = "ApplyActorAnimation"
M.rpc_names[52] = "Spawn"
M.rpc_names[129] = "RequestSpawn"

M.reliability_names = {}
M.reliability_names[6] = "UNRELIABLE"
M.reliability_names[7] = "UNRELIABLE_SEQUENCED"
M.reliability_names[8] = "RELIABLE"
M.reliability_names[9] = "RELIABLE_ORDERED"
M.reliability_names[10] = "RELIABLE_SEQUENCED"

M.rpc_schemas = {
    
    -- #68: SetSpawnInfo (установка параметров спавна игрока)
    [68] = {
        { "Team",          "u8" },
        { "Skin ID",       "i32" },
        { "Unknown Byte",  "u8" },
        { "Pos X",         "float" },
        { "Pos Y",         "float" },
        { "Pos Z",         "float" },
        { "Rotation",      "float" },
        { "Weapon 1",      "i32" },
        { "Weapon 2",      "i32" },
        { "Weapon 3",      "i32" },
        { "Ammo 1",        "i32" },
        { "Ammo 2",        "i32" },
        { "Ammo 3",        "i32" }
    },
    -- #60: UpdateSystemTime (синхронизация системного времени сервера)
    [60] = {
        { "System Time (ms)", "u32" }
    },

    -- #94: SetWorldTime (установка игрового часа 0..23)
    [94] = {
        { "Hour", "u8" }
    },
    -- #134: ShowTextDraw (создание и показ текстдрава на экране)
    [134] = {
        { "TextDraw ID",     "u16" },
        { "Flags",           "u8" },
        { "Letter Width",    "float" },
        { "Letter Height",   "float" },
        { "Letter Color",    "hex32" },
        { "Line Width",      "float" },
        { "Line Height",     "float" },
        { "Box Color",       "hex32" },
        { "Shadow",          "u8" },
        { "Outline",         "u8" },
        { "Background Color","hex32" },
        { "Style",           "u8" },
        { "Selectable",      "u8" },
        { "Pos X",           "float" },
        { "Pos Y",           "float" },
        { "Model ID",        "u16" },
        { "Rot X",           "float" },
        { "Rot Y",           "float" },
        { "Rot Z",           "float" },
        { "Zoom",            "float" },
        { "Color 1",         "u16" },
        { "Color 2",         "u16" },
        { "Text",            "str16" }
    },
    -- #25: ClientJoin (отправка ника, GPCI и версии клиента при входе)
    [25] = {
        { "Version",            "u32" },
        { "Mod",                "u8" },
        { "Nickname",           "str8" },
        { "Challenge Response", "hex32" },
        { "GPCI",               "str8" },
        { "Client Version",     "str8" }
    },
    -- #44: CreateObject (создание объекта в зоне стрима)
    [44] = {
        { "Object ID",     "u16" },
        { "Model ID",      "u32" },
        { "Pos X",         "float" },
        { "Pos Y",         "float" },
        { "Pos Z",         "float" },
        { "Rot X",         "float" },
        { "Rot Y",         "float" },
        { "Rot Z",         "float" },
        { "Draw Distance", "float" },
        { "No Camera Col", "u8" }
    },
    -- #137: ServerJoin (подключение игрока на сервер)
    [137] = {
        { "Player ID", "u16" },
        { "Color",     "hex32" },
        { "Is NPC",    "u8" },
        { "Nickname",  "str8" }
    },

    -- #12: SetPlayerPos
    [12] = {
        { "Pos X", "float" },
        { "Pos Y", "float" },
        { "Pos Z", "float" }
    },
    -- #14: SetPlayerHealth
    [14] = {
        { "Health", "float" }
    },
    -- #15: TogglePlayerControllable
    [15] = {
        { "Controllable", "u8" }
    },
    -- #18: GivePlayerMoney
    [18] = {
        { "Money", "i32" }
    },
    -- #19: SetPlayerFacingAngle
    [19] = {
        { "Angle", "float" }
    },
    -- #22: GivePlayerWeapon
    [22] = {
        { "Weapon ID", "u32" },
        { "Ammo",      "u32" }
    },
    -- #32: WorldPlayerAdd (входящий стрим игрока)
    [32] = {
        { "Player ID", "u16" },
        { "Team",      "u8" },
        { "Skin ID",   "u32" },
        { "Pos X",     "float" },
        { "Pos Y",     "float" },
        { "Pos Z",     "float" },
        { "Angle",     "float" },
        { "Color",     "hex32" },
        { "FightStyle","u8" }
    },
    -- #43: RemoveBuildingForPlayer (видели на скриншоте!)
    [43] = {
        { "Model ID", "u32" },
        { "Pos X",    "float" },
        { "Pos Y",    "float" },
        { "Pos Z",    "float" },
        { "Radius",   "float" }
    },
    -- #47: DestroyObject (видели на скриншоте!)
    [47] = {
        { "Object ID", "u16" }
    },
    -- #50: ServerCommand (исходящая команда /...)
    [50] = {
        { "Command", "str32" }
    },
    -- #56: SetPlayerMapIcon (видели на скриншоте!)
    [56] = {
        { "Icon ID",  "u8" },
        { "Pos X",    "float" },
        { "Pos Y",    "float" },
        { "Pos Z",    "float" },
        { "Type",     "u8" },
        { "Color",    "hex32" },
        { "Style",    "u8" }
    },
    -- #59: ChatBubble (текст над головой игрока)
    [59] = {
        { "Player ID", "u16" },
        { "Color",     "hex32" },
        { "Distance",  "float" },
        { "Duration",  "u32" },
        { "Message",   "str8" }
    },
    -- #61: ShowDialog (заголовок и кнопки открытые, а основной текст диалога сжат Хаффманом!)
    [61] = {
        { "Dialog ID", "u16" },
        { "Style",     "u8" },
        { "Title",     "str8" },
        { "Button 1",  "str8" },
        { "Button 2",  "str8" },
        { "Body Text", "huff" }
    },
    -- #62: DialogResponse (исходящий ответ на диалог)
    [62] = {
        { "Dialog ID", "u16" },
        { "Button",    "u8" },
        { "List Item", "i16" },
        { "Input Text","str8" }
    },
    -- #66: SetPlayerArmour
    [66] = {
        { "Armour", "float" }
    },
    -- #70: PutPlayerInVehicle
    [70] = {
        { "Vehicle ID", "u16" },
        { "Seat ID",    "u8" }
    },
    -- #72: SetPlayerColor
    [72] = {
        { "Player ID", "u16" },
        { "Color",     "hex32" }
    },
    -- #73: DisplayGameText
    [73] = {
        { "Style", "u32" },
        { "Time",  "u32" },
        { "Text",  "str32" }
    },
    -- #86: ApplyAnimation
    [86] = {
        { "Player ID", "u16" },
        { "Anim Lib",  "str8" },
        { "Anim Name", "str8" },
        { "Delta",     "float" },
        { "Loop",      "u8" },
        { "Lock X",    "u8" },
        { "Lock Y",    "u8" },
        { "Freeze",    "u8" },
        { "Time",      "u32" }
    },
    -- #93: ClientMessage
    [93] = {
        { "Color",   "hex32" },
        { "Message", "str32" }
    },
    -- #95: CreatePickup (видели на скриншоте!)
    [95] = {
        { "Pickup ID", "i32" },
        { "Model ID",  "i32" },
        { "Type",      "i32" },
        { "Pos X",     "float" },
        { "Pos Y",     "float" },
        { "Pos Z",     "float" }
    },
    -- #101: Chat (исходящее сообщение в чат)
    [101] = {
        { "Text", "str8" }
    },
    -- #108: GangZoneCreate (видели на скриншоте!)
    [108] = {
        { "Zone ID", "u16" },
        { "Min X",   "float" },
        { "Min Y",   "float" },
        { "Max X",   "float" },
        { "Max Y",   "float" },
        { "Color",   "hex32" }
    },
    -- #113: SetPlayerAttachedObject (видели на скриншоте!)
    [113] = {
        { "Player ID", "u16" },
        { "Index",     "u32" },
        { "Create",    "u8" },
        { "Model ID",  "u32" },
        { "Bone",      "u32" },
        { "Offset X",  "float" },
        { "Offset Y",  "float" },
        { "Offset Z",  "float" },
        { "Rot X",     "float" },
        { "Rot Y",     "float" },
        { "Rot Z",     "float" },
        { "Scale X",   "float" },
        { "Scale Y",   "float" },
        { "Scale Z",   "float" }
    },
    -- #153: SetPlayerSkin
    [153] = {
        { "Player ID", "u32" },
        { "Skin ID",   "u32" }
    },
    -- #156: SetPlayerCameraPos (видели на скриншоте!)
    [156] = {
        { "Pos X", "float" },
        { "Pos Y", "float" },
        { "Pos Z", "float" }
    },
    -- #157: SetPlayerCameraLookAt
    [157] = {
        { "Look X", "float" },
        { "Look Y", "float" },
        { "Look Z", "float" },
        { "Cut",    "u8" }
    },
    -- #163: WorldPlayerRemove
    [163] = {
        { "Player ID", "u16" }
    },
    -- #164: WorldVehicleAdd (видели на скриншоте!)
    [164] = {
        { "Vehicle ID", "u16" },
        { "Model ID",   "u32" },
        { "Pos X",      "float" },
        { "Pos Y",      "float" },
        { "Pos Z",      "float" },
        { "Angle",      "float" },
        { "Color 1",    "u8" },
        { "Color 2",    "u8" },
        { "Health",     "float" },
        { "Interior",   "u8" },
        { "Doors",      "u32" },
        { "Panels",     "u32" },
        { "Lights",     "u8" },
        { "Tires",      "u8" },
        { "Siren",      "u8" }
    },
    -- #165: WorldVehicleRemove
    [165] = {
        { "Vehicle ID", "u16" }
    }
}

M.rpc_names_out = {
    [62] = "DialogResponse",
    [25]  = "ClientJoin",
    [50]  = "ServerCommand",
    [52]  = "Spawn",
    [53]  = "Death",
    [101] = "Chat",
    [115] = "ClickTextDraw",
    [128] = "RequestClass",
    [129] = "RequestSpawn",
    [136] = "VehicleDestroyed",
    [154] = "GiveTakeDamage"
}

M.packet_schemas_in = {
    [6] = {
        { "Send Ping Time", "u32" }
    },
    [9] = {
        { "Send Ping Time", "u32" },
        { "Send Pong Time", "u32" }
    },
    [17] = {
        { "RPC Index", "u8" }
    },
    [30] = {
        { "Binary Address", "hex32" },
        { "Port",           "u16" }
    },
    [12] = {
        { "Auth Challenge", "str8" }
    },
    [34] = {
        { "Client IP (Hex)", "hex32" },
        { "Client Port",     "u16" },
        { "Your Player ID",  "u16" },
        { "Challenge Key",   "hex32" }
    },
    -- ID 203: Входящий ID_AIM_SYNC (2 байта Player ID + 31 байт AimData)
    [203] = {
        { "Player ID",       "u16" },
        { "Cam Mode",        "u8" },
        { "Cam Front X",     "float" },
        { "Cam Front Y",     "float" },
        { "Cam Front Z",     "float" },
        { "Cam Pos X",       "float" },
        { "Cam Pos Y",       "float" },
        { "Cam Pos Z",       "float" },
        { "Aim Z",           "float" },
        { "Zoom / WepState", "aim_zoom" },
        { "Aspect Ratio",    "u8" }
    }
}

M.packet_schemas_out = {
    [6] = {
        { "Send Ping Time", "u32" }
    },
    [9] = {
        { "Send Ping Time", "u32" },
        { "Send Pong Time", "u32" }
    },
       [12] = {
        { "Auth Key", "str8" }
    },
    [19] = {
        { "Client IP (Hex)", "hex32" },
        { "Client Port",     "u16" },
        { "Internal IP",     "hex32" },
        { "Internal Port",   "u16" },
        { "Send Timestamp",  "u32" },
        { "Recv Timestamp",  "u32" }
    },
    -- ID 200: ID_DRIVER_SYNC (InCar)
    [200] = {
        { "Vehicle ID",         "u16" },
        { "Left/Right Keys",    "u16" },
        { "Up/Down Keys",       "u16" },
        { "Keys",               "u16" },
        { "Quat W",             "float" },
        { "Quat X",             "float" },
        { "Quat Y",             "float" },
        { "Quat Z",             "float" },
        { "Pos X",              "float" },
        { "Pos Y",              "float" },
        { "Pos Z",              "float" },
        { "Vel X",              "float" },
        { "Vel Y",              "float" },
        { "Vel Z",              "float" },
        { "Vehicle Health",     "float" },
        { "Player Health",      "u8" },
        { "Player Armour",      "u8" },
        { "Weapon / AddKey",    "wep_key" },
        { "Siren State",        "u8" },
        { "Landing Gear State", "u8" },
        { "Trailer ID",         "u16" },
        { "Train/Bike/Hydra",   "float" }
    },
    -- ID 201: ID_RCON_COMMAND
    [201] = {
        { "Command", "str32" }
    },
    -- ID 203: ID_AIM_SYNC
    [203] = {
        { "Cam Mode",        "u8" },
        { "Cam Front X",     "float" },
        { "Cam Front Y",     "float" },
        { "Cam Front Z",     "float" },
        { "Cam Pos X",       "float" },
        { "Cam Pos Y",       "float" },
        { "Cam Pos Z",       "float" },
        { "Aim Z",           "float" },
        { "Zoom / WepState", "aim_zoom" },
        { "Aspect Ratio",    "u8" }
    },
    -- ID 204: ID_WEAPONS_UPDATE
    [204] = {
        { "Target Player", "u16" },
        { "Target Actor",  "u16" },
        { "Slot 0", "u8" }, { "Weapon 0", "u8" }, { "Ammo 0", "u16" },
        { "Slot 1", "u8" }, { "Weapon 1", "u8" }, { "Ammo 1", "u16" },
        { "Slot 2", "u8" }, { "Weapon 2", "u8" }, { "Ammo 2", "u16" },
        { "Slot 3", "u8" }, { "Weapon 3", "u8" }, { "Ammo 3", "u16" },
        { "Slot 4", "u8" }, { "Weapon 4", "u8" }, { "Ammo 4", "u16" },
        { "Slot 5", "u8" }, { "Weapon 5", "u8" }, { "Ammo 5", "u16" },
        { "Slot 6", "u8" }, { "Weapon 6", "u8" }, { "Ammo 6", "u16" },
        { "Slot 7", "u8" }, { "Weapon 7", "u8" }, { "Ammo 7", "u16" },
        { "Slot 8", "u8" }, { "Weapon 8", "u8" }, { "Ammo 8", "u16" },
        { "Slot 9", "u8" }, { "Weapon 9", "u8" }, { "Ammo 9", "u16" },
        { "Slot 10", "u8" }, { "Weapon 10", "u8" }, { "Ammo 10", "u16" },
        { "Slot 11", "u8" }, { "Weapon 11", "u8" }, { "Ammo 11", "u16" },
        { "Slot 12", "u8" }, { "Weapon 12", "u8" }, { "Ammo 12", "u16" }
    },
    -- ID 205: ID_STATS_UPDATE
    [205] = {
        { "Money",       "i32" },
        { "Drunk Level", "i32" }
    },
    -- ID 206: ID_BULLET_SYNC
    [206] = {
        { "Hit Type",  "u8" },
        { "Hit ID",    "u16" },
        { "Origin X",  "float" },
        { "Origin Y",  "float" },
        { "Origin Z",  "float" },
        { "Hit Pos X", "float" },
        { "Hit Pos Y", "float" },
        { "Hit Pos Z", "float" },
        { "Offset X",  "float" },
        { "Offset Y",  "float" },
        { "Offset Z",  "float" },
        { "Weapon ID", "u8" }
    },
    -- ID 207: ID_ONFOOT_SYNC
    [207] = {
        { "Left/Right Keys", "u16" },
        { "Up/Down Keys",    "u16" },
        { "Keys",            "u16" },
        { "Pos X",           "float" },
        { "Pos Y",           "float" },
        { "Pos Z",           "float" },
        { "Quat W",          "float" },
        { "Quat X",          "float" },
        { "Quat Y",          "float" },
        { "Quat Z",          "float" },
        { "Health",          "u8" },
        { "Armour",          "u8" },
        { "Weapon / AddKey", "wep_key" },
        { "Special Action",  "u8" },
        { "Vel X",           "float" },
        { "Vel Y",           "float" },
        { "Vel Z",           "float" },
        { "Surf Offset X",   "float" },
        { "Surf Offset Y",   "float" },
        { "Surf Offset Z",   "float" },
        { "Surf Vehicle ID", "u16" },
        { "Animation ID",    "i16" },
        { "Animation Flags", "i16" }
    },
    -- ID 209: ID_UNOCCUPIED_SYNC
    [209] = {
        { "Vehicle ID",     "u16" },
        { "Seat ID",        "u8" },
        { "Roll X",         "float" },
        { "Roll Y",         "float" },
        { "Roll Z",         "float" },
        { "Direction X",    "float" },
        { "Direction Y",    "float" },
        { "Direction Z",    "float" },
        { "Pos X",          "float" },
        { "Pos Y",          "float" },
        { "Pos Z",          "float" },
        { "Vel X",          "float" },
        { "Vel Y",          "float" },
        { "Vel Z",          "float" },
        { "Angular Vel X",  "float" },
        { "Angular Vel Y",  "float" },
        { "Angular Vel Z",  "float" },
        { "Vehicle Health", "float" }
    },
    -- ID 210: ID_TRAILER_SYNC
    [210] = {
        { "Trailer ID",    "u16" },
        { "Pos X",         "float" },
        { "Pos Y",         "float" },
        { "Pos Z",         "float" },
        { "Quat W",        "float" },
        { "Quat X",        "float" },
        { "Quat Y",        "float" },
        { "Quat Z",        "float" },
        { "Vel X",         "float" },
        { "Vel Y",         "float" },
        { "Vel Z",         "float" },
        { "Angular Vel X", "float" },
        { "Angular Vel Y", "float" },
        { "Angular Vel Z", "float" }
    },
    -- ID 211: ID_PASSENGER_SYNC
    [211] = {
        { "Vehicle ID",      "u16" },
        { "Seat / DriveBy",  "seat_db" },
        { "Weapon / AddKey", "wep_key" },
        { "Health",          "u8" },
        { "Armour",          "u8" },
        { "Left/Right Keys", "u16" },
        { "Up/Down Keys",    "u16" },
        { "Keys",            "u16" },
        { "Pos X",           "float" },
        { "Pos Y",           "float" },
        { "Pos Z",           "float" }
    },
    -- ID 212: ID_SPECTATING_SYNC
    [212] = {
        { "Left/Right Keys", "u16" },
        { "Up/Down Keys",    "u16" },
        { "Keys",            "u16" },
        { "Pos X",           "float" },
        { "Pos Y",           "float" },
        { "Pos Z",           "float" }
    },
}

return M