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

        cfsetting(requesttimeout=600);

        // push selected page of data to objectbroker
        for (row in qData) {
            stObject = oType.getData(objectid=qData.objectid, bUseInstanceCache=false);
            application.fc.lib.objectbroker.AddToObjectBroker(stobj=stObject,typename=arguments.typename);
        }

        pushed += qData.recordcount;

        return pushed;
    }

    public query function getContentTypePage(required string typename) {

        return queryExecute("
            SELECT      objectid, '#arguments.typename#' as typename
            FROM        #typename#
            ORDER BY    datetimeCreated DESC
        ", {}, { datasource=application.dsn_read });
    }

}