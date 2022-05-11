/* clang-format off */
#include <karyuu>
#include <sdkhooks>
#include <chat-processor>

#undef REQUIRE_PLUGIN
#undef REQUIRE_EXTENSIONS
#tryinclude <myjailbreak>
#define REQUIRE_EXTENSIONS
#define REQUIRE_PLUGIN

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name			= "| CS:GO | Simple-VIP",
	author		= "KitsuneLab ~ Karyuu",
	description = "Our old Simple-VIP system, but fully remade, optimised and upgraded.",
	version		= "1.211b",
	url			= "https://www.kitsune-lab.dev"
};
/* clang-format on */

ConVar g_hPrefix,
	g_hVIPFlag,
	g_hPlusHP,
	g_hPlusAR,
	g_hPlusHE,
	g_hRainbow,
	g_hChatUtils,
	g_hClanUtils;

Cookie g_hVIPTag,
	g_hVIPClanTag,
	g_hVIPTagColor,
	g_hVIPNameColor,
	g_hVIPChatColor,
	g_hHealthState,
	g_hArmorState,
	g_hRainbowState;

bool g_bMyJailbreakFound				 = false,
	  g_bIsClientVIP[MAXPLAYERS + 1]	 = { false, ... },
	  g_bHealthState[MAXPLAYERS + 1]	 = { false, ... },
	  g_bRainbowState[MAXPLAYERS + 1] = { false, ... },
	  g_bArmorState[MAXPLAYERS + 1]	 = { false, ... };

int g_iOnTagType[MAXPLAYERS + 1]		 = 0, /* 1 - Clan, 2 - Name */
	g_iTagMode[MAXPLAYERS + 1];

char g_sPrefix[128],
	g_sTag[MAXPLAYERS + 1][32],
	g_sClanTag[MAXPLAYERS + 1][32];

int	 iVipFlag;

Handle CheckEventTimer = null;

public void OnMapStart()
{
	C_Initialize();

	g_hPrefix	 = CreateConVar("sm_svip_prefix", "{default}「{lightred}Kitsune-VIP{default}」{lime}", "Modify the plugin's chat prefix (color codes supported)");
	g_hVIPFlag	 = CreateConVar("sm_svip_flag", "a", "Flag of the VIPs'. Use only flag letters!");
	g_hPlusHP	 = CreateConVar("sm_svip_extra_hp", "5", "Bonus HP for VIP users (Set this to '0' to disable)", _, true, 0.0, true, 1000.0);
	g_hPlusAR	 = CreateConVar("sm_svip_extra_armor", "100", "Bonus Armor for VIP users (Set this to '0' to disable)", _, true, 0.0, true, 100.0);
	g_hPlusHE	 = CreateConVar("sm_svip_extra_helmet", "1", "Bonus Helmet for VIP users (0 - Disabled, 1 - Enabled)", _, true, 0.0, true, 1.0);
	g_hChatUtils = CreateConVar("sm_svip_chat_utils", "1", "Chat modification utilities (colors, prefix, etc) for VIP users (0 - Disabled, 1 - Enabled)", _, true, 0.0, true, 1.0);
	g_hClanUtils = CreateConVar("sm_svip_clan_utils", "1", "Scoreboard utilities (clan-tag) for VIP users (0 - Disabled, 1 - Enabled)", _, true, 0.0, true, 1.0);
	g_hRainbow	 = CreateConVar("sm_svip_rainbow_model", "1", "Allow vip players to use a rainbow model?", _, true, 0.0, true, 1.0);

	AutoExecConfig(true);

	g_hVIPTag		 = RegClientCookie("SimpleVIPTags", "SimpleVIP Tag", CookieAccess_Protected);
	g_hVIPClanTag	 = RegClientCookie("SimpleVIPCTag", "SimpleVIP ClanTag", CookieAccess_Protected);
	g_hVIPTagColor	 = RegClientCookie("SimpleVIPTagColor", "SimpleVIP TagColor", CookieAccess_Protected);
	g_hVIPNameColor = RegClientCookie("SimpleVIPNameColor", "SimpleVIP NameColor", CookieAccess_Protected);
	g_hVIPChatColor = RegClientCookie("SimpleVIPChatColor", "SimpleVIP ChatColor", CookieAccess_Protected);
	g_hHealthState	 = RegClientCookie("SimpleVIPHealthState", "SimpleVIP ChatColor", CookieAccess_Protected);
	g_hArmorState	 = RegClientCookie("SimpleVIPArmorState", "SimpleVIP ChatColor", CookieAccess_Protected);
	g_hRainbowState = RegClientCookie("SimpleVIPRainbow", "SimpleVIP Rainbow", CookieAccess_Protected);

	HookEvent("player_spawn", OnPlayerSpawn);
	HookEvent("round_start", OnRoundStart);

	for (int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if (IsClientConnected(iClient))
			OnClientPostAdminCheck(iClient);
	}
}

