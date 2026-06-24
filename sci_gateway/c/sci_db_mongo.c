/*
 * sciDatabase — MongoDB native transport (mongo-c-driver 2.x), Scilab 2027 / macOS arm64.
 * Document paradigm; documents move as JSON strings (the macro layer maps JSON<->struct).
 *   id  = db_mongo_connect(uri, dbname)              // uri = "mongodb://host:port"
 *   js  = db_mongo_find(id, coll, filterJson)        // -> string column of result-doc JSON
 *   n   = db_mongo_insert(id, coll, docJson)         // -> inserted count (1)
 *   n   = db_mongo_update(id, coll, filterJson, updJson)  // updJson e.g. {"$set":{...}} -> modified
 *   n   = db_mongo_delete(id, coll, filterJson)      // -> deleted count
 *         db_mongo_close(id)
 * Native (no JVM) — works in every Scilab binary incl. scilab-cli.
 */
#include <string.h>
#include <stdlib.h>
#include <stdio.h>
#include "api_scilab.h"
#include "Scierror.h"
#include "sci_malloc.h"
#include "localization.h"
#include <mongoc/mongoc.h>

#define DB_MAXMG 64
static mongoc_client_t* g_mg[DB_MAXMG] = {0};
static char* g_mgdb[DB_MAXMG] = {0};
static int g_mongo_inited = 0;

static int mg_get_string(void* pvApiCtx, int pos, char** out)
{
    int* piAddr = NULL;
    SciErr se = getVarAddressFromPosition(pvApiCtx, pos, &piAddr);
    if (se.iErr) { printError(&se, 0); return 1; }
    if (!isStringType(pvApiCtx, piAddr) || !isScalar(pvApiCtx, piAddr)) return 1;
    if (getAllocatedSingleString(pvApiCtx, piAddr, out) != 0) return 1;
    return 0;
}
static int mg_get_double(void* pvApiCtx, int pos, double* out)
{
    int* piAddr = NULL;
    SciErr se = getVarAddressFromPosition(pvApiCtx, pos, &piAddr);
    if (se.iErr) { printError(&se, 0); return 1; }
    if (getScalarDouble(pvApiCtx, piAddr, out) != 0) return 1;
    return 0;
}
static mongoc_client_t* mg_client(void* pvApiCtx, char* fname, int* slot_out)
{
    double did = 0.0; int slot;
    if (mg_get_double(pvApiCtx, 1, &did)) { Scierror(999, _("%s: first argument must be a connection id.\n"), fname); return NULL; }
    slot = (int)did - 1;
    if (slot < 0 || slot >= DB_MAXMG || g_mg[slot] == NULL) { Scierror(999, _("%s: invalid or closed connection id.\n"), fname); return NULL; }
    *slot_out = slot;
    return g_mg[slot];
}

int sci_db_mongo_connect(char* fname, void* pvApiCtx)
{
    char* uri = NULL; char* dbname = NULL; int slot = -1, i;
    mongoc_client_t* client = NULL; bson_t* ping = NULL; bson_t reply; bson_error_t error;
    CheckInputArgument(pvApiCtx, 2, 2);   /* uri, dbname */
    CheckOutputArgument(pvApiCtx, 1, 1);
    if (mg_get_string(pvApiCtx, 1, &uri) || mg_get_string(pvApiCtx, 2, &dbname)) {
        Scierror(999, _("%s: expected (uri, database).\n"), fname); return 0;
    }
    if (!g_mongo_inited) { mongoc_init(); g_mongo_inited = 1; }
    for (i = 0; i < DB_MAXMG; i++) if (g_mg[i] == NULL) { slot = i; break; }
    if (slot < 0) { freeAllocatedSingleString(uri); freeAllocatedSingleString(dbname); Scierror(999, _("%s: too many open connections.\n"), fname); return 0; }
    client = mongoc_client_new(uri);
    if (client == NULL) { freeAllocatedSingleString(uri); freeAllocatedSingleString(dbname); Scierror(999, _("%s: invalid URI.\n"), fname); return 0; }
    ping = bson_new_from_json((const uint8_t*)"{\"ping\":1}", -1, NULL);
    if (!mongoc_client_command_simple(client, "admin", ping, NULL, &reply, &error)) {
        char msg[1024]; snprintf(msg, sizeof(msg), "%s", error.message);
        bson_destroy(ping); bson_destroy(&reply); mongoc_client_destroy(client);
        freeAllocatedSingleString(uri); freeAllocatedSingleString(dbname);
        Scierror(999, _("%s: connection failed: %s\n"), fname, msg); return 0;
    }
    bson_destroy(ping); bson_destroy(&reply);
    g_mg[slot] = client; g_mgdb[slot] = strdup(dbname);
    freeAllocatedSingleString(uri); freeAllocatedSingleString(dbname);
    createScalarDouble(pvApiCtx, nbInputArgument(pvApiCtx) + 1, (double)(slot + 1));
    AssignOutputVariable(pvApiCtx, 1) = nbInputArgument(pvApiCtx) + 1;
    ReturnArguments(pvApiCtx);
    return 0;
}

