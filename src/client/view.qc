/*
 * Copyright (c) 2016-2020 Marco Cawthorne <marco@icculus.org>
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

void
View_UpdateWeapon(player pl, entity vm, entity mflash)
{
	/* only bother upon change */
	if (pSeat->m_iLastWeapon == pl.activeweapon) {
		return;
	}
	pSeat->m_iOldWeapon = pSeat->m_iLastWeapon;
	pSeat->m_iLastWeapon = pl.activeweapon;

	if (!pl.activeweapon) {
		return;
	}

	/* we forced a weapon call outside the prediction,
	 * thus we need to update all the net variables to
	 * make sure these updates are recognized. this is
	 * vile but it'll have to do for now */
	SAVE_STATE(pl.w_attack_next);
	SAVE_STATE(pl.w_idle_next);
	SAVE_STATE(pl.viewzoom);
	SAVE_STATE(pl.weapontime);
	SAVE_STATE(pl.weaponframe);

	/* hack, we changed the wep, move this into Game_Input/PMove */
	Weapons_Draw(pl);

	/* we forced a weapon call outside the prediction,
	 * thus we need to update all the net variables to
	 * make sure these updates are recognized. this is
	 * vile but it'll have to do for now */
	ROLL_BACK(pl.w_attack_next);
	ROLL_BACK(pl.w_idle_next);
	ROLL_BACK(pl.viewzoom);
	ROLL_BACK(pl.weapontime);
	ROLL_BACK(pl.weaponframe);

	/* figure out when the attachments start. in FTE attachments for
	 * HLMDL are treated as bones. they start at numbones + 1 */
	skel_delete(mflash.skeletonindex);
	mflash.skeletonindex = skel_create(vm.modelindex);
	pSeat->m_iVMBones = skel_get_numbones(mflash.skeletonindex) + 1;

	if (getplayerkeyfloat(pl.entnum-1, "*team") == TEAM_CT) {
		setcustomskin(pSeat->m_eViewModel, "", "geomset 0 2\ngeomset 1 1\n");
	} else {
		setcustomskin(pSeat->m_eViewModel, "", "geomset 0 1\ngeomset 1 2\n");
	}
}
