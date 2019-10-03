<cfsetting enablecfoutputonly="true">

<cfimport taglib="/farcry/core/tags/formtools" prefix="ft" />


<cfset stPushed = {} />
<ft:processForm action="Run">
    <cfloop list="#form.cachename#" index="cache">
        <cfset id = listGetAt(cache, 1, ":") />
        <cfset type = listGetAt(cache, 2, ":") />
        <cfset stPushed[id] = application.fc.lib.warmcache.warmCache(id, type) />
    </cfloop>
</ft:processForm>


<cfset qCaches = application.fc.lib.warmcache.getWarmableCaches() />

<ft:form>
    <cfoutput>
        <h1>Warm Caches</h1>

        <table id="caches" class="table table-striped">
            <thead>
                <tr>
                    <th><input type="checkbox" name="all"></th>
                    <th>Cache</th>
                    <cfif not structIsEmpty(stPushed)>
                        <th>## Pushed</th>
                    </cfif>
                </tr>
            </thead>
            <tbody>
    </cfoutput>

    <cfoutput query="qCaches">
        <tr>
            <td><input type="checkbox" name="cachename" value="#qCaches.id#:#qCaches.type#"></td>
            <td>
                #qCaches.label#<br>
                <code>application.fc.lib.warmcache.warmCache("#qCaches.id#", "#qCaches.type#")</code>
            </td>
            <cfif not structIsEmpty(stPushed)>
                <cfif structKeyExists(stPushed, qCaches.id)>
                    <td>#stPushed[qCaches.id]#</td>
                <cfelse>
                    <td></th>
                </cfif>
            </cfif>
        </tr>
    </cfoutput>

    <cfoutput>
            </tbody>
        </table>
    </cfoutput>

    <ft:buttonPanel>
        <ft:button value="Run" />
    </ft:buttonPanel>

    <cfoutput>
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