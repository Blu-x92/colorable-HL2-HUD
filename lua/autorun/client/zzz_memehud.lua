local cl_drawhud = GetConVar("cl_drawhud")
local cvar_enable = CreateClientConVar( "cl_hud_edit_enabled", 1, true, false)
local cvar_slownumbers = CreateClientConVar( "cl_hud_slownumbers", 1, true, false)
local cvar_hidelowarmor = CreateClientConVar( "cl_hud_hide_low_armor", 0, true, false)
local cvar_hidearmor = CreateClientConVar( "cl_hud_hide_armor", 0, true, false)

local cvar_selectsound = CreateClientConVar( "cl_hud_selectsound", "Player.WeaponSelectionMoveSlot", true, false)
local cvar_movesound = CreateClientConVar( "cl_hud_movesound", "Player.WeaponSelectionClose", true, false)

local Y = ScrH()
local X = ScrW()

local MAX_SLOTS = 6
local CACHE_TIME = 1
local MOVE_SOUND = "Player.WeaponSelectionMoveSlot"
local SELECT_SOUND = "Player.WeaponSelectionClose"
local iCurSlot = 0
local iCurPos = 1
local flNextPrecache = 0
local flSelectTime = 0
local iWeaponCount = 0
local tCache = {}
local tCacheLength = {}
local FadeHud = 0

local ColR = CreateClientConVar("cl_hud_color_r", "255", true, false)
local ColG = CreateClientConVar("cl_hud_color_g", "208", true, false)
local ColB = CreateClientConVar("cl_hud_color_b", "64", true, false)

local wColR = CreateClientConVar("cl_hud_wcolor_r", "255", true, false)
local wColG = CreateClientConVar("cl_hud_wcolor_g", "48", true, false)
local wColB = CreateClientConVar("cl_hud_wcolor_b", "0", true, false)

local bColR = CreateClientConVar("cl_hud_bcolor_r", "0", true, false)
local bColG = CreateClientConVar("cl_hud_bcolor_g", "0", true, false)
local bColB = CreateClientConVar("cl_hud_bcolor_b", "0", true, false)
local bColA = CreateClientConVar("cl_hud_bcolor_a", "100", true, false)

local ColNormal = Color(255,208,64,255)
local ColWarning = Color(255,48,0,255)
local ColBackground = Color(0,0,0,100)

local IsHudEnabled = true
local HudHideLowArmor = false
local HudSlowNumbers = true

cvars.AddChangeCallback( "cl_hud_color_r", function( convar, oldValue, newValue )  ColNormal.r = tonumber( newValue ) end)
cvars.AddChangeCallback( "cl_hud_color_g", function( convar, oldValue, newValue )  ColNormal.g = tonumber( newValue ) end)
cvars.AddChangeCallback( "cl_hud_color_b", function( convar, oldValue, newValue )  ColNormal.b = tonumber( newValue ) end)

cvars.AddChangeCallback( "cl_hud_wcolor_r", function( convar, oldValue, newValue )  ColWarning.r = tonumber( newValue ) end)
cvars.AddChangeCallback( "cl_hud_wcolor_g", function( convar, oldValue, newValue )  ColWarning.g = tonumber( newValue ) end)
cvars.AddChangeCallback( "cl_hud_wcolor_b", function( convar, oldValue, newValue ) ColWarning.b = tonumber( newValue ) end)

cvars.AddChangeCallback( "cl_hud_bcolor_r", function( convar, oldValue, newValue )  ColBackground.r = tonumber( newValue ) end)
cvars.AddChangeCallback( "cl_hud_bcolor_g", function( convar, oldValue, newValue )  ColBackground.g = tonumber( newValue ) end)
cvars.AddChangeCallback( "cl_hud_bcolor_b", function( convar, oldValue, newValue ) ColBackground.b = tonumber( newValue ) end)
cvars.AddChangeCallback( "cl_hud_bcolor_a", function( convar, oldValue, newValue ) ColBackground.a = tonumber( newValue ) end)

