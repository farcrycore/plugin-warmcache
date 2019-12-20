<cfsetting enablecfoutputonly="true">

<cfimport taglib="/farcry/core/tags/formtools" prefix="ft" />
<cfimport taglib="/farcry/core/tags/webskin" prefix="skin" />

<ft:processForm action="Run Standard Strategy" url="refresh">
    <cfthread name="runwarming">
        <cfset application.fc.lib.warmcache.performWarmCache(application.fapi.getConfig("warmcache", "standardStrategy")) />
    </cfthread>
</ft:processForm>

<ft:processForm action="Run" url="refresh">
    <cfthread name="runwarming">
        <cfset application.fc.lib.warmcache.performWarmCache(form.cachename) />
    </cfthread>
</ft:processForm>

<ft:processForm action="Save as Standard Strategy">
	<cfset stConfigData = application.fapi.getContentType("farConfig").getConfig("warmcache") />
	<cfset stConfigData.standardStrategy = form.cachename />
	<cfset qConfig = application.fapi.getContentObjects(typename="farConfig",configkey_eq="warmcache") />
	<cfset stConfig = application.fapi.getContentObject(typename="farConfig",objectid=qConfig.objectid) />
	<cfset stConfig.configdata = serializeJSON(stConfigData)>
	<cfset stConfig.datetimelastupdated = now()>
	<cfset application.fapi.setData(stProperties=stConfig) />
</ft:processForm>

<cfset qCaches = application.fc.lib.warmcache.getWarmableCaches() />
<cfset standardStrategy = application.fapi.getConfig("warmcache", "standardStrategy") />

<ft:form>
    <cfoutput>
        <h1>Warm Caches</h1>
        <p>NOTE: the order that options are listed here represents the order the warming will be performed in.</p>
        <div class="row-fluid">
            <div class="span6">
                <iframe src="/index.cfm?type=configWarmCache&view=webtopBodyStats" style="border:0; width:100%; height:1300px;">Loading</iframe>
            </div>
            <div class="span6">
                <ft:buttonPanel>
                    <cfif len(application.fapi.getConfig("warmcache", "standardStrategy")) and application.security.checkPermission('developer')>
                        <ft:button value="Run Standard Strategy" />
                    </cfif>
                </ft:buttonPanel>

                <table id="caches" class="table table-striped">
                    <thead>
                        <tr>
                            <th><input type="checkbox" name="all"></th>
                            <th>Cache</th>
                        </tr>
                    </thead>
                    <tbody>
    </cfoutput>

    <cfoutput query="qCaches">
        <tr>
            <td><input type="checkbox" name="cachename" value="#qCaches.id#:#qCaches.type#"></td>
            <td>
                <cfif listFindNoCase(standardStrategy, "#qCaches.id#:#qCaches.type#")>
                    <strong>#qCaches.label# (in standard strategy)</strong>
                <cfelse>
                    #qCaches.label#
                </cfif>
                <br>
                <code>application.fc.lib.warmcache.warmCache("#qCaches.id#", "#qCaches.type#")</code>
            </td>
        </tr>
    </cfoutput>

    <cfoutput>
                </tbody>
            </table>
    </cfoutput>

    <ft:buttonPanel>
        <cfif application.security.checkPermission('developer')>
            <ft:button value="Run" />
        </cfif>
        <ft:button value="Save as Standard Strategy" />
    </ft:buttonPanel>

    <cfoutput>
        </div>
        <script>
            $j("##caches")
                .find("tbody tr").on("click", function(event) {
                    var target = $j(event.target);

                    if (target.is("input")) {
                        event.stopPropagation();
                        return;
                    }

                    var cb = $j(this).closest("tr").find("input");
                    cb.prop("checked", !cb.prop("checked"));
                }).end()
                .find("thead input").on("click", function(event) {
                    var checked = $j(this).prop("checked");

                    $j(this).closest("table").find("tbody input").prop("checked", checked);
                });
        </script>
    </cfoutput>
</ft:form>

<cfsetting enablecfoutputonly="false">