/*
 * sciDatabase — Redis native transport (hiredis), Scilab 2027 / macOS arm64. Key-value paradigm.
 *   id  = db_redis_connect(host, port)
 *   out = db_redis_command(id, argv)   // argv = string vector ["SET","k","v"]; returns the reply:
 *                                      //   string/status -> string; integer -> double; nil -> [];
 *                                      //   array -> string column; error -> raised
 *         db_redis_close(id)
 * Native (no JVM) — works in every Scilab binary incl. scilab-cli.
 */
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include "api_scilab.h"
#include "Scierror.h"
#include "sci_malloc.h"
#include "localization.h"
#include <hiredis/hiredis.h>

#define DB_MAXRE 64
static redisContext* g_re[DB_MAXRE] = {0};

static int re_get_string(void* pvApiCtx, int pos, char** out)
{
    int* piAddr = NULL;
    SciErr se = getVarAddressFromPosition(pvApiCtx, pos, &piAddr);
    if (se.iErr) { printError(&se, 0); return 1; }
    if (!isStringType(pvApiCtx, piAddr) || !isScalar(pvApiCtx, piAddr)) return 1;
    if (getAllocatedSingleString(pvApiCtx, piAddr, out) != 0) return 1;
    return 0;
}
static int re_get_double(void* pvApiCtx, int pos, double* out)
{
    int* piAddr = NULL;
    SciErr se = getVarAddressFromPosition(pvApiCtx, pos, &piAddr);
    if (se.iErr) { printError(&se, 0); return 1; }
    if (getScalarDouble(pvApiCtx, piAddr, out) != 0) return 1;
    return 0;
}

int sci_db_redis_connect(char* fname, void* pvApiCtx)
{
    char* host = NULL; double dport = 0.0; int slot = -1, i; redisContext* c = NULL;
    CheckInputArgument(pvApiCtx, 2, 2);   /* host, port */
    CheckOutputArgument(pvApiCtx, 1, 1);
    if (re_get_string(pvApiCtx, 1, &host) || re_get_double(pvApiCtx, 2, &dport)) {
        Scierror(999, _("%s: expected (host, port).\n"), fname); return 0;
    }
    for (i = 0; i < DB_MAXRE; i++) if (g_re[i] == NULL) { slot = i; break; }
    if (slot < 0) { freeAllocatedSingleString(host); Scierror(999, _("%s: too many open connections.\n"), fname); return 0; }
    c = redisConnect(host, (int)dport);
    freeAllocatedSingleString(host);
    if (c == NULL || c->err) {
        char msg[1024]; snprintf(msg, sizeof(msg), "%s", c ? c->errstr : "allocation error");
        if (c) redisFree(c);
        Scierror(999, _("%s: connection failed: %s\n"), fname, msg); return 0;
    }
    g_re[slot] = c;
    createScalarDouble(pvApiCtx, nbInputArgument(pvApiCtx) + 1, (double)(slot + 1));
    AssignOutputVariable(pvApiCtx, 1) = nbInputArgument(pvApiCtx) + 1;
    ReturnArguments(pvApiCtx);
    return 0;
}

static void redis_emit_reply(void* pvApiCtx, redisReply* r, int outpos)
{
    if (r == NULL) { createEmptyMatrix(pvApiCtx, outpos); return; }
    switch (r->type) {
        case REDIS_REPLY_STRING:
        case REDIS_REPLY_STATUS: {
            char* s = r->str ? r->str : (char*)"";
            createMatrixOfString(pvApiCtx, outpos, 1, 1, &s);
            break;
        }
        case REDIS_REPLY_INTEGER:
            createScalarDouble(pvApiCtx, outpos, (double)r->integer);
            break;
        case REDIS_REPLY_NIL:
            createEmptyMatrix(pvApiCtx, outpos);
            break;
        case REDIS_REPLY_ARRAY: {
            size_t n = r->elements, k;
            char** arr = (char**)malloc(sizeof(char*) * (n > 0 ? n : 1));
            char** tofree = (char**)malloc(sizeof(char*) * (n > 0 ? n : 1));
            for (k = 0; k < n; k++) {
                redisReply* e = r->element[k];
                tofree[k] = NULL;
                if (e == NULL || e->type == REDIS_REPLY_NIL) { arr[k] = (char*)""; }
                else if (e->type == REDIS_REPLY_INTEGER) {
                    char buf[32]; snprintf(buf, sizeof(buf), "%lld", (long long)e->integer);
                    arr[k] = tofree[k] = strdup(buf);
                } else { arr[k] = e->str ? e->str : (char*)""; }
            }
            createMatrixOfString(pvApiCtx, outpos, (int)n, (n > 0) ? 1 : 0, arr);
            for (k = 0; k < n; k++) if (tofree[k]) free(tofree[k]);
            free(arr); free(tofree);
            break;
        }
        default:
            createEmptyMatrix(pvApiCtx, outpos);
    }
}