cvars.AddChangeCallback( "cl_hud_edit_enabled", function( convar, oldValue, newValue ) IsHudEnabled = tonumber( newValue ) ~=0 end)
cvars.AddChangeCallback( "cl_hud_hide_low_armor", function( convar, oldValue, newValue ) HudHideLowArmor = tonumber( newValue ) ~=0 end)
cvars.AddChangeCallback( "cl_hud_slownumbers", function( convar, oldValue, newValue ) HudSlowNumbers = tonumber( newValue ) ~=0 end)

IsHudEnabled = cvar_enable:GetBool()
HudHideLowArmor = cvar_hidelowarmor:GetBool()
MOVE_SOUND = cvar_movesound:GetString()
SELECT_SOUND = cvar_selectsound:GetString()
HudSlowNumbers = cvar_slownumbers:GetBool()

ColNormal = Color( ColR:GetInt(),ColG:GetInt(),ColB:GetInt(),255 )
ColWarning = Color( wColR:GetInt(),wColG:GetInt(),wColB:GetInt(),255 )
ColBackground = Color( bColR:GetInt(),bColG:GetInt(),bColB:GetInt(),bColA:GetInt() )

local weaponlist = {
	["weapon_smg1"] = "a",
	["weapon_shotgun"] = "b",
	["weapon_crowbar"] = "c",
	["weapon_pistol"] = "d",
	["weapon_357"] = "e",
	--["weapon_combinesniper"] = "f",
	["weapon_crossbow"] = "g",
	["weapon_physgun"] = "h",
	["weapon_rpg"] = "i",
	["weapon_bugbait"] = "j",
	["weapon_frag"] = "k",
	["weapon_ar2"] = "l",
	["weapon_physcannon"] = "m",
	["weapon_stunstick"] = "n",
	["weapon_slam"] = "o",
}

local function DrawWeaponHUD()
	local IdleTime = flSelectTime - RealTime()
	if FadeHud <= 0.01 and IdleTime <= -2 then
		iCurSlot = 0
		FadeHud = 0
	end
	
	local sz = Y * 0.068
	local szg = sz * 0.22
	local SlotSizeX = (sz * 3 + szg * 2)
	
	local XStart = X * 0.5035 - (sz + szg) * 4
	
	FadeHud = FadeHud + ((IdleTime > -2 and 1 or 0) - FadeHud) * FrameTime() * 5
	
	
	
	local Col = Color(ColBackground.r,ColBackground.g,ColBackground.b,ColBackground.a * FadeHud) 
	local Col2 = Color(ColNormal.r,ColNormal.g,ColNormal.b,255 * FadeHud)
	local Col3 = Color(ColWarning.r,ColWarning.g,ColWarning.b,255 * FadeHud)
	
	
	local xVal = 0
	local yVal = 0
	for i, _ in ipairs( tCache ) do
		local IsSlotSelected = iCurSlot == i
		
		local xoffset = XStart + xVal 
		
		if not IsSlotSelected then
			draw.RoundedBox( 8, xoffset, Y * 0.033, sz, sz, Col )
		else
			for k, v in ipairs( tCache[i] ) do
				if IsValid( v ) then
					local IsSelected = (k == iCurPos)
					
					local SlotSizeY = (IsSelected and sz * 2.5 or sz * 0.63)
					local yoffset = Y * 0.033 + yVal
					
					local objCol = (v:GetPrimaryAmmoType() > 0) and ((LocalPlayer():GetAmmoCount( v:GetPrimaryAmmoType() ) > 0) and Col2 or Col3) or Col2
					
					draw.RoundedBox( 8, xoffset, yoffset, SlotSizeX, SlotSizeY, Col )
					
					draw.DrawText(v:GetPrintName(), "HudHintText2", xoffset + SlotSizeX * 0.5, yoffset + SlotSizeY - sz * 0.4, objCol, TEXT_ALIGN_CENTER)
					
					if IsSelected then
						if isstring( weaponlist[v:GetClass()] ) then
							local GlowC = Color(objCol.r,objCol.g,objCol.b,objCol.a * math.abs( math.cos( CurTime() * 4 ) ))
							
							draw.DrawText(weaponlist[v:GetClass()], "WeaponLetterIconGlow", xoffset + SlotSizeX * 0.5, yoffset + SlotSizeY * 0.1, GlowC, TEXT_ALIGN_CENTER)
							draw.DrawText(weaponlist[v:GetClass()], "WeaponLetterIcon", xoffset + SlotSizeX * 0.5, yoffset + SlotSizeY * 0.1, objCol, TEXT_ALIGN_CENTER)
						else
							if v.DrawWeaponSelection then
								v:DrawWeaponSelection( xoffset,yoffset, SlotSizeX, SlotSizeY, Col2.a )
							end
						end
					end
					
					yVal = yVal + SlotSizeY + szg
				end
			end
		end
		
		draw.DrawText(i, "HudHintTextLarge2", xoffset + sz * 0.1, Y * 0.033 + sz * 0.1, Col2, TEXT_ALIGN_LEFT)
		
		xVal = xVal + (IsSlotSelected and (sz + szg) * 3 or (sz + szg))
	end
