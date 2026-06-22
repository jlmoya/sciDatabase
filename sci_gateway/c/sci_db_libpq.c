/*
 * sciDatabase — libpq (PostgreSQL) native transport for Scilab 2027 / macOS arm64.
 *
 * Exposes three Scilab primitives used by the postgresql_libpq_* driver macros:
 *   id          = db_libpq_connect(connstr)        // PQconnectdb; returns a handle id
 *   [rc,data,cols] = db_libpq_exec(id, sql)        // PQexec; SELECT -> (nrows, nr*nc strings, 1*nc names)
 *                                                  //         DML   -> (affected, [], [])
 *                  db_libpq_close(id)              // PQfinish
 *
 * Works in every Scilab binary including the no-JVM scilab-cli (no Java dependency).
 */
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include "api_scilab.h"
#include "Scierror.h"
#include "sci_malloc.h"
#include "localization.h"
#include <libpq-fe.h>

#define DB_MAXCONN 64
static PGconn* g_conns[DB_MAXCONN] = {0};

/* read one allocated string from input position; caller frees with freeAllocatedSingleString */
static int db_get_string(void* pvApiCtx, int pos, char** out)
{
    int* piAddr = NULL;
    SciErr se = getVarAddressFromPosition(pvApiCtx, pos, &piAddr);
    if (se.iErr) { printError(&se, 0); return 1; }
    if (!isStringType(pvApiCtx, piAddr) || !isScalar(pvApiCtx, piAddr)) return 1;
    if (getAllocatedSingleString(pvApiCtx, piAddr, out) != 0) return 1;
    return 0;
}

static int db_get_double(void* pvApiCtx, int pos, double* out)
{
    int* piAddr = NULL;
    SciErr se = getVarAddressFromPosition(pvApiCtx, pos, &piAddr);
    if (se.iErr) { printError(&se, 0); return 1; }
    if (getScalarDouble(pvApiCtx, piAddr, out) != 0) return 1;
    return 0;
}

/* ------------------------------------------------------------------ connect */
int sci_db_libpq_connect(char* fname, void* pvApiCtx)
{
    char* connstr = NULL;
    int slot = -1, i;
    PGconn* c = NULL;

    CheckInputArgument(pvApiCtx, 1, 1);
    CheckOutputArgument(pvApiCtx, 1, 1);

    if (db_get_string(pvApiCtx, 1, &connstr)) {
        Scierror(999, _("%s: expected a single connection string.\n"), fname);
        return 0;
    }
    for (i = 0; i < DB_MAXCONN; i++) if (g_conns[i] == NULL) { slot = i; break; }
    if (slot < 0) {
        freeAllocatedSingleString(connstr);
        Scierror(999, _("%s: too many open connections (max %d).\n"), fname, DB_MAXCONN);
        return 0;
    }
    c = PQconnectdb(connstr);
    freeAllocatedSingleString(connstr);
    if (PQstatus(c) != CONNECTION_OK) {
        char msg[1024];
        snprintf(msg, sizeof(msg), "%s", PQerrorMessage(c));
        PQfinish(c);
        Scierror(999, _("%s: connection failed: %s\n"), fname, msg);
        return 0;
    }
    g_conns[slot] = c;

    createScalarDouble(pvApiCtx, nbInputArgument(pvApiCtx) + 1, (double)(slot + 1));
    AssignOutputVariable(pvApiCtx, 1) = nbInputArgument(pvApiCtx) + 1;
    ReturnArguments(pvApiCtx);
    return 0;
}

