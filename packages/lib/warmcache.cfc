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
        var page = 1;
        var pageSize = 1000;
        var qData = getContentTypePage(arguments.typename, page, pageSize);
        var pushed = 0;
        var row = {};
        var stObject = {};
        var oType = application.fapi.getContentType(arguments.typename);

        while (true) {
            // push selected page of data to objectbroker
            for (row in qData) {
                stObject = oType.getData(objectid=qData.objectid, bUseInstanceCache=false);
                application.fc.lib.objectbroker.AddToObjectBroker(stobj=stObject,typename=arguments.typename);
            }

            pushed += qData.recordcount;

            if (qData.recordcount lt pageSize) {
                return pushed;
            }

            page += 1;
            qData = getContentTypePage(arguments.typename, page, pageSize);
            if (qData.recordcount eq 0) {
                return pushed;
            }
        }
    }

    public query function getContentTypePage(required string typename, numeric page=1, numeric pageSize=1000) {
        switch (application.dbtype) {
            case "h2": case "mysql":
                return queryExecute("
                    SELECT      objectid, '#arguments.typename#' as typename
                    FROM        #typename#
                    ORDER BY    datetimeCreated DESC
                    LIMIT       #(arguments.page - 1) * arguments.pageSize#, #arguments.pageSize#
                ", {}, { datasource=application.dsn_read });
            case "mssql2012":
                return queryExecute("
                    SELECT      objectid, '#arguments.typename#' as typename
                    FROM        #typename#
                    ORDER BY    datetimeCreated DESC
                    OFFSET      #(arguments.page - 1) * arguments.pageSize#
                    FETCH NEXT  #arguments.pageSize# ROWS ONLY
                ", {}, { datasource=application.dsn_read });
            case "mssql": case "mssql2005":
                throw(message="No getContentTypePage query for database type: #application.dbtype#");
        }
    }

}