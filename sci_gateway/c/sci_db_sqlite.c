/*
 * sciDatabase — SQLite native transport (Scilab 2027 / macOS arm64).
 *   id          = db_sqlite_connect(filename)   // sqlite3_open; ":memory:" allowed
 *   [rc,data,cols] = db_sqlite_exec(id, sql)     // SELECT -> (nrows, nr*nc strings, 1*nc names)
 *                                                // DML   -> (changes, [], [])
 *                  db_sqlite_close(id)
 * No server, no JVM — works in every Scilab binary including scilab-cli.
 */
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include "api_scilab.h"
#include "Scierror.h"
#include "sci_malloc.h"
#include "localization.h"
#include <sqlite3.h>

#define DB_MAXSQ 64
static sqlite3* g_sq[DB_MAXSQ] = {0};

static int sq_get_string(void* pvApiCtx, int pos, char** out)
{
    int* piAddr = NULL;
    SciErr se = getVarAddressFromPosition(pvApiCtx, pos, &piAddr);
    if (se.iErr) { printError(&se, 0); return 1; }
    if (!isStringType(pvApiCtx, piAddr) || !isScalar(pvApiCtx, piAddr)) return 1;
    if (getAllocatedSingleString(pvApiCtx, piAddr, out) != 0) return 1;
    return 0;
}
static int sq_get_double(void* pvApiCtx, int pos, double* out)
{
    int* piAddr = NULL;
    SciErr se = getVarAddressFromPosition(pvApiCtx, pos, &piAddr);
    if (se.iErr) { printError(&se, 0); return 1; }
    if (getScalarDouble(pvApiCtx, piAddr, out) != 0) return 1;
    return 0;
}

int sci_db_sqlite_connect(char* fname, void* pvApiCtx)
{
    char* file = NULL; int slot = -1, i; sqlite3* db = NULL;
    CheckInputArgument(pvApiCtx, 1, 1);
    CheckOutputArgument(pvApiCtx, 1, 1);
    if (sq_get_string(pvApiCtx, 1, &file)) { Scierror(999, _("%s: expected a database file path.\n"), fname); return 0; }
    for (i = 0; i < DB_MAXSQ; i++) if (g_sq[i] == NULL) { slot = i; break; }
    if (slot < 0) { freeAllocatedSingleString(file); Scierror(999, _("%s: too many open connections.\n"), fname); return 0; }
    if (sqlite3_open(file, &db) != SQLITE_OK) {
        char msg[1024]; snprintf(msg, sizeof(msg), "%s", db ? sqlite3_errmsg(db) : "cannot open");
        if (db) sqlite3_close(db);
        freeAllocatedSingleString(file);
        Scierror(999, _("%s: open failed: %s\n"), fname, msg); return 0;
    }
    freeAllocatedSingleString(file);
    g_sq[slot] = db;
    createScalarDouble(pvApiCtx, nbInputArgument(pvApiCtx) + 1, (double)(slot + 1));
    AssignOutputVariable(pvApiCtx, 1) = nbInputArgument(pvApiCtx) + 1;
    ReturnArguments(pvApiCtx);
    return 0;
}