end

local function UpdateFonts()
	local screenw = ScrW()
	local screenh = ScrH()
	local Widescreen = (screenw / screenh) > (4 / 3)

	surface.CreateFont("HudNumbers2", { font = "HalfLife2", size = (screenh / 15), weight = 0, blursize = 0, antialias = true, additive = true })
	surface.CreateFont("HudNumbersSmall2", { font = "HalfLife2", size = (screenh / 30), weight = 1000, blursize = 0, antialias = true, additive = true })
	surface.CreateFont("HudNumbersGlow2", { font = "HalfLife2", size = (screenh / 15), weight = 0, blursize = 10, scanlines = 5, antialias = true, additive = true })
	surface.CreateFont("HudNumbersSmallGlow2", { font = "HalfLife2", size = (screenh / 30), weight = 0, blursize = 5, scanlines = 5, antialias = true, additive = true })

	surface.CreateFont("HudHintTextLarge2", { font = "Verdana", size = (screenh / 50), weight = 3000, antialias = true, additive = true })
	surface.CreateFont("HudHintText2", { font = "Verdana", size = (screenh / 70), weight = 3000, antialias = true, additive = true })
	
	surface.CreateFont("WeaponLetterIcon", { font = "HalfLife2", size = (screenh / 8), weight = 0, antialias = true, additive = true })
	surface.CreateFont("WeaponLetterIconGlow", { font = "HalfLife2", size = (screenh / 8), weight = 0, blursize = 15, scanlines = 3, antialias = true, additive = true })
end
UpdateFonts()

local function PrintHealth(ply, curtime, Rate)
	if not ply:Alive() then ply.smHealth = 0 return end
	
	local health = ply:Health()
	
	if not isnumber( ply.smHealth ) then ply.smHealth = 0 end
	
	local Delta = math.Clamp(health - ply.smHealth,-Rate,Rate)

	ply.smHealth = ply.smHealth + Delta
	ply.hChange = ply.hChange or 0
	
	if math.abs(Delta) > 0 then ply.hChange = curtime + 1 end
	
	local Glow = math.min(math.max(ply.hChange - curtime,0) / 2  * 300,255)
	
	local print = math.Round(ply.smHealth,0)
	
	local xPos = Y * 0.035
	local yPos = Y * 0.9
	local xScale = Y * 0.21
	local yScale = Y * 0.075
	
	local LowHealth = (print >= 20)
	
	local Col = LowHealth and ColNormal or ColWarning
	
	local Flash = LowHealth and 0 or (math.max( math.cos( curtime * 6 ), 0 ))
	local invFlash = 1 - Flash
	local bgCol = Color( ColWarning.r * Flash + ColBackground.r * invFlash, ColWarning.g * Flash + ColBackground.g * invFlash, ColWarning.b * Flash + ColBackground.b * invFlash, ColBackground.a )
	
	draw.RoundedBox( 8, xPos, yPos, xScale, yScale, bgCol )
	
	draw.DrawText(print, "HudNumbers2", xPos + xScale * 0.48, yPos + yScale * 0.05, Col, TEXT_ALIGN_LEFT)
	draw.DrawText(print, "HudNumbersGlow2", xPos + xScale * 0.48, yPos + yScale * 0.05, Color(Col.r,Col.g,Col.b,Glow), TEXT_ALIGN_LEFT)
	
	draw.DrawText("HEALTH", "HudHintTextLarge2", xPos + xScale * 0.065, yPos + yScale * 0.54, Col, TEXT_ALIGN_LEFT)
end