int sci_db_redis_command(char* fname, void* pvApiCtx)
{
    double did = 0.0; int slot, m, n, i; int* piAddr = NULL;
    char** words = NULL; const char** argv = NULL; size_t* argvlen = NULL;
    redisContext* c = NULL; redisReply* r = NULL; SciErr se;
    CheckInputArgument(pvApiCtx, 2, 2);   /* id, argv (string vector) */
    CheckOutputArgument(pvApiCtx, 1, 1);
    if (re_get_double(pvApiCtx, 1, &did)) { Scierror(999, _("%s: first argument must be a connection id.\n"), fname); return 0; }
    slot = (int)did - 1;
    if (slot < 0 || slot >= DB_MAXRE || g_re[slot] == NULL) { Scierror(999, _("%s: invalid or closed connection id.\n"), fname); return 0; }
    c = g_re[slot];
    se = getVarAddressFromPosition(pvApiCtx, 2, &piAddr);
    if (se.iErr || !isStringType(pvApiCtx, piAddr)) { Scierror(999, _("%s: second argument must be a string vector (command words).\n"), fname); return 0; }
    if (getAllocatedMatrixOfString(pvApiCtx, piAddr, &m, &n, &words) != 0) { Scierror(999, _("%s: cannot read command words.\n"), fname); return 0; }
    {
        int nw = m * n;
        if (nw < 1) { freeAllocatedMatrixOfString(m, n, words); Scierror(999, _("%s: empty command.\n"), fname); return 0; }
        argv = (const char**)malloc(sizeof(char*) * nw);
        argvlen = (size_t*)malloc(sizeof(size_t) * nw);
        for (i = 0; i < nw; i++) { argv[i] = words[i]; argvlen[i] = strlen(words[i]); }
        r = redisCommandArgv(c, nw, argv, argvlen);
        free(argv); free(argvlen);
    }
    freeAllocatedMatrixOfString(m, n, words);
    if (r == NULL) { Scierror(999, _("%s: command failed: %s\n"), fname, c->errstr); return 0; }
    if (r->type == REDIS_REPLY_ERROR) {
        char msg[1024]; snprintf(msg, sizeof(msg), "%s", r->str ? r->str : "error");
        freeReplyObject(r);
        Scierror(999, _("%s: %s\n"), fname, msg); return 0;
    }
    redis_emit_reply(pvApiCtx, r, nbInputArgument(pvApiCtx) + 1);
    freeReplyObject(r);
    AssignOutputVariable(pvApiCtx, 1) = nbInputArgument(pvApiCtx) + 1;
    ReturnArguments(pvApiCtx);
    return 0;
}

int sci_db_redis_close(char* fname, void* pvApiCtx)
{
    double did = 0.0; int slot;
    CheckInputArgument(pvApiCtx, 1, 1);
    CheckOutputArgument(pvApiCtx, 0, 1);
    if (re_get_double(pvApiCtx, 1, &did)) { Scierror(999, _("%s: argument must be a connection id.\n"), fname); return 0; }
    slot = (int)did - 1;
    if (slot >= 0 && slot < DB_MAXRE && g_re[slot] != NULL) { redisFree(g_re[slot]); g_re[slot] = NULL; }
    AssignOutputVariable(pvApiCtx, 1) = 0;
    ReturnArguments(pvApiCtx);
    return 0;
}
