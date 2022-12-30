/*
 * Copyright (c) 2016-2021 Marco Cawthorne <marco@icculus.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF MIND, USE, DATA OR PROFITS, WHETHER
 * IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING
 * OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

int
CSMultiplayerRules::MaxItemPerSlot(int slot)
{
	/* grenades */
	if (slot == 3) {
		return (3);
	}
	return (1);
}

void
CSMultiplayerRules::PlayerDisconnect(NSClientPlayer pl)
{
	if (health > 0)
		PlayerDeath(pl);
}

void
CSMultiplayerRules::PlayerDeath(NSClientPlayer pl)
{
	player targ = (player)g_dmg_eTarget;
	player attk = (player)g_dmg_eAttacker;

	FX_Corpse_Spawn(targ, ANIM_DEATH1);

	/* obituary networking */
	WriteByte(MSG_MULTICAST, SVC_CGAMEPACKET);
	WriteByte(MSG_MULTICAST, EV_OBITUARY);
	if (g_dmg_eAttacker.netname)
		WriteString(MSG_MULTICAST, strcat(HUD_GetChatColorHEX(g_dmg_eAttacker.team), g_dmg_eAttacker.netname));
	else
		WriteString(MSG_MULTICAST, g_dmg_eAttacker.classname);

	WriteString(MSG_MULTICAST, strcat(HUD_GetChatColorHEX(targ.team), targ.netname));

	WriteByte(MSG_MULTICAST, g_dmg_iWeapon);
	WriteByte(MSG_MULTICAST, 0);
	msg_entity = world;
	multicast([0,0,0], MULTICAST_ALL);

	Plugin_PlayerObituary(g_dmg_eAttacker, g_dmg_eTarget, g_dmg_iWeapon, g_dmg_iHitBody, g_dmg_iDamage);

	/* death-counter */
	targ.deaths++;
	forceinfokey(targ, "*deaths", ftos(targ.deaths));

	/* update score-counter */
	if (g_dmg_eTarget.flags & FL_CLIENT || g_dmg_eTarget.flags & FL_MONSTER)
	if (g_dmg_eAttacker.flags & FL_CLIENT) {
		float vip = (g_dmg_eTarget.team == TEAM_VIP && g_dmg_eAttacker.team == TEAM_CT);

		if (g_dmg_eTarget == g_dmg_eAttacker) {
			g_dmg_eAttacker.frags--;
		} else if (g_dmg_eTarget.team == g_dmg_eAttacker.team || vip) {
			g_dmg_eAttacker.frags--;
			Money_AddMoney((NSClientPlayer)g_dmg_eAttacker, autocvar_fcs_penalty_teamkill);
		} else {
			g_dmg_eAttacker.frags++;
			Money_AddMoney((NSClientPlayer)g_dmg_eAttacker, autocvar_fcs_reward_kill);
		}
	}

	Weapon_DropCurrentWeapon(targ);

	/* if we're the bomb carrier, make sure we drop the bomb. */
	if (targ.g_items & ITEM_C4BOMB) {
		targ.activeweapon = WEAPON_C4BOMB;
		Weapon_DropCurrentWeapon(targ);
	}

	/* clear all ammo and inventory... */
	PlayerClearWeaponry(targ);
	targ.Death();
	targ.gflags &= ~GF_FLASHLIGHT;

	/* gamerule stuff */
	forceinfokey(targ, "*dead", "1"); 
	forceinfokey(targ, "*team", ftos(targ.team));

	pl.think = PutClientInServer;
	pl.nextthink = time + 4.0f;
}

void
CSMultiplayerRules::PlayerPreFrame(NSClientPlayer pl)
{
	super::PlayerPreFrame(pl);
}

void
CSMultiplayerRules::FrameStart(void)
{
	if (cvar("timelimit"))
	if (time >= (cvar("timelimit") * 60)) {
		IntermissionStart();
	}

	IntermissionCycle();
}

void
CSMultiplayerRules::InitPostEnts(void)
{
}

/*
=================
BuyingPossible

Checks if it is possible for players to buy anything
=================
*/
bool
CSMultiplayerRules::BuyingPossible(NSClientPlayer pl)
{
	if (pl.health <= 0) {
		return (false);
	}
	
	return (true);
}