public void OnRoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	if (g_bMyJailbreakFound)
	{
		if (CheckEventTimer != null)
			delete CheckEventTimer;

		CheckEventTimer = CreateTimer(0.3, Timer_CheckForEvent_HP, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_CheckForEvent_HP(Handle timer, any data)
{
	if (!g_bMyJailbreakFound)
		return Plugin_Stop;

	if (MyJailbreak_IsEventDayPlanned())
	{
		for (int iClient = 1; iClient <= MaxClients; iClient++)
		{
			if (!IsClientConnected(iClient))
				continue;

			Karyuu_ResetArmor(iClient);

			if (GetClientHealth(iClient) > 100)
				SetEntityHealth(iClient, 100);
		}
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

public void OnConfigsExecuted()
{
	g_hPrefix.GetString(STRING(g_sPrefix));
	CFormat(STRING(g_sPrefix));

	char sVipFlag[8];
	g_hVIPFlag.GetString(STRING(sVipFlag));
	iVipFlag = ReadFlagString(sVipFlag);
	Karyuu_RegMultipleCommand("sm_vip;sm_svip;sm_vipmenu", cmd_VIP_Menu, "Kitsune-VIP | Open main VIP menu", iVipFlag);

	if (g_hChatUtils.BoolValue)
		Karyuu_RegMultipleCommand("sm_chat;sm_cu;sm_chatutils;sm_chatutilities", cmd_VIP_ChatUtils, "Kitsune-VIP | Open Chat Modifications VIP menu", iVipFlag);

	if (g_hClanUtils.BoolValue)
		Karyuu_RegMultipleCommand("sm_clan;sm_sb;sm_scoreboard;sm_clantag;sm_ct", cmd_VIP_ClanUtils, "Kitsune-VIP | Open Scoreboard Editor VIP menu", iVipFlag);
}

public Action cmd_VIP_ChatUtils(int iClient, int iArgs)
{
	if (!g_hChatUtils.BoolValue)
	{
		CPrintToChat(iClient, "%s%T", g_sPrefix, "Error_ModuleDisabled", iClient);
		return Plugin_Handled;
	}

	if (!IsClientInGame(iClient))
	{
		CPrintToChat(iClient, "%T", "Error_InGameOnly", iClient);
		return Plugin_Handled;
	}

	VIP_NameTagMenu(iClient);
	return Plugin_Handled;
}

public Action cmd_VIP_ClanUtils(int iClient, int iArgs)
{
	if (!g_hClanUtils.BoolValue)
	{
		CPrintToChat(iClient, "%s%T", g_sPrefix, "Error_ModuleDisabled", iClient);
		return Plugin_Handled;
	}

	if (!IsClientInGame(iClient))
	{
		CPrintToChat(iClient, "%s%T", g_sPrefix, "Error_InGameOnly", iClient);
		return Plugin_Handled;
	}

	VIP_ClanTag(iClient);
	return Plugin_Handled;
}

public void OnAllPluginsLoaded()
{
	g_bMyJailbreakFound = LibraryExists("myjailbreak");
}

public void OnLibraryAdded(const char[] sLibraryName)
{
	if (Karyuu_StrEquals(sLibraryName, "myjailbreak"))
		g_bMyJailbreakFound = true;
}

public void OnLibraryRemoved(const char[] sLibraryName)
{
	if (Karyuu_StrEquals(sLibraryName, "myjailbreak"))
		g_bMyJailbreakFound = false;
}

public Action cmd_VIP_Menu(int iClient, int iArgs)
{
	if (!IsClientInGame(iClient))
	{
		CPrintToChat(iClient, "%T", "Error_InGameOnly", iClient);
		return Plugin_Handled;
	}

	Menu mMenu = CreateMenu(menuHandler_VipMenu);
	Karyuu_Menu_SetTitle(mMenu, "-- Kitsune-VIP --");

	if (g_hPlusHP.IntValue > 0)
		Karyuu_Menu_AddItem(mMenu, _, "hp", "%T [%T]", "Menu_BonusHP", iClient, g_hPlusHP.IntValue, g_bHealthState[iClient] ? "Menu_ON" : "Menu_OFF", iClient);

	if (g_hPlusAR.IntValue > 0)
		Karyuu_Menu_AddItem(mMenu, _, "armor", "%T [%T]", "Menu_BonusArmor", iClient, g_hPlusAR.IntValue, g_bArmorState[iClient] ? "Menu_ON" : "Menu_OFF", iClient);

	Karyuu_Menu_AddItem(mMenu, g_hClanUtils.BoolValue ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED, "clantag", "%T", "Menu_ClanTagEditor", iClient);
	Karyuu_Menu_AddItem(mMenu, g_hChatUtils.BoolValue ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED, "chatmod", "%T", "Menu_ChatMods", iClient);

	if (g_hRainbow.BoolValue)
		Karyuu_Menu_AddItem(mMenu, _, "rainbow", "%T [%T]", "Menu_Rainbow", iClient, g_bRainbowState[iClient] ? "Menu_ON" : "Menu_OFF", iClient);

	Karyuu_Menu_Send(mMenu, iClient);
	return Plugin_Handled;
}

public int menuHandler_VipMenu(Menu mMenu, MenuAction menuAction, int iClient, int iParam)
{
	Karyuu_HandleMenuJunk(mMenu, menuAction);
	switch (menuAction)
	{
		case MenuAction_Select:
		{
			bool bRefresh = false;
			switch (iParam)
			{
				case 0:
				{
					g_bHealthState[iClient] = !g_bHealthState[iClient];
					g_hHealthState.Set(iClient, g_bHealthState[iClient] ? "1" : "0");
					CPrintToChat(iClient, "%s%T %T", g_sPrefix, "Chat_BonusHP", iClient, g_bHealthState[iClient] ? "Chat_Enabled" : "Chat_Disabled", iClient);
					bRefresh = true;
				}
				case 1:
				{
					g_bArmorState[iClient] = !g_bArmorState[iClient];
					g_hArmorState.Set(iClient, g_bArmorState[iClient] ? "1" : "0");
					CPrintToChat(iClient, "%s%T %T", g_sPrefix, "Chat_BonusArmor", iClient, g_bArmorState[iClient] ? "Chat_Enabled" : "Chat_Disabled", iClient);
					bRefresh = true;
				}
				case 2:
				{
					VIP_ClanTag(iClient);
				}
				case 3:
				{
					VIP_NameTagMenu(iClient);
				}
				case 4:
				{
					g_bRainbowState[iClient] = !g_bRainbowState[iClient];
					g_hRainbowState.Set(iClient, g_bRainbowState[iClient] ? "1" : "0");

					CPrintToChat(iClient, "%s%T %T", g_sPrefix, "Chat_Rainbow", iClient, g_bArmorState[iClient] ? "Chat_Enabled" : "Chat_Disabled", iClient);

					if (g_bRainbowState[iClient])
					{
						SDKUnhook(iClient, SDKHook_PreThink, OnPlayerThink);
						SetEntityRenderColor(iClient, 255, 255, 255, 255);
					}
					else
						SDKHook(iClient, SDKHook_PreThink, OnPlayerThink);

					bRefresh = true;
				}
			}

			if (bRefresh)
				cmd_VIP_Menu(iClient, 0);
		}
	}
}

public void VIP_ClanTag(int iClient)
{
	if (!g_hClanUtils.BoolValue)
		return;

	Menu mMenu = CreateMenu(menuHandler_ClanTagMenu);
	Karyuu_Menu_SetTitle(mMenu, "-- Kitsune-VIP > %T --", "Menu_ClanTagEditor", iClient);

	Karyuu_Menu_AddItem(mMenu, _, "edittag", "%T", "Menu_ModifyClanTag", iClient);
	Karyuu_Menu_AddItem(mMenu, Karyuu_IsStringEmpty(g_sClanTag[iClient]) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT, "removetag", "%T", "Menu_ResetClanTag", iClient);

	Karyuu_Menu_Send(mMenu, iClient, true, true);
}

public int menuHandler_ClanTagMenu(Menu mMenu, MenuAction menuAction, int iClient, int iParam)
{
	Karyuu_HandleMenuJunk(mMenu, menuAction);
	switch (menuAction)
	{
		case MenuAction_Select:
		{
			switch (iParam)
			{
				case 0:
				{
					g_iOnTagType[iClient] = 1;
					CPrintToChat(iClient, "%s%T", g_sPrefix, "Chat_TypeClanTag", iClient);
				}
				case 1:
				{
					g_sClanTag[iClient] = NULL_STRING;
					CS_SetClientClanTag(iClient, NULL_STRING);
					g_hVIPClanTag.Set(iClient, NULL_STRING);
					CPrintToChat(iClient, "%s%T", g_sPrefix, "Chat_ClanTagReset", iClient);
				}
			}
		}
		case MenuAction_Cancel:
			cmd_VIP_Menu(iClient, 0);
	}
}

public void VIP_NameTagMenu(int iClient)
{
	if (!g_hChatUtils.BoolValue)
		return;

	Menu mMenu = CreateMenu(menuHandler_NameTagMenu);
	Karyuu_Menu_SetTitle(mMenu, "-- Kitsune-VIP > %T --", "Menu_ChatUtils", iClient);

	Karyuu_Menu_AddItem(mMenu, _, "edittag", "%T", "Menu_ModifyPrefix", iClient);
	Karyuu_Menu_AddItem(mMenu, _, "tagcolor", "%T", "Menu_PrefixColor", iClient);
	Karyuu_Menu_AddItem(mMenu, _, "namecolor", "%T", "Menu_NameColor", iClient);
	Karyuu_Menu_AddItem(mMenu, _, "chatcolor", "%T", "Menu_ChatColor", iClient);
	Karyuu_Menu_AddItem(mMenu, Karyuu_IsStringEmpty(g_sTag[iClient]) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT, "removetag", "%T", "Menu_ResetPrefix", iClient);

	Karyuu_Menu_Send(mMenu, iClient, true, true);
}

public Action OnClientSayCommand(int iClient, const char[] sCommand, const char[] sMessage)
{
	if (!g_hChatUtils.BoolValue || !Karyuu_IsValidClient(iClient) || g_iOnTagType[iClient] == 0)
		return Plugin_Continue;

	if (Karyuu_StrContains(sMessage, "cancel") || Karyuu_StrContains(sMessage, "abort"))
	{
		g_iOnTagType[iClient] = 0;
		CPrintToChat(iClient, "%s%T", g_sPrefix, "Chat_ModifyCancel", iClient);
		return Plugin_Handled;
	}

	switch (g_iOnTagType[iClient])
	{
		case 1:
		{
			g_iOnTagType[iClient] = 0;

			if (Karyuu_IsStringEmpty(sMessage))
			{
				g_sClanTag[iClient] = NULL_STRING;
				CPrintToChat(iClient, "%s%T", g_sPrefix, "Chat_ClanTagReset", iClient);
			}
			else
			{
				strcopy(g_sClanTag[iClient], sizeof(g_sClanTag), sMessage);
				CPrintToChat(iClient, "%s%T", g_sPrefix, "Chat_SetClanTag", iClient, g_sClanTag[iClient]);
			}

			CS_SetClientClanTag(iClient, g_sClanTag[iClient]);
			g_hVIPClanTag.Set(iClient, g_sClanTag[iClient]);
			return Plugin_Handled;
		}
		case 2:
		{
			g_iOnTagType[iClient] = 0;

			if (Karyuu_IsStringEmpty(sMessage))
			{
				g_sTag[iClient] = NULL_STRING;
				CPrintToChat(iClient, "%s%T", g_sPrefix, "Chat_NameTagReset", iClient);
			}
			else
			{
				strcopy(g_sTag[iClient], sizeof(g_sTag), sMessage);
				CPrintToChat(iClient, "%s%T", g_sPrefix, "Chat_SetNameTag", iClient, g_sTag[iClient]);
			}

			ChatProcessor_StripClientTags(iClient);

			if (!Karyuu_IsStringEmpty(g_sTag[iClient]))
				ChatProcessor_AddClientTag(iClient, g_sTag[iClient]);

			g_hVIPTag.Set(iClient, g_sTag[iClient]);
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

public int menuHandler_NameTagMenu(Menu mMenu, MenuAction menuAction, int iClient, int iParam)
{
	Karyuu_HandleMenuJunk(mMenu, menuAction);
	switch (menuAction)
	{
		case MenuAction_Select:
		{
			switch (iParam)
			{
				case 0:
				{
					g_iOnTagType[iClient] = 2;
					CPrintToChat(iClient, "%s%T", g_sPrefix, "Chat_TypeNameTag", iClient);

					VIP_NameTagMenu(iClient);
				}
				case 1, 2, 3:
				{
					VIP_ColorMenu(iClient, iParam);
				}
				case 4:
				{
					g_sTag[iClient] = NULL_STRING;
					g_hVIPTag.Set(iClient, NULL_STRING);

					CPrintToChat(iClient, "%s%T", g_sPrefix, "Chat_NameTagReset", iClient);
				}
			}
		}
	}
}

public void VIP_ColorMenu(int iClient, int iMode)
{
	if (!g_hChatUtils.BoolValue)
		return;

	g_iTagMode[iClient] = iMode;

	Menu mMenu			  = CreateMenu(menuHandler_ColorMenu);
	Karyuu_Menu_SetTitle(mMenu, "-- Kitsune-VIP > %T --", "Menu_ChooseColor", iClient);

	Karyuu_Menu_AddItem(mMenu, _, "{default}", "%T", "Color_Default", iClient);
	Karyuu_Menu_AddItem(mMenu, _, "{red}", "%T", "Color_Red", iClient);
	Karyuu_Menu_AddItem(mMenu, _, "{lightred}", "%T", "Color_Lightred", iClient);
	Karyuu_Menu_AddItem(mMenu, _, "{darkred}", "%T", "Color_Darkred", iClient);
	Karyuu_Menu_AddItem(mMenu, _, "{bluegrey}", "%T", "Color_BlueGray", iClient);
	Karyuu_Menu_AddItem(mMenu, _, "{blue}", "%T", "Color_Blue", iClient);
	Karyuu_Menu_AddItem(mMenu, _, "{darkblue}", "%T", "Color_Darkblue", iClient);
	Karyuu_Menu_AddItem(mMenu, _, "{purple}", "%T", "Color_Purple", iClient);
	Karyuu_Menu_AddItem(mMenu, _, "{orchid}", "%T", "Color_Orchid", iClient);
	Karyuu_Menu_AddItem(mMenu, _, "{yellow}", "%T", "Color_Yellow", iClient);
	Karyuu_Menu_AddItem(mMenu, _, "{gold}", "%T", "Color_Gold", iClient);
	Karyuu_Menu_AddItem(mMenu, _, "{lightgreen}", "%T", "Color_Lightgreen", iClient);
	Karyuu_Menu_AddItem(mMenu, _, "{green}", "%T", "Color_Green", iClient);
	Karyuu_Menu_AddItem(mMenu, _, "{lime}", "%T", "Color_Lime", iClient);
	Karyuu_Menu_AddItem(mMenu, _, "{grey}", "%T", "Color_Lightgrey", iClient);
	Karyuu_Menu_AddItem(mMenu, _, "{grey2}", "%T", "Color_Grey", iClient);

	Karyuu_Menu_Send(mMenu, iClient, true, true);
}

public int menuHandler_ColorMenu(Menu mMenu, MenuAction menuAction, int iClient, int iParam)
{
	Karyuu_HandleMenuJunk(mMenu, menuAction);
	switch (menuAction)
	{
		case MenuAction_Select:
		{
			char sColor[16], sDisplay[32];
			GetMenuItem(mMenu, iParam, STRING(sColor), _, STRING(sDisplay));

			switch (g_iTagMode[iClient])
			{
				case 0:
				{
					g_hVIPTagColor.Set(iClient, sColor);

					ChatProcessor_SetTagColor(iClient, g_sTag[iClient], sColor);

					CPrintToChat(iClient, "%s%T", g_sPrefix, "Chat_SetPrefixColor", iClient, sColor, sDisplay);
				}
				case 1:
				{
					g_hVIPNameColor.Set(iClient, sColor);

					ChatProcessor_SetNameColor(iClient, sColor);

					CPrintToChat(iClient, "%s%T", g_sPrefix, "Chat_SetNameColor", iClient, sColor, sDisplay);
				}
				case 2:
				{
					g_hVIPChatColor.Set(iClient, sColor);

					ChatProcessor_SetChatColor(iClient, sColor);

					CPrintToChat(iClient, "%s%T", g_sPrefix, "Chat_SetTextColor", iClient, sColor, sDisplay);
				}
			}
			VIP_ColorMenu(iClient, g_iTagMode[iClient]);
		}
		case MenuAction_Cancel:
			VIP_NameTagMenu(iClient);
	}
}

public void OnClientPostAdminCheck(int iClient)
{
	if (!Karyuu_IsValidClient(iClient))
		return;

	g_bIsClientVIP[iClient] = Karyuu_ClientHasFlag(iClient, iVipFlag);
}

public void OnClientDisconnect(int iClient)
{
	if (!Karyuu_IsValidClient(iClient) || !g_bIsClientVIP[iClient])
		return;

	g_bIsClientVIP[iClient]	 = false;
	g_bHealthState[iClient]	 = false;
	g_bRainbowState[iClient] = false;
	g_bArmorState[iClient]	 = false;

	g_iOnTagType[iClient]	 = 0;

	g_sTag[iClient]			 = NULL_STRING;
	g_sClanTag[iClient]		 = NULL_STRING;
}

public void OnClientCookiesCached(int iClient)
{
	g_bHealthState[iClient]	 = Karyuu_GetCookieBool(g_hHealthState, iClient);
	g_bRainbowState[iClient] = Karyuu_GetCookieBool(g_hRainbowState, iClient);
	g_bArmorState[iClient]	 = Karyuu_GetCookieBool(g_hArmorState, iClient);

	if (g_hChatUtils.BoolValue)
	{
		ChatProcessor_StripClientTags(iClient);

		g_hVIPTag.Get(iClient, g_sTag[iClient], sizeof(g_sTag[]));

		ChatProcessor_AddClientTag(iClient, g_sTag[iClient]);

		ChatProcessor_SetChatColor(iClient, Karyuu_GetCookieString(g_hVIPNameColor, iClient));
		ChatProcessor_SetNameColor(iClient, Karyuu_GetCookieString(g_hVIPNameColor, iClient));
		ChatProcessor_SetTagColor(iClient, g_sTag[iClient], Karyuu_GetCookieString(g_hVIPNameColor, iClient));
	}

	if (g_hClanUtils.BoolValue)
	{
		g_hVIPClanTag.Get(iClient, g_sClanTag[iClient], sizeof(g_sClanTag[]));
		CS_SetClientClanTag(iClient, g_sClanTag[iClient]);
	}
}

public Action OnPlayerSpawn(Event event, char[] name, bool dontBroadcast)
{
	int iClient = GetClientOfUserId(event.GetInt("userid"));

	if (!Karyuu_IsValidClient(iClient) || !g_bIsClientVIP[iClient])
		return;

	if (g_hPlusHP.IntValue > 0 && g_bHealthState[iClient])
		SetEntityHealth(iClient, GetClientHealth(iClient) + g_hPlusHP.IntValue);

	if (g_hPlusAR.IntValue > 0 && g_bArmorState[iClient])
		SetEntProp(iClient, Prop_Send, "m_ArmorValue", g_hPlusAR.IntValue, 1);

	if (g_hPlusHE.BoolValue)
		SetEntProp(iClient, Prop_Send, "m_bHasHelmet", 1);

	if (!Karyuu_IsStringEmpty(g_sClanTag[iClient]))
		CS_SetClientClanTag(iClient, g_sClanTag[iClient]);

	if (g_hRainbow.BoolValue && g_bRainbowState[iClient])
	{
		SDKHook(iClient, SDKHook_PreThink, OnPlayerThink);
	}
	else
	{
		SDKUnhook(iClient, SDKHook_PreThink, OnPlayerThink);
		SetEntityRenderColor(iClient, 255, 255, 255, 255);
	}
}

public Action OnPlayerThink(int iClient)
{
	if (g_hRainbow.BoolValue && Karyuu_IsClientIndex(iClient) && g_bIsClientVIP[iClient])
	{
		int	iRGBA[3];
		float flRate = 1.0;

		iRGBA[0]		 = RoundToNearest(Cosine((GetGameTime() * flRate) + iClient + 0) * 127.5 + 127.5);
		iRGBA[1]		 = RoundToNearest(Cosine((GetGameTime() * flRate) + iClient + 2) * 127.5 + 127.5);
		iRGBA[2]		 = RoundToNearest(Cosine((GetGameTime() * flRate) + iClient + 4) * 127.5 + 127.5);

		SetEntityRenderMode(iClient, RENDER_GLOW);
		SetEntityRenderColor(iClient, iRGBA[0], iRGBA[1], iRGBA[2], 255);
	}
	else
	{
		g_hRainbowState.Set(iClient, "0");
		g_bRainbowState[iClient] = false;
		SDKUnhook(iClient, SDKHook_PreThink, OnPlayerThink);
	}
}