local function PrintArmor(ply, curtime, Rate)
	if not ply:Alive() then ply.smArmor = 0 return end
	
	local armor = ply:Armor()
	
	if not isnumber( ply.smArmor ) then ply.smArmor = 0 end
	
	local Delta = math.Clamp(armor - ply.smArmor,-Rate,Rate)
	
	ply.smArmor = ply.smArmor + Delta
	ply.aChange = ply.aChange or 0
	
	if math.abs(Delta) > 0 then ply.aChange = curtime + 1 end
	
	local Glow = math.min(math.max(ply.aChange - curtime,0) / 2  * 300,255)
	
	local print = math.Round(ply.smArmor,0)
	
	if print <= 0 and HudHideLowArmor then return end
	
	local xPos = Y * 0.292
	local yPos = Y * 0.9
	local xScale = Y * 0.22
	local yScale = Y * 0.075
	
	local Col = (print > 1) and ColNormal or ColWarning
	
	draw.RoundedBox( 8, xPos, yPos, xScale, yScale,  ColBackground )

	draw.DrawText(print, "HudNumbers2", xPos + xScale * 0.46, yPos + yScale * 0.05, Col, TEXT_ALIGN_LEFT)
	draw.DrawText(print, "HudNumbersGlow2", xPos + xScale * 0.46, yPos + yScale * 0.05, Color(Col.r,Col.g,Col.b,Glow), TEXT_ALIGN_LEFT)
	
	draw.DrawText("ARMOR", "HudHintTextLarge2", xPos + xScale * 0.065, yPos + yScale * 0.54, Col, TEXT_ALIGN_LEFT)
end