/*
=================
PlayerFindSpawn

Recursive function that gets the next spawnpoint
=================
*/
entity
CSMultiplayerRules::PlayerFindSpawn(float t)
{
	entity point = world;

	if (t == TEAM_T) {
		m_eLastTSpawn = find(m_eLastTSpawn, ::classname, "info_player_deathmatch");
		
		if (m_eLastTSpawn == world) {
			m_eLastTSpawn = find(m_eLastTSpawn, ::classname, "info_player_deathmatch");
		}
		point = m_eLastTSpawn;
	} else if (t == TEAM_CT) {

		// Count how many info_player_start there are
		int count = 0;
		entity LastSpawn = find(world, ::classname, "info_player_start");
		while (LastSpawn != world)
		{
			count++;
			LastSpawn = find(LastSpawn, ::classname, "info_player_start");
		}

		if (count > 1)
		{
			m_eLastCTSpawn = find(m_eLastCTSpawn, ::classname, "info_player_start");
			
			if (m_eLastCTSpawn == world) {
				m_eLastCTSpawn = find(m_eLastCTSpawn, ::classname, "info_player_start");
			}
		}
		else
		{
			m_eLastCTSpawn = find(m_eLastCTSpawn, ::classname, "info_player_deathmatch");
			
			if (m_eLastCTSpawn == world) {
				m_eLastCTSpawn = find(m_eLastCTSpawn, ::classname, "info_player_deathmatch");
			}
		}
		point = m_eLastCTSpawn;
	} else if (t == TEAM_VIP) {
		point = find(world, ::classname, "info_vip_start");
	}

	if (point == world) {
		error("Error: No valid spawnpoints available.");
	}

	return point;
}

/*
=================
PlayerRespawn

Called whenever a player survived a round and needs a basic respawn.
=================
*/
void
CSMultiplayerRules::PlayerRespawn(NSClientPlayer pp, int fTeam)
{
	player pl = (player)pp;

	entity eSpawn;
	forceinfokey(pl, "*spec", "0");
	eSpawn = PlayerFindSpawn(pl.team);

	pl.classname = "player";
	pl.health = pl.max_health = 100;
	forceinfokey(pl, "*dead", "0");

	pl.takedamage = DAMAGE_YES;
	pl.solid = SOLID_SLIDEBOX;
	pl.movetype = MOVETYPE_WALK;
	pl.flags = FL_CLIENT;
	pl.iBleeds = TRUE;
	pl.viewzoom = 1.0;
	pl.g_items &= ~ITEM_C4BOMB;

	pl.SetOrigin(eSpawn.origin);
	pl.angles = eSpawn.angles;
	pl.SendFlags = UPDATE_ALL;
	Client_FixAngle(pl, pl.angles);

	switch (pl.charmodel) {
	case 1:
		pl.model = "models/player/terror/terror.mdl";
		break;
	case 2:
		pl.model = "models/player/leet/leet.mdl";
		break;
	case 3:
		pl.model = "models/player/arctic/arctic.mdl";
		break;
	case 4:
		pl.model = "models/player/guerilla/guerilla.mdl";
		break;
	case 5:
		pl.model = "models/player/urban/urban.mdl";
		break;
	case 6:
		pl.model = "models/player/gsg9/gsg9.mdl";
		break;
	case 7:
		pl.model = "models/player/sas/sas.mdl";
		break;
	case 8:
		pl.model = "models/player/gign/gign.mdl";
		break;
	default:
		pl.model = "models/player/vip/vip.mdl";
	}

	pl.SetModel(pl.model);
	pl.SetSize(VEC_HULL_MIN, VEC_HULL_MAX);

	pl.velocity = [0,0,0];
	pl.progress = 0.0f;
	Weapons_SwitchBest(pl);
	Ammo_AutoFill(pl);
}

void
CSMultiplayerRules::PlayerClearWeaponry(NSClientPlayer pp)
{
	player pl = (player)pp;

	pl.g_items = 0x0;
	pl.activeweapon = 0;
	pl.ammo_50ae = 0;
	pl.ammo_762mm = 0;
	pl.ammo_556mm = 0;
	pl.ammo_556mmbox = 0;
	pl.ammo_338mag = 0;
	pl.ammo_9mm = 0;
	pl.ammo_buckshot = 0;
	pl.ammo_45acp = 0;
	pl.ammo_357sig = 0;
	pl.ammo_57mm = 0;
	pl.ammo_hegrenade = 0;
	pl.ammo_fbgrenade = 0;
	pl.ammo_smokegrenade = 0;
	pl.usp45_mag = 0;
	pl.glock18_mag = 0;
	pl.deagle_mag = 0;
	pl.p228_mag = 0;
	pl.elites_mag = 0;
	pl.fiveseven_mag = 0;
	pl.m3_mag = 0;
	pl.xm1014_mag = 0;
	pl.mp5_mag = 0;
	pl.p90_mag = 0;
	pl.ump45_mag = 0;
	pl.mac10_mag = 0;
	pl.tmp_mag = 0;
	pl.ak47_mag = 0;
	pl.sg552_mag = 0;
	pl.m4a1_mag = 0;
	pl.aug_mag = 0;
	pl.scout_mag = 0;
	pl.awp_mag = 0;
	pl.g3sg1_mag = 0;
	pl.sg550_mag = 0;
	pl.para_mag = 0;
	pl.viewzoom = 1.0f;
	pl.mode_temp = 0;
}