int sci_db_mongo_find(char* fname, void* pvApiCtx)
{
    int slot, n = 0, cap = 16, i; char* coll = NULL; char* fjson = NULL;
    mongoc_client_t* client; mongoc_collection_t* collection; mongoc_cursor_t* cursor;
    bson_t* filter; const bson_t* doc; bson_error_t error; char** docs;
    CheckInputArgument(pvApiCtx, 3, 3);   /* id, coll, filterJson */
    CheckOutputArgument(pvApiCtx, 1, 1);
    client = mg_client(pvApiCtx, fname, &slot); if (!client) return 0;
    if (mg_get_string(pvApiCtx, 2, &coll) || mg_get_string(pvApiCtx, 3, &fjson)) { Scierror(999, _("%s: expected (id, collection, filterJson).\n"), fname); return 0; }
    filter = bson_new_from_json((const uint8_t*)fjson, -1, &error);
    freeAllocatedSingleString(fjson);
    if (!filter) { freeAllocatedSingleString(coll); Scierror(999, _("%s: bad filter JSON: %s\n"), fname, error.message); return 0; }
    collection = mongoc_client_get_collection(client, g_mgdb[slot], coll);
    freeAllocatedSingleString(coll);
    cursor = mongoc_collection_find_with_opts(collection, filter, NULL, NULL);
    docs = (char**)malloc(sizeof(char*) * cap);
    while (mongoc_cursor_next(cursor, &doc)) {
        if (n >= cap) { cap *= 2; docs = (char**)realloc(docs, sizeof(char*) * cap); }
        docs[n++] = bson_as_relaxed_extended_json(doc, NULL);
    }
    if (mongoc_cursor_error(cursor, &error)) {
        for (i = 0; i < n; i++) bson_free(docs[i]); free(docs);
        mongoc_cursor_destroy(cursor); bson_destroy(filter); mongoc_collection_destroy(collection);
        Scierror(999, _("%s: query failed: %s\n"), fname, error.message); return 0;
    }
    createMatrixOfString(pvApiCtx, nbInputArgument(pvApiCtx) + 1, n, (n > 0) ? 1 : 0, docs);
    for (i = 0; i < n; i++) bson_free(docs[i]);
    free(docs);
    mongoc_cursor_destroy(cursor); bson_destroy(filter); mongoc_collection_destroy(collection);
    AssignOutputVariable(pvApiCtx, 1) = nbInputArgument(pvApiCtx) + 1;
    ReturnArguments(pvApiCtx);
    return 0;
}