int sci_db_sqlite_exec(char* fname, void* pvApiCtx)
{
    double did = 0.0; int slot, nc, i, j; char* sql = NULL;
    sqlite3* db = NULL; sqlite3_stmt* stmt = NULL;
    CheckInputArgument(pvApiCtx, 2, 2);
    CheckOutputArgument(pvApiCtx, 1, 3);
    if (sq_get_double(pvApiCtx, 1, &did)) { Scierror(999, _("%s: first argument must be a connection id.\n"), fname); return 0; }
    slot = (int)did - 1;
    if (slot < 0 || slot >= DB_MAXSQ || g_sq[slot] == NULL) { Scierror(999, _("%s: invalid or closed connection id.\n"), fname); return 0; }
    db = g_sq[slot];
    if (sq_get_string(pvApiCtx, 2, &sql)) { Scierror(999, _("%s: second argument must be an SQL string.\n"), fname); return 0; }

    if (sqlite3_prepare_v2(db, sql, -1, &stmt, NULL) != SQLITE_OK) {
        char msg[2048]; snprintf(msg, sizeof(msg), "%s", sqlite3_errmsg(db));
        freeAllocatedSingleString(sql);
        Scierror(999, _("%s: prepare failed: %s\n"), fname, msg); return 0;
    }
    freeAllocatedSingleString(sql);
    nc = sqlite3_column_count(stmt);

    if (nc == 0) {
        double affected;
        sqlite3_step(stmt);
        affected = (double)sqlite3_changes(db);
        sqlite3_finalize(stmt);
        createScalarDouble(pvApiCtx, nbInputArgument(pvApiCtx) + 3, affected);
        createEmptyMatrix(pvApiCtx, nbInputArgument(pvApiCtx) + 1);
        createEmptyMatrix(pvApiCtx, nbInputArgument(pvApiCtx) + 2);
    } else {
        int cap = 16, nr = 0, rc;
        char** cells = (char**)malloc(sizeof(char*) * cap * nc);
        char** cols  = (char**)malloc(sizeof(char*) * nc);
        char** data;
        for (j = 0; j < nc; j++) cols[j] = strdup(sqlite3_column_name(stmt, j));
        while ((rc = sqlite3_step(stmt)) == SQLITE_ROW) {
            if (nr >= cap) { cap *= 2; cells = (char**)realloc(cells, sizeof(char*) * cap * nc); }
            for (j = 0; j < nc; j++) {
                const unsigned char* t = sqlite3_column_text(stmt, j);
                cells[nr * nc + j] = strdup(t ? (const char*)t : "");
            }
            nr++;
        }
        sqlite3_finalize(stmt);
        data = (char**)malloc(sizeof(char*) * (nr * nc > 0 ? nr * nc : 1));
        for (j = 0; j < nc; j++) for (i = 0; i < nr; i++) data[j * nr + i] = cells[i * nc + j]; /* col-major */
        createMatrixOfString(pvApiCtx, nbInputArgument(pvApiCtx) + 1, nr, nc, data);
        createMatrixOfString(pvApiCtx, nbInputArgument(pvApiCtx) + 2, (nc > 0) ? 1 : 0, nc, cols);
        createScalarDouble(pvApiCtx, nbInputArgument(pvApiCtx) + 3, (double)nr);
        free(data);
        for (i = 0; i < nr * nc; i++) free(cells[i]);
        free(cells);
        for (j = 0; j < nc; j++) free(cols[j]);
        free(cols);
    }
    AssignOutputVariable(pvApiCtx, 1) = nbInputArgument(pvApiCtx) + 3;
    AssignOutputVariable(pvApiCtx, 2) = nbInputArgument(pvApiCtx) + 1;
    AssignOutputVariable(pvApiCtx, 3) = nbInputArgument(pvApiCtx) + 2;
    ReturnArguments(pvApiCtx);
    return 0;
}

/* ---- prepared statements ---- */
#define DB_MAXSTMT 256
static sqlite3_stmt* g_sq_stmt[DB_MAXSTMT] = {0};

/* execute a prepared (and already param-bound) statement, emit [rc,data,cols] at +1/+2/+3 */
static void sq_collect(void* pvApiCtx, sqlite3_stmt* stmt)
{
    int nc = sqlite3_column_count(stmt), i, j, rc;
    if (nc == 0) {
        sqlite3_step(stmt);
        createScalarDouble(pvApiCtx, nbInputArgument(pvApiCtx) + 3, (double)sqlite3_changes(sqlite3_db_handle(stmt)));
        createEmptyMatrix(pvApiCtx, nbInputArgument(pvApiCtx) + 1);
        createEmptyMatrix(pvApiCtx, nbInputArgument(pvApiCtx) + 2);
    } else {
        int cap = 16, nr = 0;
        char** cells = (char**)malloc(sizeof(char*) * cap * nc);
        char** cols  = (char**)malloc(sizeof(char*) * nc);
        char** data;
        for (j = 0; j < nc; j++) cols[j] = strdup(sqlite3_column_name(stmt, j));
        while ((rc = sqlite3_step(stmt)) == SQLITE_ROW) {
            if (nr >= cap) { cap *= 2; cells = (char**)realloc(cells, sizeof(char*) * cap * nc); }
            for (j = 0; j < nc; j++) { const unsigned char* t = sqlite3_column_text(stmt, j); cells[nr * nc + j] = strdup(t ? (const char*)t : ""); }
            nr++;
        }
        data = (char**)malloc(sizeof(char*) * (nr * nc > 0 ? nr * nc : 1));
        for (j = 0; j < nc; j++) for (i = 0; i < nr; i++) data[j * nr + i] = cells[i * nc + j];
        createMatrixOfString(pvApiCtx, nbInputArgument(pvApiCtx) + 1, nr, nc, data);
        createMatrixOfString(pvApiCtx, nbInputArgument(pvApiCtx) + 2, (nc > 0) ? 1 : 0, nc, cols);
        createScalarDouble(pvApiCtx, nbInputArgument(pvApiCtx) + 3, (double)nr);
        free(data);
        for (i = 0; i < nr * nc; i++) free(cells[i]); free(cells);
        for (j = 0; j < nc; j++) free(cols[j]); free(cols);
    }
}