local xScale = Y * 0.28
local smOffset = 0
local oldweapon
local function PrintAmmo(ply, curtime, Rate)	
	local weapon = ply:GetActiveWeapon()
	
	if ply:InVehicle() and not ply:GetAllowWeaponsInVehicle() then return end
	
	ply.weaponChange = ply.weaponChange and ply.weaponChange or 0
	if oldweapon ~= weapon then
		oldweapon = weapon
		ply.weaponChange = curtime + 1
	end
	
	if not IsValid( weapon ) then return end
	
	local ammotype = weapon:GetPrimaryAmmoType()
	local ammotype2 = weapon:GetSecondaryAmmoType()
	
	local clip = weapon:Clip1()
	
	local maxclip = weapon:GetMaxClip1()
	local maxclip2 = weapon:GetMaxClip2()
	local curammo = ply:GetAmmoCount( ammotype )
	local curammo2 = ply:GetAmmoCount( ammotype2 )
	
	if ammotype == -1 and ammotype2 == -1 and maxclip <= 0 and maxclip2 <= 0 then 
		ply.smClip1 = 0
		ply.smCurAmmo1 = 0
		ply.smCurAmmo2 = 0
		
		return
	end
	
	if ammotype == -1 and ammotype2 >= 0 then
		ammotype = ammotype2
		ammotype2 = -1
		curammo = curammo2
		curammo2 = -1
		maxclip = -1
		maxclip2 = -1
	elseif ammotype == ammotype2 then
		
		ammotype2 = -1
		maxclip2 = -1
		curammo2 = -1
		
	elseif ammotype == -1 and ammotype2 == -1 then
		ammotype = 1
		ammotype2 = -1
		curammo = clip
		curammo2 = -1
		maxclip = -1
		maxclip2 = -1
	end
	
	local DesxScale = Y * 0.28
	if maxclip == -1 then
		clip = curammo
		DesxScale = Y * 0.21
	end
	
	if not isnumber( ply.smClip1 ) then ply.smClip1 = 0 end
	if not isnumber( ply.smCurAmmo1 ) then ply.smCurAmmo1 = 0 end
	if not isnumber( ply.smCurAmmo2 ) then ply.smCurAmmo2 = 0 end
	
	local Delta = math.Clamp(clip - ply.smClip1,-Rate,Rate)
	local Delta2 = math.Clamp(curammo - ply.smCurAmmo1,-Rate,Rate)
	local Delta3 = math.Clamp(curammo2 - ply.smCurAmmo2,-Rate,Rate)
	
	ply.smClip1 = ply.smClip1 + Delta
	ply.smCurAmmo1 = ply.smCurAmmo1 + Delta2
	ply.smCurAmmo2 = ply.smCurAmmo2 + Delta3
	
	ply.c1Change = ply.c1Change or 0
	ply.ca1Change = ply.ca1Change or 0
	ply.ca2Change = ply.ca2Change or 0
	
	if math.abs(Delta) > 0 then ply.c1Change = curtime + 1 end
	if math.abs(Delta2) > 0 then ply.ca1Change = curtime + 1 end
	if math.abs(Delta3) > 0 then ply.ca2Change = curtime + 1 end
	
	local Glow = math.min(math.max(ply.c1Change - curtime,0) / 2  * 300,255)
	local Glow2 = math.min(math.max(ply.ca1Change - curtime,0) / 2  * 300,255)
	local Glow3 = math.min(math.max(ply.ca2Change - curtime,0) / 2  * 300,255)
	
	local smRate =  FrameTime() * 5
	
	xScale = xScale + (DesxScale - xScale) * smRate
	
	smOffset = smOffset + (((ammotype2 == -1) and 0 or Y * 0.15) - smOffset) * smRate
	
	local yScale = Y * 0.075
	local xPos = X - Y * 0.035 - xScale - smOffset
	local yPos = Y * 0.9
	
	local Col = (clip > 0) and ColNormal or ColWarning
	local Col1 = (curammo > 0) and ColNormal or ColWarning
	local Col2 = (curammo2 > 0) and ColNormal or ColWarning
	
	local print = math.Round(ply.smClip1,0)
	local print2 = math.Round(ply.smCurAmmo1,0)
	local print3= math.Round(ply.smCurAmmo2,0)
	
	local GlowB = math.min(math.max(ply.weaponChange - curtime,0) / 2,255)
	local invGlowB = 1 - GlowB
	local ColB = Color( ColNormal.r * GlowB + ColBackground.r * invGlowB, ColNormal.g * GlowB + ColBackground.g * invGlowB, ColNormal.b * GlowB + ColBackground.b * invGlowB, ColBackground.a )
	
	draw.RoundedBox( 8, xPos, yPos, xScale, yScale, ColB )

	draw.DrawText(print, "HudNumbers2", xPos + Y * 0.0938, yPos + yScale * 0.05, Col, TEXT_ALIGN_LEFT)
	draw.DrawText(print, "HudNumbersGlow2", xPos + Y * 0.0938, yPos + yScale * 0.05, Color(Col.r,Col.g,Col.b,Glow), TEXT_ALIGN_LEFT)
	
	draw.DrawText("AMMO", "HudHintTextLarge2", xPos + xScale * 0.065, yPos + yScale * 0.54, Col, TEXT_ALIGN_LEFT)
	
	if maxclip ~= -1 then
		draw.DrawText(print2, "HudNumbersSmall2", xPos + xScale * 0.73, yPos + yScale * 0.45, Col1, TEXT_ALIGN_LEFT)
		draw.DrawText(print2, "HudNumbersSmallGlow2", xPos + xScale * 0.73, yPos + yScale * 0.45,  Color(Col1.r,Col1.g,Col1.b,Glow2), TEXT_ALIGN_LEFT)
	end
	
	if ammotype2 ~= -1 then
		local xScale = Y * 0.122
		local xPos = X - Y * 0.035 - xScale
		draw.RoundedBox( 8, xPos, yPos, xScale, yScale, ColB )
		
		draw.DrawText("ALT", "HudHintTextLarge2", xPos + xScale * 0.1, yPos + yScale * 0.54, Col2, TEXT_ALIGN_LEFT)
		
		draw.DrawText(print3, "HudNumbers2", xPos + Y * 0.075, yPos + yScale * 0.05, Col2, TEXT_ALIGN_LEFT)
		draw.DrawText(print3, "HudNumbersGlow2", xPos + Y * 0.075, yPos + yScale * 0.05, Color(Col2.r,Col2.g,Col2.b,Glow3), TEXT_ALIGN_LEFT)
	end
end

for i = 1, MAX_SLOTS do
	tCache[i] = {}
	tCacheLength[i] = 0
end

