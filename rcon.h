/*
 * rcon.h - part of the rcon module
 */
/*
 * Copyright (C) 2001 proton
 * Copyright (C) 2001, 2002 Eggheads Development Team
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 */

#ifndef _EGG_MOD_RCON_RCON_H
#define _EGG_MOD_RCON_RCON_H

// Default rcon listen port (changed in eggdrop.conf)
static int rcon_listen_port = 43456;

// buffer size for UDP recv's
const int RCON_BUFFER_SIZE = 65536;

#endif /* _EGG_MOD_RCON_RCON_H */