/* --------------------------------------------------------------------- exec */
int sci_db_libpq_exec(char* fname, void* pvApiCtx)
{
    double did = 0.0;
    int slot, nr, nc, i, j;
    char* sql = NULL;
    PGconn* c = NULL;
    PGresult* r = NULL;
    ExecStatusType st;

    CheckInputArgument(pvApiCtx, 2, 2);
    CheckOutputArgument(pvApiCtx, 1, 3);

    if (db_get_double(pvApiCtx, 1, &did)) {
        Scierror(999, _("%s: first argument must be a connection id.\n"), fname);
        return 0;
    }
    slot = (int)did - 1;
    if (slot < 0 || slot >= DB_MAXCONN || g_conns[slot] == NULL) {
        Scierror(999, _("%s: invalid or closed connection id.\n"), fname);
        return 0;
    }
    c = g_conns[slot];
    if (db_get_string(pvApiCtx, 2, &sql)) {
        Scierror(999, _("%s: second argument must be an SQL string.\n"), fname);
        return 0;
    }
    r = PQexec(c, sql);
    freeAllocatedSingleString(sql);
    st = PQresultStatus(r);

    if (st == PGRES_TUPLES_OK) {
        char** data = NULL;
        char** cols = NULL;
        nr = PQntuples(r);
        nc = PQnfields(r);
        data = (char**)MALLOC(sizeof(char*) * (nr * nc > 0 ? nr * nc : 1));
        cols = (char**)MALLOC(sizeof(char*) * (nc > 0 ? nc : 1));
        /* Scilab string matrices are column-major */
        for (j = 0; j < nc; j++) {
            cols[j] = PQfname(r, j);
            for (i = 0; i < nr; i++)
                data[j * nr + i] = PQgetisnull(r, i, j) ? (char*)"" : PQgetvalue(r, i, j);
        }
        createMatrixOfString(pvApiCtx, nbInputArgument(pvApiCtx) + 1, nr, nc, data);
        createMatrixOfString(pvApiCtx, nbInputArgument(pvApiCtx) + 2, (nc > 0) ? 1 : 0, nc, cols);
        createScalarDouble(pvApiCtx, nbInputArgument(pvApiCtx) + 3, (double)nr);
        FREE(data); FREE(cols);
    } else if (st == PGRES_COMMAND_OK) {
        char* ct = PQcmdTuples(r);
        double affected = (ct && *ct) ? atof(ct) : 0.0;
        createScalarDouble(pvApiCtx, nbInputArgument(pvApiCtx) + 3, affected);
        createEmptyMatrix(pvApiCtx, nbInputArgument(pvApiCtx) + 1); /* data = [] */
        createEmptyMatrix(pvApiCtx, nbInputArgument(pvApiCtx) + 2); /* cols = [] */
    } else {
        char msg[2048];
        snprintf(msg, sizeof(msg), "%s", PQresultErrorMessage(r));
        PQclear(r);
        Scierror(999, _("%s: query failed: %s\n"), fname, msg);
        return 0;
    }
    PQclear(r);

    AssignOutputVariable(pvApiCtx, 1) = nbInputArgument(pvApiCtx) + 3; /* rc   */
    AssignOutputVariable(pvApiCtx, 2) = nbInputArgument(pvApiCtx) + 1; /* data */
    AssignOutputVariable(pvApiCtx, 3) = nbInputArgument(pvApiCtx) + 2; /* cols */
    ReturnArguments(pvApiCtx);
    return 0;
}

/* ---- prepared statements ---- */
#define DB_MAXSTMT 256
static PGconn* g_pq_stmt_conn[DB_MAXSTMT] = {0};
static char    g_pq_stmt_name[DB_MAXSTMT][32];

/* emit [rc,data,cols] from a PGresult; returns 1 (and raises) on query error, else 0. */
static int pq_emit(void* pvApiCtx, PGresult* r, char* fname)
{
    ExecStatusType st = PQresultStatus(r);
    if (st == PGRES_TUPLES_OK) {
        int nr = PQntuples(r), nc = PQnfields(r), i, j;
        char** data = (char**)MALLOC(sizeof(char*) * (nr * nc > 0 ? nr * nc : 1));
        char** cols = (char**)MALLOC(sizeof(char*) * (nc > 0 ? nc : 1));
        for (j = 0; j < nc; j++) { cols[j] = PQfname(r, j); for (i = 0; i < nr; i++) data[j * nr + i] = PQgetisnull(r, i, j) ? (char*)"" : PQgetvalue(r, i, j); }
        createMatrixOfString(pvApiCtx, nbInputArgument(pvApiCtx) + 1, nr, nc, data);
        createMatrixOfString(pvApiCtx, nbInputArgument(pvApiCtx) + 2, (nc > 0) ? 1 : 0, nc, cols);
        createScalarDouble(pvApiCtx, nbInputArgument(pvApiCtx) + 3, (double)nr);
        FREE(data); FREE(cols);
    } else if (st == PGRES_COMMAND_OK) {
        char* ct = PQcmdTuples(r); double aff = (ct && *ct) ? atof(ct) : 0.0;
        createScalarDouble(pvApiCtx, nbInputArgument(pvApiCtx) + 3, aff);
        createEmptyMatrix(pvApiCtx, nbInputArgument(pvApiCtx) + 1);
        createEmptyMatrix(pvApiCtx, nbInputArgument(pvApiCtx) + 2);
    } else {
        char m[2048]; snprintf(m, sizeof(m), "%s", PQresultErrorMessage(r));
        Scierror(999, _("%s: query failed: %s\n"), fname, m); return 1;
    }
    AssignOutputVariable(pvApiCtx, 1) = nbInputArgument(pvApiCtx) + 3;
    AssignOutputVariable(pvApiCtx, 2) = nbInputArgument(pvApiCtx) + 1;
    AssignOutputVariable(pvApiCtx, 3) = nbInputArgument(pvApiCtx) + 2;
    return 0;
}