local function PrecacheWeps()
	for i = 1, MAX_SLOTS do
		for j = 1, tCacheLength[i] do
			tCache[i][j] = nil
		end

		tCacheLength[i] = 0
	end

	flNextPrecache = RealTime() + CACHE_TIME
	iWeaponCount = 0

	for _, pWeapon in ipairs(LocalPlayer():GetWeapons()) do
		iWeaponCount = iWeaponCount + 1

		local iSlot = pWeapon:GetSlot() + 1

		if (iSlot <= MAX_SLOTS) then
			local iLen = tCacheLength[iSlot] + 1
			tCacheLength[iSlot] = iLen
			tCache[iSlot][iLen] = pWeapon
		end
	end

	if (iCurSlot ~= 0) then
		local iLen = tCacheLength[iCurSlot]

		if (iLen < iCurPos) then
			if (iLen == 0) then
				iCurSlot = 0
			else
				iCurPos = iLen
			end
		end
	end
end

hook.Add("HUDPaint", "!!!!!lolmeem", function()
	if not IsHudEnabled then return end
	
	local ply = LocalPlayer()
	
	if not IsValid( ply ) then return end
	
	local curtime = CurTime()
	local Rate = 1 * FrameTime() * 80
	if not HudSlowNumbers then Rate = 1e999 end
	
	PrintHealth(ply, curtime, Rate)
	PrintArmor(ply, curtime, Rate)
	PrintAmmo(ply, curtime, Rate)
	
	if Y ~= ScrH() then
		UpdateFonts()
		
		Y = ScrH()
		X = ScrW()
	end
	
	if (iCurSlot == 0 or not cl_drawhud:GetBool()) then
		return
	end

	if ply:Alive() and (not ply:InVehicle() or ply:GetAllowWeaponsInVehicle()) then
		if flNextPrecache <= RealTime() then
			PrecacheWeps()
		end

		DrawWeaponHUD()
	else
		iCurSlot = 0
	end
end )

local hide = {
	["CHudHealth"] = true,
	["CHudBattery"] = true,
	["CHudAmmo"] = true,
	["CHudSecondaryAmmo"] = true,
	["CHudWeaponSelection"] = true,
}
hook.Add( "HUDShouldDraw", "!!!!HideHUD", function( name ) 
	if IsHudEnabled then
		if ( hide[ name ] ) then return false end
	end
end )

