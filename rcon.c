/*
 * This module provides two TCL procedures to eggdrop: challengercon and rcon.
 *
 * challengercon syntax:
 *   challengercon hostname port
 * returns a challenge number from the specified HL server at port
 *
 * rcon syntax:
 *   rcon hostname port challengenumber password command
 * returns the output of "command"
 *
 * Version 1.4
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

#define MODULE_NAME "rcon"
#define MAKING_RCON
#include "rcon.h" 
#include "../module.h"
#include <netdb.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>

static Function *global = NULL;

int totalexpmem=0;

//char *rconbuffer;
//static int rconsock;
static int rconlistensock;
static p_tcl_bind_list H_rcon;
//static int rcon_listen_port = 43456;
//const int RCON_BUFFER_SIZE = 4096;

static int rcon_expmem() {
  return totalexpmem;
}

static void rcon_report(int idx, int details)
{
  if (details) {
    dprintf(idx, "   using %d bytes\n", rcon_expmem());
    dprintf(idx, "   listening on port: %d\n", rcon_listen_port);
  }
}

static unsigned long my_get_ip(char* rcon_host)
{
  struct hostent *hp;
  IP ip;  
  struct in_addr *in;
    
  /* could be pre-defined */
  if (rcon_host[0]) {
    if ((rcon_host[strlen(rcon_host) - 1] >= '0') && (rcon_host[strlen(rcon_host) - 1] <= '9')) {
        return (IP) inet_addr(rcon_host);    
    }
  }  

  hp = gethostbyname(rcon_host);
  if (hp == NULL) {
    return -1;
  }
  in = (struct in_addr *) (hp->h_addr_list[0]);
  ip = (IP) (in->s_addr);
  return ip;
}       
/*
int init_rcon(void)
{
  struct  sockaddr_in sai;

  if ((rconsock = socket(AF_INET, SOCK_DGRAM, 0)) < 0) {
    putlog(LOG_DEBUG, "*", "init_rcon socket returned < 0 %d",rconsock);
    return((rconsock = -1));
  }
  memset(&sai, 0, sizeof(sai));
  sai.sin_addr.s_addr = INADDR_ANY;
  sai.sin_family = AF_INET;
  if (bind(rconsock, (struct sockaddr*)&sai, sizeof(sai)) < 0) {
    close(rconsock);
    return((rconsock = -1));
  }
  fcntl(rconsock, F_SETFL, O_NONBLOCK | fcntl(rconsock, F_GETFL));

  return(0);
}
*/

static int init_rcon_sock(void)
{
  struct  sockaddr_in sai;
  int rconsock;

  if ((rconsock = socket(AF_INET, SOCK_DGRAM, 0)) < 0) {
    putlog(LOG_DEBUG, "*", "init_rcon socket returned < 0 %d",rconsock);
    return((rconsock = -1));
  }
  memset(&sai, 0, sizeof(sai));
  sai.sin_addr.s_addr = INADDR_ANY;
  sai.sin_family = AF_INET;
  if (bind(rconsock, (struct sockaddr*)&sai, sizeof(sai)) < 0) {
    putlog(LOG_DEBUG, "*", "bind rconsock failed");
    return((rconsock = -2));
  }
  fcntl(rconsock, F_SETFL, O_NONBLOCK | fcntl(rconsock, F_GETFL));

  return(rconsock);
}

static int init_rcon_listen() {
  struct  sockaddr_in sai;

  if ((rconlistensock = socket(AF_INET, SOCK_DGRAM, 0)) < 0) {
    putlog(LOG_MISC, "*", "init_rcon_listen socket returned < 0 %d",rconlistensock);
    return((rconlistensock = -1));
  }
  (void) allocsock(rconlistensock, SOCK_PASS);

  memset(&sai, 0, sizeof(sai));
  sai.sin_family = AF_INET;
  sai.sin_addr.s_addr = htonl(INADDR_ANY);
  sai.sin_port = htons(rcon_listen_port);

  if (bind(rconlistensock, (struct sockaddr*)&sai, sizeof(sai)) < 0) {
    close(rconlistensock);
    return((rconlistensock = -1));
  }
  fcntl(rconlistensock, F_SETFL, O_NONBLOCK | fcntl(rconlistensock, F_GETFL));

  return 1;
}

