/*
 * sciDatabase — MySQL native transport (libmysqlclient), Scilab 2027 / macOS arm64.
 *   id          = db_mysql_connect(host, port, database, user, password)
 *   [rc,data,cols] = db_mysql_exec(id, sql)   // SELECT -> (nrows, nr*nc strings, 1*nc names)
 *                                             // DML   -> (affected, [], [])
 *                  db_mysql_close(id)
 * Native (no JVM) — works in every Scilab binary incl. scilab-cli.
 */
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include "api_scilab.h"
#include "Scierror.h"
#include "sci_malloc.h"
#include "localization.h"
#include <mysql.h>

#define DB_MAXMY 64
static MYSQL* g_my[DB_MAXMY] = {0};

static int my_get_string(void* pvApiCtx, int pos, char** out)
{
    int* piAddr = NULL;
    SciErr se = getVarAddressFromPosition(pvApiCtx, pos, &piAddr);
    if (se.iErr) { printError(&se, 0); return 1; }
    if (!isStringType(pvApiCtx, piAddr) || !isScalar(pvApiCtx, piAddr)) return 1;
    if (getAllocatedSingleString(pvApiCtx, piAddr, out) != 0) return 1;
    return 0;
}
static int my_get_double(void* pvApiCtx, int pos, double* out)
{
    int* piAddr = NULL;
    SciErr se = getVarAddressFromPosition(pvApiCtx, pos, &piAddr);
    if (se.iErr) { printError(&se, 0); return 1; }
    if (getScalarDouble(pvApiCtx, piAddr, out) != 0) return 1;
    return 0;
}

int sci_db_mysql_connect(char* fname, void* pvApiCtx)
{
    char *host = NULL, *db = NULL, *user = NULL, *pw = NULL;
    double dport = 0.0; int slot = -1, i; MYSQL* m = NULL;
    CheckInputArgument(pvApiCtx, 5, 5);   // host, port, database, user, password
    CheckOutputArgument(pvApiCtx, 1, 1);
    if (my_get_string(pvApiCtx, 1, &host) || my_get_double(pvApiCtx, 2, &dport) ||
        my_get_string(pvApiCtx, 3, &db)   || my_get_string(pvApiCtx, 4, &user) ||
        my_get_string(pvApiCtx, 5, &pw)) {
        Scierror(999, _("%s: expected (host, port, database, user, password).\n"), fname); return 0;
    }
    for (i = 0; i < DB_MAXMY; i++) if (g_my[i] == NULL) { slot = i; break; }
    if (slot < 0) { Scierror(999, _("%s: too many open connections.\n"), fname); return 0; }
    m = mysql_init(NULL);
    if (m == NULL) { Scierror(999, _("%s: mysql_init failed.\n"), fname); return 0; }
    if (mysql_real_connect(m, host, user, pw, (db && *db) ? db : NULL, (unsigned int)dport, NULL, 0) == NULL) {
        char msg[1024]; snprintf(msg, sizeof(msg), "%s", mysql_error(m));
        mysql_close(m);
        freeAllocatedSingleString(host); freeAllocatedSingleString(db);
        freeAllocatedSingleString(user); freeAllocatedSingleString(pw);
        Scierror(999, _("%s: connection failed: %s\n"), fname, msg); return 0;
    }
    freeAllocatedSingleString(host); freeAllocatedSingleString(db);
    freeAllocatedSingleString(user); freeAllocatedSingleString(pw);
    g_my[slot] = m;
    createScalarDouble(pvApiCtx, nbInputArgument(pvApiCtx) + 1, (double)(slot + 1));
    AssignOutputVariable(pvApiCtx, 1) = nbInputArgument(pvApiCtx) + 1;
    ReturnArguments(pvApiCtx);
    return 0;
}