hook.Add("PlayerBindPress", "!!!!!HL2WeaponSelector", function(pPlayer, sBind, bPressed)
	if not IsHudEnabled then return end
	
	if (not pPlayer:Alive() or pPlayer:InVehicle() and not pPlayer:GetAllowWeaponsInVehicle()) then
		return
	end

	sBind = string.lower(sBind)
	
	if (sBind == "cancelselect") then
		if (bPressed) then
			iCurSlot = 0
		end

		return true
	end

	if not pPlayer:KeyDown( IN_ATTACK ) then
		if (sBind == "invprev") then
			if (not bPressed) then
				return true
			end

			PrecacheWeps()

			if (iWeaponCount == 0) then
				return true
			end

			local bLoop = iCurSlot == 0

			if (bLoop) then
				local pActiveWeapon = pPlayer:GetActiveWeapon()

				if (pActiveWeapon:IsValid()) then
					local iSlot = pActiveWeapon:GetSlot() + 1
					local tSlotCache = tCache[iSlot]

					if (tSlotCache[1] ~= pActiveWeapon) then
						iCurSlot = iSlot
						iCurPos = 1

						for i = 2, tCacheLength[iSlot] do
							if (tSlotCache[i] == pActiveWeapon) then
								iCurPos = i - 1

								break
							end
						end

						flSelectTime = RealTime()
						pPlayer:EmitSound(MOVE_SOUND)

						return true
					end

					iCurSlot = iSlot
				end
			end

			if (bLoop or iCurPos == 1) then
				repeat
					if (iCurSlot <= 1) then
						iCurSlot = MAX_SLOTS
					else
						iCurSlot = iCurSlot - 1
					end
				until(tCacheLength[iCurSlot] ~= 0)

				iCurPos = tCacheLength[iCurSlot]
			else
				iCurPos = iCurPos - 1
			end

			flSelectTime = RealTime()
			pPlayer:EmitSound(MOVE_SOUND)

			return true
		end

		if (sBind == "invnext") then
			if (not bPressed) then
				return true
			end

			PrecacheWeps()

			if (iWeaponCount == 0) then
				return true
			end

			local bLoop = iCurSlot == 0

			if (bLoop) then
				local pActiveWeapon = pPlayer:GetActiveWeapon()

				if (pActiveWeapon:IsValid()) then
					local iSlot = pActiveWeapon:GetSlot() + 1
					local iLen = tCacheLength[iSlot]
					local tSlotCache = tCache[iSlot]

					if (tSlotCache[iLen] ~= pActiveWeapon) then
						iCurSlot = iSlot
						iCurPos = 1

						for i = 1, iLen - 1 do
							if (tSlotCache[i] == pActiveWeapon) then
								iCurPos = i + 1

								break
							end
						end

						flSelectTime = RealTime()
						pPlayer:EmitSound(MOVE_SOUND)

						return true
					end

					iCurSlot = iSlot
				end
			end

			if (bLoop or iCurPos == tCacheLength[iCurSlot]) then
				repeat
					if (iCurSlot == MAX_SLOTS) then
						iCurSlot = 1
					else
						iCurSlot = iCurSlot + 1
					end
				until(tCacheLength[iCurSlot] ~= 0)
				
				iCurPos = 1
			else
				iCurPos = iCurPos + 1
			end

			flSelectTime = RealTime()
			pPlayer:EmitSound(MOVE_SOUND)

			return true
		end
	end

	if (sBind:sub(1, 4) == "slot") then
		local iSlot = tonumber(sBind:sub(5))

		if (iSlot == nil) then
			return
		end

		if (not bPressed) then
			return true
		end

		PrecacheWeps()

		if (iWeaponCount == 0) then
			pPlayer:EmitSound(MOVE_SOUND)

			return true
		end

		if (iSlot <= MAX_SLOTS) then
			if (iSlot == iCurSlot) then
				if (iCurPos == tCacheLength[iCurSlot]) then
					iCurPos = 1
				else
					iCurPos = iCurPos + 1
				end
			elseif (tCacheLength[iSlot] ~= 0) then
				iCurSlot = iSlot
				iCurPos = 1
			end

			flSelectTime = RealTime()
			pPlayer:EmitSound(MOVE_SOUND)
		end

		return true
	end

	if (iCurSlot ~= 0) then
		if (sBind == "+attack") then
			local pWeapon = tCache[iCurSlot][iCurPos]
			iCurSlot = 0

			if (pWeapon:IsValid() and pWeapon ~= pPlayer:GetActiveWeapon()) then
				input.SelectWeapon(pWeapon)
			end

			flSelectTime = RealTime()
			pPlayer:EmitSound(SELECT_SOUND)

			return true
		end

		if (sBind == "+attack2") then
			flSelectTime = RealTime()
			iCurSlot = 0

			return true
		end
	end
end)