int sci_db_sqlite_prepare(char* fname, void* pvApiCtx)
{
    double did = 0.0; int slot, st = -1, i; char* sql = NULL; sqlite3_stmt* stmt = NULL;
    CheckInputArgument(pvApiCtx, 2, 2); CheckOutputArgument(pvApiCtx, 1, 1);
    if (sq_get_double(pvApiCtx, 1, &did)) { Scierror(999, _("%s: first argument must be a connection id.\n"), fname); return 0; }
    slot = (int)did - 1;
    if (slot < 0 || slot >= DB_MAXSQ || g_sq[slot] == NULL) { Scierror(999, _("%s: invalid or closed connection id.\n"), fname); return 0; }
    if (sq_get_string(pvApiCtx, 2, &sql)) { Scierror(999, _("%s: second argument must be an SQL string.\n"), fname); return 0; }
    if (sqlite3_prepare_v2(g_sq[slot], sql, -1, &stmt, NULL) != SQLITE_OK) {
        char m[2048]; snprintf(m, sizeof(m), "%s", sqlite3_errmsg(g_sq[slot]));
        freeAllocatedSingleString(sql); Scierror(999, _("%s: prepare failed: %s\n"), fname, m); return 0;
    }
    freeAllocatedSingleString(sql);
    for (i = 0; i < DB_MAXSTMT; i++) if (g_sq_stmt[i] == NULL) { st = i; break; }
    if (st < 0) { sqlite3_finalize(stmt); Scierror(999, _("%s: too many prepared statements.\n"), fname); return 0; }
    g_sq_stmt[st] = stmt;
    createScalarDouble(pvApiCtx, nbInputArgument(pvApiCtx) + 1, (double)(st + 1));
    AssignOutputVariable(pvApiCtx, 1) = nbInputArgument(pvApiCtx) + 1;
    ReturnArguments(pvApiCtx);
    return 0;
}

int sci_db_sqlite_run(char* fname, void* pvApiCtx)
{
    double dst = 0.0; int st, m = 0, n = 0, i, np; int* piAddr = NULL; char** params = NULL;
    sqlite3_stmt* stmt; SciErr se;
    CheckInputArgument(pvApiCtx, 2, 2); CheckOutputArgument(pvApiCtx, 1, 3);
    if (sq_get_double(pvApiCtx, 1, &dst)) { Scierror(999, _("%s: first argument must be a statement handle.\n"), fname); return 0; }
    st = (int)dst - 1;
    if (st < 0 || st >= DB_MAXSTMT || g_sq_stmt[st] == NULL) { Scierror(999, _("%s: invalid or finalized statement.\n"), fname); return 0; }
    stmt = g_sq_stmt[st];
    sqlite3_reset(stmt); sqlite3_clear_bindings(stmt);
    se = getVarAddressFromPosition(pvApiCtx, 2, &piAddr);
    if (!se.iErr && isStringType(pvApiCtx, piAddr) && getAllocatedMatrixOfString(pvApiCtx, piAddr, &m, &n, &params) == 0) {
        np = m * n;
        for (i = 0; i < np; i++) sqlite3_bind_text(stmt, i + 1, params[i], -1, SQLITE_TRANSIENT);
        freeAllocatedMatrixOfString(m, n, params);
    }
    sq_collect(pvApiCtx, stmt);
    sqlite3_reset(stmt);
    AssignOutputVariable(pvApiCtx, 1) = nbInputArgument(pvApiCtx) + 3;
    AssignOutputVariable(pvApiCtx, 2) = nbInputArgument(pvApiCtx) + 1;
    AssignOutputVariable(pvApiCtx, 3) = nbInputArgument(pvApiCtx) + 2;
    ReturnArguments(pvApiCtx);
    return 0;
}

int sci_db_sqlite_finalize(char* fname, void* pvApiCtx)
{
    double dst = 0.0; int st;
    CheckInputArgument(pvApiCtx, 1, 1); CheckOutputArgument(pvApiCtx, 0, 1);
    if (sq_get_double(pvApiCtx, 1, &dst)) { Scierror(999, _("%s: argument must be a statement handle.\n"), fname); return 0; }
    st = (int)dst - 1;
    if (st >= 0 && st < DB_MAXSTMT && g_sq_stmt[st] != NULL) { sqlite3_finalize(g_sq_stmt[st]); g_sq_stmt[st] = NULL; }
    AssignOutputVariable(pvApiCtx, 1) = 0;
    ReturnArguments(pvApiCtx);
    return 0;
}

int sci_db_sqlite_close(char* fname, void* pvApiCtx)
{
    double did = 0.0; int slot;
    CheckInputArgument(pvApiCtx, 1, 1);
    CheckOutputArgument(pvApiCtx, 0, 1);
    if (sq_get_double(pvApiCtx, 1, &did)) { Scierror(999, _("%s: argument must be a connection id.\n"), fname); return 0; }
    slot = (int)did - 1;
    if (slot >= 0 && slot < DB_MAXSQ && g_sq[slot] != NULL) { sqlite3_close(g_sq[slot]); g_sq[slot] = NULL; }
    AssignOutputVariable(pvApiCtx, 1) = 0;
    ReturnArguments(pvApiCtx);
    return 0;
}
