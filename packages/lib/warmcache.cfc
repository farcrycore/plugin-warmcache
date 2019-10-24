component {

    public query function getWarmableCaches() {
        var qCaches = queryNew("id,label,type")

        for (var typename in application.stCOAPI) {
            if (application.stCOAPI[typename].bObjectBroker) {
                queryAddRow(qCaches);
                querySetCell(qCaches, "id", typename);
                querySetCell(qCaches, "label", application.fapi.getContentTypeMetadata(typename, "displayName", typename));
                querySetCell(qCaches, "type", "contenttype");
            }
        }

        qCaches = queryExecute("SELECT * FROM qCaches ORDER BY label", {  }, { dbType="query" });

        return qCaches;
    }


    public numeric function warmCache(required string id, required string type) {
        switch (arguments.type) {
            case "contenttype": return warmContentTypeCache(arguments.id);
        }

        throw(message="Unknown cache type: #arguments.type#");
    }

    public numeric function warmContentTypeCache(required string typename) {
        var stData = getContentTypeFull(arguments.typename);
        var objectid = "";

        cfsetting(requesttimeout=600);

        // push selected page of data to objectbroker
        for (objectid in stData) {
            application.fc.lib.objectbroker.AddToObjectBroker(stobj=stData[objectid],typename=arguments.typename);
        }

        return structCount(stData);
    }

    public struct function getContentTypeFull(required string typename) {
        var qObjectData = queryExecute("SELECT * FROM #arguments.typename#", {}, { datasource=application.dsn_read })
        var stResult = {};
        var row = {};
        var column = "";
        var gateway = application.fc.lib.db.getGateway(application.dsn, "read");
        var schema = application.fc.lib.db.getTableMetadata(arguments.typename);
        var property = "";
        var arrayFields = "";

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