static int tcl_challengercon STDVAR
{
  struct sockaddr_in sai;
  const char CHALLENGERCON[] = { "����challenge rcon" };
  struct timeval timeout;
  char *buffer = NULL;
  int front, numbytes;
  fd_set hl_sockets;
  unsigned long rconip;
  int rconport;
  char challenge_number[40]="";
  char challenge_number_temp[40]="";
  int rconsock = init_rcon_sock();

  BADARGS(3, 3, " server port");
  rconip = my_get_ip(argv[1]);
  rconport = atoi(argv[2]);


//  debug1("rcon sock: %d", rconsock);

  memset(&sai, 0, sizeof(sai));
  sai.sin_family = AF_INET;
  sai.sin_addr.s_addr = rconip;
  sai.sin_port = htons(rconport);
//  debug2("ip: %D | port: %d", rconip, rconport);

  sendto(rconsock, CHALLENGERCON, strlen(CHALLENGERCON), 0, (struct sockaddr*)&sai, sizeof(sai));

  FD_ZERO(&hl_sockets);
  FD_SET(rconsock,&hl_sockets);
  timeout.tv_sec = 10;
  timeout.tv_usec = 0;

  front = select(FD_SETSIZE,&hl_sockets,NULL,NULL,&timeout);
  if (front < 1) {
     putlog(LOG_MISC, "*", "rconerror: Server not responding (timeout) %d", front);
     Tcl_AppendResult(irp, "-1", NULL);
     return TCL_OK;
  }

        buffer = (char *) nmalloc(RCON_BUFFER_SIZE);
	totalexpmem += RCON_BUFFER_SIZE;
        egg_bzero(buffer, RCON_BUFFER_SIZE);

        numbytes = recv(rconsock, (char *)buffer, RCON_BUFFER_SIZE-1,0);
        if (numbytes == -1) {
                putlog(LOG_MISC, "*", "rconerror: Server not responding");
	        Tcl_AppendResult(irp, "-2", NULL);
		if (buffer) {
			totalexpmem -= RCON_BUFFER_SIZE;
		        nfree(buffer);
			buffer = NULL;
		}
                return TCL_OK;
        }
//  debug2("numbytes: %d | challenge reply: %s", numbytes, buffer);

  strlcpy(challenge_number, buffer, sizeof(challenge_number));
  splitc(challenge_number_temp, challenge_number, ' ');
  splitc(challenge_number_temp, challenge_number, ' ');
  challenge_number[strlen(challenge_number)-1] = '\0';

//  debug1("challenge reply out: %s", challenge_number);

//  challenge_number = buffer[19];
  Tcl_AppendResult(irp, challenge_number, NULL);
  if (buffer) {
    totalexpmem -= RCON_BUFFER_SIZE;
    nfree(buffer);
    buffer = NULL;
  }

  close(rconsock);
  return TCL_OK;
}