int sci_db_mysql_exec(char* fname, void* pvApiCtx)
{
    double did = 0.0; int slot, nc, nr, i, j; char* sql = NULL;
    MYSQL* m = NULL; MYSQL_RES* res = NULL;
    CheckInputArgument(pvApiCtx, 2, 2);
    CheckOutputArgument(pvApiCtx, 1, 3);
    if (my_get_double(pvApiCtx, 1, &did)) { Scierror(999, _("%s: first argument must be a connection id.\n"), fname); return 0; }
    slot = (int)did - 1;
    if (slot < 0 || slot >= DB_MAXMY || g_my[slot] == NULL) { Scierror(999, _("%s: invalid or closed connection id.\n"), fname); return 0; }
    m = g_my[slot];
    if (my_get_string(pvApiCtx, 2, &sql)) { Scierror(999, _("%s: second argument must be an SQL string.\n"), fname); return 0; }
    if (mysql_query(m, sql) != 0) {
        char msg[2048]; snprintf(msg, sizeof(msg), "%s", mysql_error(m));
        freeAllocatedSingleString(sql);
        Scierror(999, _("%s: query failed: %s\n"), fname, msg); return 0;
    }
    freeAllocatedSingleString(sql);
    res = mysql_store_result(m);

    if (res != NULL) {
        MYSQL_FIELD* fields;
        char** data; char** cols; MYSQL_ROW row;
        nc = (int)mysql_num_fields(res);
        nr = (int)mysql_num_rows(res);
        fields = mysql_fetch_fields(res);
        cols = (char**)malloc(sizeof(char*) * (nc > 0 ? nc : 1));
        data = (char**)malloc(sizeof(char*) * (nr * nc > 0 ? nr * nc : 1));
        for (j = 0; j < nc; j++) cols[j] = fields[j].name;
        i = 0;
        while ((row = mysql_fetch_row(res)) != NULL) {
            for (j = 0; j < nc; j++) data[j * nr + i] = row[j] ? row[j] : (char*)""; /* col-major */
            i++;
        }
        createMatrixOfString(pvApiCtx, nbInputArgument(pvApiCtx) + 1, nr, nc, data);
        createMatrixOfString(pvApiCtx, nbInputArgument(pvApiCtx) + 2, (nc > 0) ? 1 : 0, nc, cols);
        createScalarDouble(pvApiCtx, nbInputArgument(pvApiCtx) + 3, (double)nr);
        free(data); free(cols);
        mysql_free_result(res);
    } else if (mysql_field_count(m) == 0) {
        double affected = (double)mysql_affected_rows(m);
        createScalarDouble(pvApiCtx, nbInputArgument(pvApiCtx) + 3, affected);
        createEmptyMatrix(pvApiCtx, nbInputArgument(pvApiCtx) + 1);
        createEmptyMatrix(pvApiCtx, nbInputArgument(pvApiCtx) + 2);
    } else {
        char msg[1024]; snprintf(msg, sizeof(msg), "%s", mysql_error(m));
        Scierror(999, _("%s: result fetch failed: %s\n"), fname, msg); return 0;
    }
    AssignOutputVariable(pvApiCtx, 1) = nbInputArgument(pvApiCtx) + 3;
    AssignOutputVariable(pvApiCtx, 2) = nbInputArgument(pvApiCtx) + 1;
    AssignOutputVariable(pvApiCtx, 3) = nbInputArgument(pvApiCtx) + 2;
    ReturnArguments(pvApiCtx);
    return 0;
}

int sci_db_mysql_close(char* fname, void* pvApiCtx)
{
    double did = 0.0; int slot;
    CheckInputArgument(pvApiCtx, 1, 1);
    CheckOutputArgument(pvApiCtx, 0, 1);
    if (my_get_double(pvApiCtx, 1, &did)) { Scierror(999, _("%s: argument must be a connection id.\n"), fname); return 0; }
    slot = (int)did - 1;
    if (slot >= 0 && slot < DB_MAXMY && g_my[slot] != NULL) { mysql_close(g_my[slot]); g_my[slot] = NULL; }
    AssignOutputVariable(pvApiCtx, 1) = 0;
    ReturnArguments(pvApiCtx);
    return 0;
}