/*
=================
PlayerSpawn

Called on the client first joining the server.
=================
*/

void
CSMultiplayerRules::PlayerSpawn(NSClientPlayer pp)
{
	player pl = (player)pp;

	if (infokey(pl, "*team") == "1" || infokey(pl, "*team") == "2")
	{
		pl.g_items |= ITEM_SUIT;
		Weapons_AddItem(pl, WEAPON_KNIFE, -1);

		/* terrorists */
		if (infokey(pl, "*team") == "1") {
			pl.team = TEAM_T;
			if (autocvar_fcs_knifeonly == FALSE) {
				Weapons_AddItem(pl, WEAPON_GLOCK18, -1);
				pl.ammo_9mm = 40;
			}
		} else if (infokey(pl, "*team") == "2") {
			pl.team = TEAM_CT;
			if (autocvar_fcs_knifeonly == FALSE) {
				Weapons_AddItem(pl, WEAPON_USP45, -1);
				pl.ammo_45acp = 24;
			}
		}

		pl.ingame = TRUE;
		forceinfokey(pl, "*team", ftos(pl.team)); 
		PlayerRespawn(pl, pl.team);
	}
	else
	{
		/* immediately put us into spectating mode */
		PlayerMakeSpectator(pl);
		Spawn_ObserverCam(pl);

		/* give the initial server-joining money */
		// todo: bug here? do we give the player money every time they switch?
		Money_AddMoney(pl, autocvar_mp_startmoney);

		/* we don't belong to any team */
		pl.team = TEAM_SPECTATOR;
		forceinfokey(pl, "*team", "0"); 
	}
}

/*
=================
PlayerMakeSpectator

Force the player to become an observer.
=================
*/
void
CSMultiplayerRules::PlayerMakeSpectator(NSClientPlayer pp)
{
	player pl = (player)pp;
	pl.MakeTempSpectator();
	PlayerClearWeaponry(pl);
}

void
CSMultiplayerRules_BotJoin(void)
{
	spawnfunc_csbot();
	CSEv_JoinAuto();
}

bool
CSMultiplayerRules::ConsoleCommand(NSClientPlayer pp, string cmd)
{
	tokenize(cmd);

	switch (argv(0)) {
	case "bot_add":
		entity bot_ent = Bot_AddQuick();
		if (bot_ent) {
			bot_ent.think = CSMultiplayerRules_BotJoin;
			bot_ent.nextthink = time;
		}
		break;
	default:
		return (false);
	}

	return (true);
}

bool
CSMultiplayerRules::IsTeamplay(void)
{
	return true;
}

void
CSMultiplayerRules::CSMultiplayerRules(void)
{
	forceinfokey(world, "teams", "2");
	forceinfokey(world, "team_1", "Terrorist");
	forceinfokey(world, "team_2", "Counter-Terrorist");
}

/*
=================
CSEv_JoinTeam_f

Event Handling, called by the Client codebase via 'sendevent'
=================
*/
void
CSEv_JoinTeam_f(float flChar)
{
	CSMultiplayerRules rules;
	player pl;

	/* matches Game_InitRules() */
	if (cvar("sv_playerslots") == 1 || cvar("coop") == 1) {
		return;
	}

	rules = (CSMultiplayerRules)g_grMode;
	pl = (player)self;

	// alive and are trying to switch teams, so subtract us from the Alive_Team counter.
	if (pl.health > 0) {
		rules.PlayerKill(pl);
	}

	pl.charmodel = (int)flChar;

	if (flChar < 5)
		pl.team = TEAM_T;
	else
		pl.team = TEAM_CT;

	forceinfokey(pl, "*team", ftos(pl.team)); 

	pl.frags = 0;
	pl.deaths = 0;
	forceinfokey(pl, "*deaths", ftos(pl.deaths));

	rules.PlayerSpawn(pl);
}

void
CSEv_JoinAuto(void)
{
	CSMultiplayerRules rules;

	/* matches Game_InitRules() */
	if (cvar("sv_playerslots") == 1 || cvar("coop") == 1) {
		return;
	}

	rules = (CSMultiplayerRules)g_grMode;

	if (g_cs_total_ct >= g_cs_total_t) {
		CSEv_JoinTeam_f(floor(random(1,5)));
	} else {
		CSEv_JoinTeam_f(floor(random(5,9)));
	}
}