static int tcl_sendrcon STDVAR
{
  struct sockaddr_in sai;
  const char RCONSTR[] = { "����rcon" };
  struct timeval timeout;
  char *buffer = NULL;
  int front, numbytes;
  fd_set hl_sockets;
  unsigned long rconip;
  int rconport;
  char *cmd = NULL;
  char *newbuffer = NULL;
  int cmdsize;
  int rconsock = init_rcon_sock();

  BADARGS(6, 6, " server port challenge password cmd");
  rconip = my_get_ip(argv[1]);
  rconport = atoi(argv[2]);
  cmdsize = strlen(RCONSTR) + 1 + strlen(argv[3]) + 1 + strlen(argv[4])+2 + 1
            + strlen(argv[5]) + 1;

  cmd = (char *) nmalloc(cmdsize);
  totalexpmem += cmdsize;
  egg_bzero(cmd, cmdsize);  

  sprintf(cmd, "%s %s \"%s\" %s", RCONSTR, argv[3], argv[4], argv[5]);

//  debug3("cmdsize: %d | strlen(cmdsize): %d | cmd: %s", cmdsize, strlen(cmd), cmd);
  memset(&sai, 0, sizeof(sai));
  sai.sin_family = AF_INET;
  sai.sin_addr.s_addr = rconip;
  sai.sin_port = htons(rconport);
  sendto(rconsock, cmd, strlen(cmd), 0, (struct sockaddr*)&sai, sizeof(sai));
  if (cmd) {
    totalexpmem -= cmdsize;
    nfree(cmd);
    cmd = NULL;
  }

  FD_ZERO(&hl_sockets);
  FD_SET(rconsock,&hl_sockets);
  timeout.tv_sec = 6;
  timeout.tv_usec = 0;
             
  front = select(FD_SETSIZE,&hl_sockets,NULL,NULL,&timeout);
  if (front < 1) {
     putlog(LOG_MISC, "*", "rconerror: Server not responding");
     Tcl_AppendResult(irp, "-1", NULL);
     return TCL_OK;
  }

  buffer = (char *) nmalloc(RCON_BUFFER_SIZE);
  totalexpmem += RCON_BUFFER_SIZE;
  egg_bzero(buffer, RCON_BUFFER_SIZE);
  numbytes = recv(rconsock, buffer, RCON_BUFFER_SIZE-1,0);

//  egg_bzero(rconbuffer, RCON_BUFFER_SIZE);
//  Context;
//  numbytes = recv(rconsock, rconbuffer, RCON_BUFFER_SIZE-1,0);

  if (numbytes == -1) {
      putlog(LOG_MISC, "*", "rconerror: Server not responding");
      Tcl_AppendResult(irp, "-2", NULL);
      if (buffer) {
        totalexpmem -= RCON_BUFFER_SIZE;
        nfree(buffer);
        buffer = NULL;
      }

      return TCL_OK;
  }
//  ContextNote(rconbuffer);

  if (numbytes > 4) {  // strip off ����l shit
    newbuffer = buffer + 5;
  } else {
    newbuffer = buffer;
  }

//  debug3("numbytes: %d | buffer: %d | newbuffer: %d", numbytes, strlen(rconbuffer), strlen(newbuffer));
  Tcl_AppendResult(irp, newbuffer, NULL);


  newbuffer = NULL;


  if (buffer) {
    totalexpmem -= RCON_BUFFER_SIZE;
    nfree(buffer);
    buffer = NULL;
  }

  close(rconsock);

  return TCL_OK;
}

static void check_tcl_rcon(char *msg)
{
  Tcl_SetVar(interp, "_rcon1", msg, 0);
  check_tcl_bind(H_rcon, msg, 0, " $_rcon1", MATCH_MASK | BIND_STACKABLE);
}


static void eof_rcon_socket(int idx)
{ 
  putlog(LOG_MISC, "*", "RCON Error: socket closed.");
  killsock(dcc[idx].sock);
  /* Try to reopen socket */
  if (init_rcon_listen()) {
    putlog(LOG_MISC, "*", "RCON socket successfully reopened!");
    dcc[idx].sock = rconlistensock;
    dcc[idx].timeval = now;
  } else
    lostdcc(idx);
} 


static void rcon_socket(int idx, char *buf, int len)
{
  char *buffer = NULL;
  int actualsize;
  struct sockaddr_in from;
  socklen_t fromlen = sizeof(from);
  char src_tag[64];

  buffer = (char *) nmalloc(RCON_BUFFER_SIZE);
  totalexpmem += RCON_BUFFER_SIZE;
  actualsize = recvfrom(rconlistensock, buffer, RCON_BUFFER_SIZE, 0,
                         (struct sockaddr *)&from, &fromlen);

  if (actualsize >= 6) {
    char *tagged;
    int taglen;

    buffer[actualsize-2] = '\0';
    snprintf(src_tag, sizeof(src_tag), "%s:%d ",
             inet_ntoa(from.sin_addr), ntohs(from.sin_port));
    taglen = strlen(src_tag) + strlen(buffer + 4) + 1;
    tagged = (char *) nmalloc(taglen);
    totalexpmem += taglen;
    strcpy(tagged, src_tag);
    strcat(tagged, buffer + 4);

    check_tcl_rcon(tagged);

    totalexpmem -= taglen;
    nfree(tagged);
  }

  if (buffer) {
    totalexpmem -= RCON_BUFFER_SIZE;
    nfree(buffer);
  }

}

