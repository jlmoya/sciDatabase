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
#include <stdbool.h>
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

/* ---- prepared statements ---- */
#define DB_MAXSTMT 256
static MYSQL_STMT* g_my_stmt[DB_MAXSTMT] = {0};

int sci_db_mysql_prepare(char* fname, void* pvApiCtx)
{
    double did = 0.0; int slot, st = -1, i; char* sql = NULL; MYSQL_STMT* stmt;
    CheckInputArgument(pvApiCtx, 2, 2); CheckOutputArgument(pvApiCtx, 1, 1);
    if (my_get_double(pvApiCtx, 1, &did)) { Scierror(999, _("%s: first argument must be a connection id.\n"), fname); return 0; }
    slot = (int)did - 1;
    if (slot < 0 || slot >= DB_MAXMY || g_my[slot] == NULL) { Scierror(999, _("%s: invalid or closed connection id.\n"), fname); return 0; }
    if (my_get_string(pvApiCtx, 2, &sql)) { Scierror(999, _("%s: second argument must be an SQL string.\n"), fname); return 0; }
    stmt = mysql_stmt_init(g_my[slot]);
    if (stmt == NULL) { freeAllocatedSingleString(sql); Scierror(999, _("%s: mysql_stmt_init failed.\n"), fname); return 0; }
    if (mysql_stmt_prepare(stmt, sql, (unsigned long)strlen(sql)) != 0) {
        char m[2048]; snprintf(m, sizeof(m), "%s", mysql_stmt_error(stmt));
        mysql_stmt_close(stmt); freeAllocatedSingleString(sql);
        Scierror(999, _("%s: prepare failed: %s\n"), fname, m); return 0;
    }
    freeAllocatedSingleString(sql);
    for (i = 0; i < DB_MAXSTMT; i++) if (g_my_stmt[i] == NULL) { st = i; break; }
    if (st < 0) { mysql_stmt_close(stmt); Scierror(999, _("%s: too many prepared statements.\n"), fname); return 0; }
    g_my_stmt[st] = stmt;
    createScalarDouble(pvApiCtx, nbInputArgument(pvApiCtx) + 1, (double)(st + 1));
    AssignOutputVariable(pvApiCtx, 1) = nbInputArgument(pvApiCtx) + 1;
    ReturnArguments(pvApiCtx);
    return 0;
}

