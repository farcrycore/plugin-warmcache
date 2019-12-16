component {

    public query function getWarmableCaches() {
        var qCaches = queryNew("id,label,type,priority", "varchar,varchar,varchar,numeric")

        for (var typename in application.stCOAPI) {
            if (application.stCOAPI[typename].bObjectBroker) {
                queryAddRow(qCaches);
                querySetCell(qCaches, "id", typename);
                querySetCell(qCaches, "label", application.fapi.getContentTypeMetadata(typename, "displayName", typename) & " Objects");
                querySetCell(qCaches, "type", "contenttype");
                querySetCell(qCaches, "priority", "10");

                queryAddRow(qCaches);
                querySetCell(qCaches, "id", typename);
                querySetCell(qCaches, "label", application.fapi.getContentTypeMetadata(typename, "displayName", typename) & " Page Webskins");
                querySetCell(qCaches, "type", "pagewebskin");
                querySetCell(qCaches, "priority", "20");
            }
        }

        qCaches = queryExecute("SELECT * FROM qCaches ORDER BY priority, label", {  }, { dbType="query" });

        return qCaches;
    }


    public struct function performWarmCache(required string caches=application.fapi.getConfig("warmcache", "standardStrategy")) {
        var stPushed = {
            "stats" = {},
            "old_version" = application.fc.lib.objectbroker.getCacheVersion(),
            "start" = round(getTickCount() / 1000)
        };

        cfsetting(requesttimeout=50000);

        application.warmCacheProgress = {
            "start" = now(),
            "cacheTypes" = [],
            "cacheProgress" = {},
            "old_version" = stPushed.old_version
        };

        application.fc.lib.objectbroker.prepareCacheVersion();

        application.warmCacheProgress["new_version"] = application.fc.lib.objectbroker.getCacheVersion();

        application.warmCacheProgress.cacheTypes = listToArray(arguments.caches);
        for (var cachename in listToArray(arguments.caches)) {
            application.warmCacheProgress.cacheProgress[cacheName] = {
                "progress" = 0,
                "total" = 0
            };
            stPushed.stats[cachename] = application.fc.lib.warmcache.warmCache(listGetAt(cachename, 1, ":"), listGetAt(cachename, 2, ":"));
            application.warmCacheProgress.cacheProgress[cacheName].progress = stPushed.stats[cachename].pushed;
        }

        application.fc.lib.objectbroker.finalizeCacheVersion();

        stPushed["finish"] = round(getTickCount() / 1000);
        stPushed["new_version"] = application.fc.lib.objectbroker.getCacheVersion();
        stPushed["time"] = stPushed.finish - stPushed.start;
        stPushed["machine"] = application.sysInfo.machineName;
        application.fc.lib.cdn.ioWriteFile(location="privatefiles", file="/warmcache/#application.fapi.getConfig('warmcache', 'statsID')#/stats_#stPushed.finish#.json", data=serializeJSON(stPushed));

        structDelete(application, "warmCacheProgress");

        return stPushed;
    }

    public struct function warmCache(required string id, required string type) {
        var start = getTickCount();
        var stResult = {};

        switch (arguments.type) {
            case "contenttype":
                stResult["pushed"] = warmContentTypeCache(arguments.id);
                break;
            case "pagewebskin":
                stResult["pushed"] = warmPageWebskinCache(arguments.id);
                break;
            default:
                throw(message="Unknown cache type: #arguments.type#");
        }

        stResult["time"] = round((getTickCount() - start) / 1000);
        return stResult;
    }

    public numeric function warmContentTypeCache(required string typename) {
        var stData = getContentTypeFull(arguments.typename, "contenttype");
        var objectid = "";

        if (structKeyExists(application, "warmCacheProgress")) {
            application.warmCacheProgress.cacheProgress["#arguments.typename#:contenttype"].total = structCount(stData);
        }

        // push selected page of data to objectbroker
        for (objectid in stData) {
            application.fc.lib.objectbroker.AddToObjectBroker(stobj=stData[objectid],typename=arguments.typename);
            if (structKeyExists(application, "warmCacheProgress")) {
                application.warmCacheProgress.cacheProgress["#arguments.typename#:contenttype"].progress += 1;
            }
        }

        return structCount(stData);
    }

    public numeric function warmPageWebskinCache(required string typename) {
        var stData = getContentTypeSummary(
            typename=arguments.typename,
            cacheType="pagewebskin",
            includeFU=true,
            extraProps={ "displayMethod"="displayPageStandard" }
        );
        var objectid = "";
        var cacheVersion = application.fc.lib.objectbroker.getCacheVersion();
        var threads = "";
        var threadid = "";
        var maxSimultaneous = application.fapi.getConfig("warmcache", "threads");
        var overrideKey = "cacheversion_app";

        if (structKeyExists(application, "warmCacheProgress")) {
            application.warmCacheProgress.cacheProgress["#arguments.typename#:pagewebskin"].total = structCount(stData);
        }

        if (listFindNoCase(application.plugins, "memcached")) {
            overrideKey &= "_#application.fapi.getConfig('memcached', 'accessKey')#=#cacheVersion#";
        }
        else if (listFindNoCase(application.plugins, "redis")) {
            overrideKey &= "_#application.fapi.getConfig('redis', 'accessKey')#=#cacheVersion#";
        }
        else {
            throw(message="warmcache only works with the memcached and redis plugins");
        }

        // push selected page of data to objectbroker
        Each(stData, function(objectid){
            cfhttp(method="HEAD", url="http://localhost#stData[objectid].friendlyURL##find('?', stData[objectid].friendlyURL) ? '&' : '?'##overrideKey#", throwOnError=false) {}
            if (structKeyExists(application, "warmCacheProgress")) {
                application.warmCacheProgress.cacheProgress["#stData[objectid].typename#:pagewebskin"].progress += 1;
            }
        }, true, maxSimultaneous);

        return structCount(stData);
    }

    public struct function getContentTypeSummary(required string typename, required string cacheType, boolean includeFU=false, struct extraProps={}) {
        var oType = application.fapi.getContentType(arguments.typename);

        if (structKeyExists(oType, "getWarmableObjects")) {
            return oType.getWarmableObjects(argumentCollection=arguments);
        }

        var sql = "SELECT t.objectid";
        var prop = "";
        for (prop in arguments.extraProps) {
            sql &= structKeyExists(application.stCOAPI[arguments.typename].stProps, prop) ? ", t.#prop#" : ", '#arguments.extraProps[prop]#' as #prop#";
        }
        if (arguments.includeFU) {
            sql &= ", f.friendlyURL FROM #arguments.typename# t LEFT OUTER JOIN farFU f ON t.objectid=f.refobjectid AND f.fuStatus<>0 AND f.bDefault=1";
        }
        else {
            sql &= " FROM #arguments.typename# t";
        }
        if (structKeyExists(application.stCOAPI[arguments.typename].stProps, "status")) {
            sql &= " WHERE status='approved'"
        }

        var qData = queryExecute(sql, {}, { datasource=application.dsn_read });
        var stData = {};
        for (row in qData) {
            stData[row.objectid] = {
                "objectid" = row.objectid,
                "typename" = arguments.typename
            }

            if (arguments.includeFU) {
                if (len(row.friendlyURL)) {
                    stData[row.objectid]["friendlyURL"] = row.friendlyURL;
                }
                else {
                    stData[row.objectid]["friendlyURL"] = "/index.cfm?type=#arguments.typename#&objectid=#row.objectid#";
                }
            }


            for (prop in arguments.extraProps) {
                stData[row.objectid][prop] = row[prop];
            }
        }

        return stData;
    }

    public struct function getContentTypeFull(required string typename, required string cacheType) {
        var oType = application.fapi.getContentType(arguments.typename);
        if (structKeyExists(oType, "getWarmableObjects")) {
            return oType.getWarmableObjects(arguments.typename, "pagewebskin");
        }

        var stResult = {};
        var row = {};
        var column = "";
        var gateway = application.fc.lib.db.getGateway(application.dsn, "read");
        var schema = application.fc.lib.db.getTableMetadata(arguments.typename);
        var property = "";
        var arrayFields = "";

        var sql = "SELECT * FROM #arguments.typename#";
        if (structKeyExists(application.stCOAPI[arguments.typename].stProps, "status")) {
            sql &= " WHERE status='approved'"
        }
        var qObjectData = queryExecute(sql, {}, { datasource=application.dsn_read });

        for (property in schema.fields) {
            if (schema.fields[property].type eq "array") {
                arrayFields = listAppend(arrayFields, property);
            }
        }

        // base fields
        for (row in qObjectData) {
            stResult[row.objectid] = {
                "typename" = arguments.typename
            };

            for (property in qObjectData.columnlist) {
                if (structKeyExists(schema.fields, property)) {
                    stResult[row.objectid][property] = gateway.getValueFromDB(schema=schema.fields[property], value=row[property]);
                }
            }

            for (property in arrayFields) {
                stResult[row.objectid][property] = [];
            }
        }

        for (property in arrayFields) {
            if (listsort(structkeylist(schema.fields[property].fields),"textnocase") neq "data,parentid,seq,typename") {
                loadComplexArray(stResult, property, schema.fields[property]);
            }
            else {
                loadSimpleArray(stResult, property, schema.fields[property]);
            }
        }

        return stResult;
    }

    public struct function getStatHistory(numeric maxrows=3, numeric truncateTo=100) {
        var statsPath = '/warmcache/#application.fapi.getConfig('warmcache', 'statsID')#'
        var qFiles = application.fc.lib.cdn.ioGetDirectoryListing(location='privatefiles', dir='#statsPath#/');
        var row = {};
        var stResult = {
            "data" = queryNew("file,machine,start,finish,label,oldVersion,newVersion,total", "string,string,numeric,numeric,string,numeric,numeric,numeric"),
            "labels" = [],
            "caches" = []
        };
        var stData = {};
        var cacheType = "";
        var finishDate = "";
        var stCacheTypes = {};
        var label = "";

        for (i=1; i<=qFiles.recordcount - arguments.truncateTo; i++) {
            application.fc.lib.cdn.ioDeleteFile(location='privatefiles', file=statsPath & qFiles.file[i]);
        }

        for (row in qFiles) {
            stData = deserializeJSON(application.fc.lib.cdn.ioReadFile(location='privatefiles', file=statsPath & row.file));
            finishDate = DateAdd("s", stData.finish, DateConvert("utc2Local", "January 1 1970 00:00"));
            label = dateFormat(finishDate, 'd mmm yyyy') & " " & timeFormat(finishDate, "HH:mm") & " (" & stData.old_version & ">" & stData.new_version & ")";
            stCacheTypes[label] = [];

            queryAddRow(stResult.data);
            querySetCell(stResult.data, "file", statsPath & row.file);
            querySetCell(stResult.data, "machine", stData.machine);
            querySetCell(stResult.data, "start", stData.start);
            querySetCell(stResult.data, "finish", stData.finish);
            querySetCell(stResult.data, "label", label);
            querySetCell(stResult.data, "oldVersion", stData.old_version);
            querySetCell(stResult.data, "newVersion", stData.new_version);
            querySetCell(stResult.data, "total", stData.time);

            for (cacheType in stData.stats) {
                if (not listFindNoCase(stResult.data.columnlist, replace(cacheType, ":", "_") & "_count")) {
                    queryAddColumn(stResult.data, replace(cacheType, ":", "_") & "_count", []);
                    queryAddColumn(stResult.data, replace(cacheType, ":", "_") & "_time", []);
                    arrayAppend(stResult.caches, cacheType);
                }

                arrayAppend(stCacheTypes[label], cacheType);

                querySetCell(stResult.data, replace(cacheType, ":", "_") & "_count", stData.stats[cacheType].pushed);
                querySetCell(stResult.data, replace(cacheType, ":", "_") & "_time", stData.stats[cacheType].time);
            }
        }

        stResult.data = queryExecute("SELECT * FROM stResult.data ORDER BY finish desc", {  }, { dbType="query", maxrows=arguments.maxrows })
        stResult.data = queryExecute("SELECT * FROM stResult.data ORDER BY finish asc", {  }, { dbType="query" })

        for (row in stResult.data) {
            arrayAppend(stResult.labels, row.label);
            for (cacheType in stCacheTypes[row.label]) {
                if (not arrayFind(stResult.caches, cacheType)) {
                    arrayAppend(stResult.caches, cacheType);
                }
            }
        }
        arraySort(stResult.caches, "textnocase");

        return stResult;
    }

    public struct function getGoogleChartData(numeric maxrows=3) {
        var stStats = getStatHistory(maxrows=arguments.maxrows);
        var stResult = {
            "time" = [["Cache"]],
            "pushed" = [["Cache"]],
            "avgtimeper" = [["Cache"]]
        };
        var row = {};
        var cacheType = "";
        var i = 0;

        arrayAppend(stResult.time[1], stStats.labels, true);
        arrayAppend(stResult.pushed[1], stStats.labels, true);
        arrayAppend(stResult.avgtimeper[1], stStats.labels, true);
        for (cacheType in stStats.caches) {
            arrayAppend(stResult.time, [replace(cacheType, ":", " (") & ")"]);
            arrayAppend(stResult.pushed, [replace(cacheType, ":", " (") & ")"]);
            arrayAppend(stResult.avgtimeper, [replace(cacheType, ":", " (") & ")"]);
        }

        for (row in stStats.data) {
            for (i=1; i<=arrayLen(stStats.caches); i++) {
                if (len(row[replace(stStats.caches[i], ':', '_') & "_time"])) {
                    arrayAppend(stResult.time[i+1], row[replace(stStats.caches[i], ':', '_') & "_time"]);
                    arrayAppend(stResult.pushed[i+1], row[replace(stStats.caches[i], ':', '_') & "_count"]);
                    if (row[replace(stStats.caches[i], ':', '_') & "_count"]) {
                        arrayAppend(stResult.avgtimeper[i+1], row[replace(stStats.caches[i], ':', '_') & "_time"] / row[replace(stStats.caches[i], ':', '_') & "_count"]);
                    }
                    else {
                        arrayAppend(stResult.avgtimeper[i+1], 0);
                    }
                }
                else {
                    arrayAppend(stResult.time[i+1], 0);
                    arrayAppend(stResult.pushed[i+1], 0);
                    arrayAppend(stResult.avgtimeper[i+1], 0);
                }
            }
        }

        return stResult;
    }

    public void function loadSimpleArray(required struct stObjects, required string arrayName, required struct schema) {
        var row = {};
        var gateway = application.fc.lib.db.getGateway(application.dsn, "read");
        var qArrayData = queryExecute("
            select 		parentid, data 
            from 		#application.dbowner##arguments.schema.tablename#
            order by 	parentid, seq
        ", {}, { datasource=application.dsn_read });
        
        for (row in qArrayData) {
            if (structKeyExists(arguments.stObjects, row.parentid)) {
                arrayappend(arguments.stObjects[row.parentid][arguments.arrayName], gateway.getValueFromDB(schema=arguments.schema.fields["data"], value=row.data));
            }
        }
    }

    public void function loadComplexArray(required struct stObjects, required string arrayName, required struct schema) {
        var row = {};
        var thisext = {};
        var thiscol = {};
        var gateway = application.fc.lib.db.getGateway(application.dsn, "read");
        var qArrayData = queryExecute("
            select 		#structkeylist(arguments.schema.fields)# 
            from 		#application.dbowner##arguments.schema.tablename#
            order by 	parentid, seq
        ", {}, { datasource=application.dsn_read });
        
        for (row in qArrayData) {
            thisext = {};
            for (thiscol in qArrayData.columnlist) {
                thisext[thiscol] = gateway.getValueFromDB(schema=arguments.schema.fields[thiscol], value=row[thiscol]);
            }
            arrayAppend(arguments.stObjects[row.parentid][arguments.arrayName], thisext);
        }
    }

}