int sci_db_libpq_prepare(char* fname, void* pvApiCtx)
{
    double did = 0.0; int slot, st = -1, i; char* sql = NULL; PGresult* r;
    CheckInputArgument(pvApiCtx, 2, 2); CheckOutputArgument(pvApiCtx, 1, 1);
    if (db_get_double(pvApiCtx, 1, &did)) { Scierror(999, _("%s: first argument must be a connection id.\n"), fname); return 0; }
    slot = (int)did - 1;
    if (slot < 0 || slot >= DB_MAXCONN || g_conns[slot] == NULL) { Scierror(999, _("%s: invalid or closed connection id.\n"), fname); return 0; }
    if (db_get_string(pvApiCtx, 2, &sql)) { Scierror(999, _("%s: second argument must be an SQL string.\n"), fname); return 0; }
    for (i = 0; i < DB_MAXSTMT; i++) if (g_pq_stmt_conn[i] == NULL) { st = i; break; }
    if (st < 0) { freeAllocatedSingleString(sql); Scierror(999, _("%s: too many prepared statements.\n"), fname); return 0; }
    snprintf(g_pq_stmt_name[st], 32, "scidb_ps_%d", st);
    r = PQprepare(g_conns[slot], g_pq_stmt_name[st], sql, 0, NULL);
    freeAllocatedSingleString(sql);
    if (PQresultStatus(r) != PGRES_COMMAND_OK) {
        char m[2048]; snprintf(m, sizeof(m), "%s", PQresultErrorMessage(r));
        PQclear(r); Scierror(999, _("%s: prepare failed: %s\n"), fname, m); return 0;
    }
    PQclear(r);
    g_pq_stmt_conn[st] = g_conns[slot];
    createScalarDouble(pvApiCtx, nbInputArgument(pvApiCtx) + 1, (double)(st + 1));
    AssignOutputVariable(pvApiCtx, 1) = nbInputArgument(pvApiCtx) + 1;
    ReturnArguments(pvApiCtx);
    return 0;
}

int sci_db_libpq_run(char* fname, void* pvApiCtx)
{
    double dst = 0.0; int st, m = 0, n = 0, i, np = 0; int* piAddr = NULL; char** params = NULL;
    const char** pv = NULL; PGresult* r; SciErr se;
    CheckInputArgument(pvApiCtx, 2, 2); CheckOutputArgument(pvApiCtx, 1, 3);
    if (db_get_double(pvApiCtx, 1, &dst)) { Scierror(999, _("%s: first argument must be a statement handle.\n"), fname); return 0; }
    st = (int)dst - 1;
    if (st < 0 || st >= DB_MAXSTMT || g_pq_stmt_conn[st] == NULL) { Scierror(999, _("%s: invalid or finalized statement.\n"), fname); return 0; }
    se = getVarAddressFromPosition(pvApiCtx, 2, &piAddr);
    if (!se.iErr && isStringType(pvApiCtx, piAddr) && getAllocatedMatrixOfString(pvApiCtx, piAddr, &m, &n, &params) == 0) {
        np = m * n;
        if (np > 0) { pv = (const char**)malloc(sizeof(char*) * np); for (i = 0; i < np; i++) pv[i] = params[i]; }
    }
    r = PQexecPrepared(g_pq_stmt_conn[st], g_pq_stmt_name[st], np, pv, NULL, NULL, 0);
    if (pv) free((void*)pv);
    if (params) freeAllocatedMatrixOfString(m, n, params);
    if (pq_emit(pvApiCtx, r, fname)) { PQclear(r); return 0; }
    PQclear(r);
    ReturnArguments(pvApiCtx);
    return 0;
}

int sci_db_libpq_finalize(char* fname, void* pvApiCtx)
{
    double dst = 0.0; int st;
    CheckInputArgument(pvApiCtx, 1, 1); CheckOutputArgument(pvApiCtx, 0, 1);
    if (db_get_double(pvApiCtx, 1, &dst)) { Scierror(999, _("%s: argument must be a statement handle.\n"), fname); return 0; }
    st = (int)dst - 1;
    if (st >= 0 && st < DB_MAXSTMT && g_pq_stmt_conn[st] != NULL) {
        char dq[64]; PGresult* r; snprintf(dq, sizeof(dq), "DEALLOCATE %s", g_pq_stmt_name[st]);
        r = PQexec(g_pq_stmt_conn[st], dq); PQclear(r); g_pq_stmt_conn[st] = NULL;
    }
    AssignOutputVariable(pvApiCtx, 1) = 0;
    ReturnArguments(pvApiCtx);
    return 0;
}

/* -------------------------------------------------------------------- close */
int sci_db_libpq_close(char* fname, void* pvApiCtx)
{
    double did = 0.0;
    int slot;

    CheckInputArgument(pvApiCtx, 1, 1);
    CheckOutputArgument(pvApiCtx, 0, 1);

    if (db_get_double(pvApiCtx, 1, &did)) {
        Scierror(999, _("%s: argument must be a connection id.\n"), fname);
        return 0;
    }
    slot = (int)did - 1;
    if (slot >= 0 && slot < DB_MAXCONN && g_conns[slot] != NULL) {
        PQfinish(g_conns[slot]);
        g_conns[slot] = NULL;
    }
    AssignOutputVariable(pvApiCtx, 1) = 0;
    ReturnArguments(pvApiCtx);
    return 0;
}