int sci_db_mysql_run(char* fname, void* pvApiCtx)
{
    double dst = 0.0; int st, m = 0, n = 0, i, j, np = 0; int* piAddr = NULL; char** params = NULL;
    MYSQL_STMT* stmt; MYSQL_RES* meta; SciErr se; bool aupd = 1;
    MYSQL_BIND* pbind = NULL; unsigned long* plen = NULL;
    CheckInputArgument(pvApiCtx, 2, 2); CheckOutputArgument(pvApiCtx, 1, 3);
    if (my_get_double(pvApiCtx, 1, &dst)) { Scierror(999, _("%s: first argument must be a statement handle.\n"), fname); return 0; }
    st = (int)dst - 1;
    if (st < 0 || st >= DB_MAXSTMT || g_my_stmt[st] == NULL) { Scierror(999, _("%s: invalid or finalized statement.\n"), fname); return 0; }
    stmt = g_my_stmt[st];
    se = getVarAddressFromPosition(pvApiCtx, 2, &piAddr);
    if (!se.iErr && isStringType(pvApiCtx, piAddr) && getAllocatedMatrixOfString(pvApiCtx, piAddr, &m, &n, &params) == 0) np = m * n;
    if (np > 0) {
        pbind = (MYSQL_BIND*)calloc(np, sizeof(MYSQL_BIND));
        plen  = (unsigned long*)malloc(np * sizeof(unsigned long));
        for (i = 0; i < np; i++) {
            plen[i] = (unsigned long)strlen(params[i]);
            pbind[i].buffer_type = MYSQL_TYPE_STRING; pbind[i].buffer = params[i];
            pbind[i].buffer_length = plen[i]; pbind[i].length = &plen[i];
        }
        mysql_stmt_bind_param(stmt, pbind);
    }
    mysql_stmt_attr_set(stmt, STMT_ATTR_UPDATE_MAX_LENGTH, &aupd);
    if (mysql_stmt_execute(stmt) != 0) {
        char msg[2048]; snprintf(msg, sizeof(msg), "%s", mysql_stmt_error(stmt));
        if (pbind) free(pbind); if (plen) free(plen); if (params) freeAllocatedMatrixOfString(m, n, params);
        Scierror(999, _("%s: execute failed: %s\n"), fname, msg); return 0;
    }
    meta = mysql_stmt_result_metadata(stmt);
    if (meta != NULL) {
        int nc = (int)mysql_num_fields(meta), nr, row = 0;
        MYSQL_FIELD* fields; MYSQL_BIND* rbind; char** rbuf; unsigned long* rlen; bool* risnull; char** cols; char** data;
        mysql_stmt_store_result(stmt);
        nr = (int)mysql_stmt_num_rows(stmt);
        fields = mysql_fetch_fields(meta);
        rbind   = (MYSQL_BIND*)calloc(nc, sizeof(MYSQL_BIND));
        rbuf    = (char**)malloc(nc * sizeof(char*));
        rlen    = (unsigned long*)malloc(nc * sizeof(unsigned long));
        risnull = (bool*)malloc(nc * sizeof(bool));
        cols    = (char**)malloc((nc > 0 ? nc : 1) * sizeof(char*));
        data    = (char**)malloc((nr * nc > 0 ? nr * nc : 1) * sizeof(char*));
        for (j = 0; j < nc; j++) {
            unsigned long sz = fields[j].max_length + 1; if (sz < 1) sz = 1;
            rbuf[j] = (char*)malloc(sz); cols[j] = strdup(fields[j].name);
            rbind[j].buffer_type = MYSQL_TYPE_STRING; rbind[j].buffer = rbuf[j];
            rbind[j].buffer_length = sz; rbind[j].length = &rlen[j]; rbind[j].is_null = &risnull[j];
        }
        mysql_stmt_bind_result(stmt, rbind);
        while (mysql_stmt_fetch(stmt) == 0) {
            for (j = 0; j < nc; j++) data[j * nr + row] = risnull[j] ? strdup("") : strndup(rbuf[j], rlen[j]);
            row++;
        }
        createMatrixOfString(pvApiCtx, nbInputArgument(pvApiCtx) + 1, nr, nc, data);
        createMatrixOfString(pvApiCtx, nbInputArgument(pvApiCtx) + 2, (nc > 0) ? 1 : 0, nc, cols);
        createScalarDouble(pvApiCtx, nbInputArgument(pvApiCtx) + 3, (double)nr);
        for (i = 0; i < nr * nc; i++) free(data[i]); free(data);
        for (j = 0; j < nc; j++) { free(cols[j]); free(rbuf[j]); }
        free(cols); free(rbuf); free(rlen); free(risnull); free(rbind);
        mysql_free_result(meta); mysql_stmt_free_result(stmt);
    } else {
        createScalarDouble(pvApiCtx, nbInputArgument(pvApiCtx) + 3, (double)mysql_stmt_affected_rows(stmt));
        createEmptyMatrix(pvApiCtx, nbInputArgument(pvApiCtx) + 1);
        createEmptyMatrix(pvApiCtx, nbInputArgument(pvApiCtx) + 2);
    }
    if (pbind) free(pbind); if (plen) free(plen); if (params) freeAllocatedMatrixOfString(m, n, params);
    AssignOutputVariable(pvApiCtx, 1) = nbInputArgument(pvApiCtx) + 3;
    AssignOutputVariable(pvApiCtx, 2) = nbInputArgument(pvApiCtx) + 1;
    AssignOutputVariable(pvApiCtx, 3) = nbInputArgument(pvApiCtx) + 2;
    ReturnArguments(pvApiCtx);
    return 0;
}

int sci_db_mysql_finalize(char* fname, void* pvApiCtx)
{
    double dst = 0.0; int st;
    CheckInputArgument(pvApiCtx, 1, 1); CheckOutputArgument(pvApiCtx, 0, 1);
    if (my_get_double(pvApiCtx, 1, &dst)) { Scierror(999, _("%s: argument must be a statement handle.\n"), fname); return 0; }
    st = (int)dst - 1;
    if (st >= 0 && st < DB_MAXSTMT && g_my_stmt[st] != NULL) { mysql_stmt_close(g_my_stmt[st]); g_my_stmt[st] = NULL; }
    AssignOutputVariable(pvApiCtx, 1) = 0;
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