local function OpenMenu()
	local Frame = vgui.Create( "DFrame" )
	Frame:SetSize( 600, 600 )
	Frame:SetTitle( "HUD Editor" )
	Frame:SetDraggable( true )
	Frame:MakePopup()
	Frame:Center()
	
	local DermaCheckbox = vgui.Create("DCheckBoxLabel", Frame)
	DermaCheckbox:SetPos(10, 40)
	DermaCheckbox:SetText("Enable")
	DermaCheckbox:SetConVar("cl_hud_edit_enabled")
	DermaCheckbox:SizeToContents() 
	
	local DermaCheckbox = vgui.Create("DCheckBoxLabel", Frame)
	DermaCheckbox:SetPos(10, 70)
	DermaCheckbox:SetText("Slow Numbers")
	DermaCheckbox:SetConVar("cl_hud_slownumbers")
	DermaCheckbox:SizeToContents() 
	
	local DermaCheckbox = vgui.Create("DCheckBoxLabel", Frame)
	DermaCheckbox:SetPos(100, 40)
	DermaCheckbox:SetText("Only show armor when > 0 ")
	DermaCheckbox:SetConVar("cl_hud_hide_low_armor")
	DermaCheckbox:SizeToContents() 

	local DLabel = vgui.Create( "DLabel", Frame )
	DLabel:SetPos( 290, 35 )
	DLabel:SetText( "Move snd:" )
	
	local TextEntry = vgui.Create( "DTextEntry", Frame )
	TextEntry:SetPos( 350, 35 )
	TextEntry:SetSize( 240, 20 )
	TextEntry:SetText( MOVE_SOUND )
	TextEntry.OnEnter = function( self )
		MOVE_SOUND = self:GetValue()
		cvar_movesound:SetString( self:GetValue() )
	end
	
	local DLabel = vgui.Create( "DLabel", Frame )
	DLabel:SetPos( 290, 70 )
	DLabel:SetText( "Select snd:" )
	
	local aTextEntry = vgui.Create( "DTextEntry", Frame )
	aTextEntry:SetPos( 350, 65 )
	aTextEntry:SetSize( 240, 20 )
	aTextEntry:SetText( SELECT_SOUND )
	aTextEntry.OnEnter = function( self )
		SELECT_SOUND = self:GetValue()
		cvar_selectsound:SetString( self:GetValue() )
	end
	
	local Mixer = vgui.Create("DColorMixer", Frame)
	Mixer:SetLabel( "Main Color" )
	Mixer:SetPos( 10, 90 )
	Mixer:SetSize( 285, 250 )
	Mixer:SetPalette(true) 
	Mixer:SetAlphaBar(false)
	Mixer:SetWangs(true)
	Mixer:SetConVarR( "cl_hud_color_r" )
	Mixer:SetConVarG( "cl_hud_color_g" )
	Mixer:SetConVarB( "cl_hud_color_b" )
	
	local wMixer = vgui.Create("DColorMixer", Frame)
	wMixer:SetLabel( "Warning Color" )
	wMixer:SetPos( 300, 90 )
	wMixer:SetSize( 285, 250 )
	wMixer:SetPalette(true) 
	wMixer:SetAlphaBar(false)
	wMixer:SetWangs(true)
	wMixer:SetConVarR( "cl_hud_wcolor_r" )
	wMixer:SetConVarG( "cl_hud_wcolor_g" )
	wMixer:SetConVarB( "cl_hud_wcolor_b" )

	local bMixer = vgui.Create("DColorMixer", Frame)
	bMixer:SetLabel( "Background Color" )
	bMixer:SetPos( 10, 348 )
	bMixer:SetSize( 400, 200 )
	bMixer:SetPalette(true) 
	bMixer:SetAlphaBar(true)
	bMixer:SetWangs(true)
	bMixer:SetConVarR( "cl_hud_bcolor_r" )
	bMixer:SetConVarG( "cl_hud_bcolor_g" )
	bMixer:SetConVarB( "cl_hud_bcolor_b" )
	bMixer:SetConVarA( "cl_hud_bcolor_a" )
	
	local DermaButton = vgui.Create( "DButton", Frame )
	DermaButton:SetText( "Reset" )
	DermaButton:SetPos( 10, 560 )
	DermaButton:SetSize( 580, 30 )
	DermaButton.DoClick = function()
		ColR:SetInt( 255 )
		ColG:SetInt( 208 )
		ColB:SetInt( 64 )
		
		wColR:SetInt( 255 )
		wColG:SetInt( 48 )
		wColB:SetInt( 0 )
		
		bColR:SetInt( 0 )
		bColG:SetInt( 0 )
		bColB:SetInt( 0 )
		bColA:SetInt( 100 )
		
		cvar_enable:SetBool( true )
		cvar_hidelowarmor:SetBool( false )
		cvar_slownumbers:SetBool( true )
		
		cvar_selectsound:SetString( "Player.WeaponSelectionClose" )
		cvar_movesound:SetString( "Player.WeaponSelectionMoveSlot" )

		SELECT_SOUND = "Player.WeaponSelectionClose"
		MOVE_SOUND = "Player.WeaponSelectionMoveSlot"
		
		TextEntry:SetText( MOVE_SOUND )
		aTextEntry:SetText( SELECT_SOUND )
	end
end

list.Set( "DesktopWindows", "L_HUD_EDIT", {
	title = "HUD Editor",
	icon = "icon64/tool.png",
	init = function( icon, window )
		OpenMenu()
	end
} )

concommand.Add( "hud_openeditor", function( ply, cmd, args ) OpenMenu() end )