static void display_rcon_socket(int idx, char *buf)
{
  strcpy(buf, "rcon   (ready)");
}

static struct dcc_table DCC_RCON =
{
  "RCON",
  DCT_LISTEN,
  eof_rcon_socket,
  rcon_socket,
  NULL,
  NULL,
  display_rcon_socket,
  NULL,
  NULL,
  NULL
};

static int rcon_1char STDVAR
{
  Function F = (Function) cd;
 
  BADARGS(2, 2, " msg");
  CHECKVALIDITY(rcon_1char);
  F(argv[1]);
  return TCL_OK;
}

static tcl_cmds mytcls[] =
{ 
  {"challengercon",     tcl_challengercon},
  {"rcon",              tcl_sendrcon},
  {NULL,                NULL} 
};

static tcl_ints myints[] =
{
  {"rcon-listen-port",  &rcon_listen_port,   0},
  {NULL,                NULL,                0}
};


static void rcon_rehash() {
  int i, idx;

  for (i = 0; i < dcc_total; i++) {
    if (dcc[i].type == &DCC_RCON) {
      killsock(dcc[i].sock);
      lostdcc(i);
      break;
    }
  }

    idx = new_dcc(&DCC_RCON, 0);
//    if (idx < 0)
//      return "NO MORE DCC CONNECTIONS -- Can't create RCON socket.";

    if (!init_rcon_listen()) {
      lostdcc(idx);
//      return "RCON initialization failed.";
    } else {

    dcc[idx].sock = rconlistensock;
    dcc[idx].timeval = now;
 
    strcpy(dcc[idx].nick, "(rcon)");
    }
}

EXPORT_SCOPE char *rcon_start(Function *);

static char *rcon_close()
{
  int i;

  for (i = 0; i < dcc_total; i++) {
    if (dcc[i].type == &DCC_RCON &&
        dcc[i].sock == rconlistensock) {
      killsock(dcc[i].sock);
      lostdcc(i);
      break;
    }
  }
/*
  if (rconbuffer) {
    totalexpmem -= RCON_BUFFER_SIZE;
    nfree(rconbuffer);
    rconbuffer = NULL;
  }
*/
//  close(rconsock);
  close(rconlistensock);

  del_bind_table(H_rcon);
  del_hook(HOOK_REHASH, (Function) rcon_rehash);
  rem_tcl_commands(mytcls);
  rem_tcl_ints(myints);
  module_undepend(MODULE_NAME);
  return NULL;
}


static Function rcon_table[] =
{
  (Function) rcon_start,
  (Function) rcon_close,
  (Function) rcon_expmem,
  (Function) rcon_report,
  (Function) & H_rcon,
};

char *rcon_start(Function * global_funcs)
{
  int idx;

  if (global_funcs) {
    global = global_funcs;

    module_register(MODULE_NAME, rcon_table, 1, 4);
    if (!module_depend(MODULE_NAME, "eggdrop", 108, 4)) {
      module_undepend(MODULE_NAME);
      return "This module requires Eggdrop 1.8.4 or later.";
    }

//    init_rcon();
//    rconbuffer = (char *) nmalloc(RCON_BUFFER_SIZE);
//    totalexpmem += RCON_BUFFER_SIZE;

    add_tcl_commands(mytcls);
    add_tcl_ints(myints);
    H_rcon = add_bind_table("rcon", HT_STACKABLE, rcon_1char);
    add_hook(HOOK_REHASH, (Function) rcon_rehash);

    idx = new_dcc(&DCC_RCON, 0);
    if (idx < 0)
      return "NO MORE DCC CONNECTIONS -- Can't create RCON socket.";

    if (!init_rcon_listen()) {
      lostdcc(idx);
      return "RCON initialization failed.";
    }

    dcc[idx].sock = rconlistensock;
    dcc[idx].timeval = now;
 
    strcpy(dcc[idx].nick, "(rcon)");

  }  
  return NULL;
}