static int mg_write(char* fname, void* pvApiCtx, int kind)
{
    /* kind: 0=insert(coll,docJson) 1=update(coll,filterJson,updJson) 2=delete(coll,filterJson) */
    int slot; char* coll = NULL; char* j1 = NULL; char* j2 = NULL;
    mongoc_client_t* client; mongoc_collection_t* collection;
    bson_t* b1 = NULL; bson_t* b2 = NULL; bson_t reply; bson_error_t error; bool ok; double cnt = 0.0;
    bson_iter_t it; const char* cntkey;
    client = mg_client(pvApiCtx, fname, &slot); if (!client) return 0;
    if (mg_get_string(pvApiCtx, 2, &coll)) { Scierror(999, _("%s: collection name expected.\n"), fname); return 0; }
    if (mg_get_string(pvApiCtx, 3, &j1)) { freeAllocatedSingleString(coll); Scierror(999, _("%s: JSON argument expected.\n"), fname); return 0; }
    if (kind == 1) { if (mg_get_string(pvApiCtx, 4, &j2)) { freeAllocatedSingleString(coll); freeAllocatedSingleString(j1); Scierror(999, _("%s: update JSON expected.\n"), fname); return 0; } }
    collection = mongoc_client_get_collection(client, g_mgdb[slot], coll);
    freeAllocatedSingleString(coll);
    b1 = bson_new_from_json((const uint8_t*)j1, -1, &error);
    freeAllocatedSingleString(j1);
    if (!b1) { if (j2) freeAllocatedSingleString(j2); mongoc_collection_destroy(collection); Scierror(999, _("%s: bad JSON: %s\n"), fname, error.message); return 0; }
    if (kind == 1) { b2 = bson_new_from_json((const uint8_t*)j2, -1, &error); freeAllocatedSingleString(j2);
        if (!b2) { bson_destroy(b1); mongoc_collection_destroy(collection); Scierror(999, _("%s: bad update JSON: %s\n"), fname, error.message); return 0; } }

    if (kind == 0) { ok = mongoc_collection_insert_one(collection, b1, NULL, &reply, &error); cnt = ok ? 1.0 : 0.0; cntkey = NULL; }
    else if (kind == 1) { ok = mongoc_collection_update_many(collection, b1, b2, NULL, &reply, &error); cntkey = "modifiedCount"; }
    else { ok = mongoc_collection_delete_many(collection, b1, NULL, &reply, &error); cntkey = "deletedCount"; }

    if (ok && cntkey && bson_iter_init_find(&it, &reply, cntkey)) cnt = (double)bson_iter_as_int64(&it);
    bson_destroy(&reply); bson_destroy(b1); if (b2) bson_destroy(b2);
    mongoc_collection_destroy(collection);
    if (!ok) { Scierror(999, _("%s: operation failed: %s\n"), fname, error.message); return 0; }

    createScalarDouble(pvApiCtx, nbInputArgument(pvApiCtx) + 1, cnt);
    AssignOutputVariable(pvApiCtx, 1) = nbInputArgument(pvApiCtx) + 1;
    ReturnArguments(pvApiCtx);
    return 0;
}

int sci_db_mongo_insert(char* fname, void* pvApiCtx) { CheckInputArgument(pvApiCtx, 3, 3); CheckOutputArgument(pvApiCtx, 1, 1); return mg_write(fname, pvApiCtx, 0); }
int sci_db_mongo_update(char* fname, void* pvApiCtx) { CheckInputArgument(pvApiCtx, 4, 4); CheckOutputArgument(pvApiCtx, 1, 1); return mg_write(fname, pvApiCtx, 1); }
int sci_db_mongo_delete(char* fname, void* pvApiCtx) { CheckInputArgument(pvApiCtx, 3, 3); CheckOutputArgument(pvApiCtx, 1, 1); return mg_write(fname, pvApiCtx, 2); }

int sci_db_mongo_collections(char* fname, void* pvApiCtx)
{
    int slot, n = 0; mongoc_client_t* client; mongoc_database_t* database;
    char** names; bson_error_t error;
    CheckInputArgument(pvApiCtx, 1, 1);
    CheckOutputArgument(pvApiCtx, 1, 1);
    client = mg_client(pvApiCtx, fname, &slot); if (!client) return 0;
    database = mongoc_client_get_database(client, g_mgdb[slot]);
    names = mongoc_database_get_collection_names_with_opts(database, NULL, &error);
    if (names == NULL) {
        mongoc_database_destroy(database);
        Scierror(999, _("%s: list collections failed: %s\n"), fname, error.message); return 0;
    }
    while (names[n] != NULL) n++;
    createMatrixOfString(pvApiCtx, nbInputArgument(pvApiCtx) + 1, n, (n > 0) ? 1 : 0, names);
    bson_strfreev(names);
    mongoc_database_destroy(database);
    AssignOutputVariable(pvApiCtx, 1) = nbInputArgument(pvApiCtx) + 1;
    ReturnArguments(pvApiCtx);
    return 0;
}

int sci_db_mongo_close(char* fname, void* pvApiCtx)
{
    int slot;
    CheckInputArgument(pvApiCtx, 1, 1);
    CheckOutputArgument(pvApiCtx, 0, 1);
    if (!mg_client(pvApiCtx, fname, &slot)) return 0;
    mongoc_client_destroy(g_mg[slot]); g_mg[slot] = NULL;
    if (g_mgdb[slot]) { free(g_mgdb[slot]); g_mgdb[slot] = NULL; }
    AssignOutputVariable(pvApiCtx, 1) = 0;
    ReturnArguments(pvApiCtx);
    return 0;
}
