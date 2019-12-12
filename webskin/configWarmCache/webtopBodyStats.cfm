<cfsetting enablecfoutputonly="true">
<!--- @viewstack: page --->

<cfimport taglib="/farcry/core/tags/webskin" prefix="skin" />

<skin:loadCSS id="fc-bootstrap" />

<cfset request.bHideContextMenu = true />

<cfset stStats = application.fc.lib.warmcache.getGoogleChartData()>

<cfoutput>
    <!doctype html>
    <html>
        <head>
            <cfif arrayLen(stStats.pushed) gt 1>
                <script type="text/javascript" src="https://www.gstatic.com/charts/loader.js"></script>
                <script>
                    google.charts.load('current', {'packages':['corechart', 'bar']});

                    google.charts.setOnLoadCallback(drawPushedChart);
                    google.charts.setOnLoadCallback(drawAvgTimeTakenChart);
                    google.charts.setOnLoadCallback(drawTotalTimeTakenChart);

                    function drawPushedChart() {
                        // Create the data table.
                        var data = google.visualization.arrayToDataTable(#serializeJSON(stStats.pushed)#);

                        // Set chart options
                        var options = {
                            title:'Items pushed to cache',
                            hAxis: { title: 'Items',  titleTextStyle: {color: '##333'}, slantedText: true },
                            vAxis: { title: 'Cache type' },
                            bars: 'horizontal',
                            width: 750,
                            height: 400
                        };

                        // Instantiate and draw our chart, passing in some options.
                        var chart = new google.charts.Bar(document.getElementById('pushedchart'));
                        chart.draw(data, google.charts.Bar.convertOptions(options));
                    }

                    function drawAvgTimeTakenChart() {
                        // Create the data table.
                        var data = google.visualization.arrayToDataTable(#serializeJSON(stStats.avgtimeper)#);

                        // Set chart options
                        var options = {
                            title:'Average Time taken to push',
                            hAxis: {title: 'Avg sec/item',  titleTextStyle: {color: '##333'}},
                            vAxis: {title: 'Cache type'},
                            bars: 'horizontal',
                            width: 750,
                            height: 400
                        };

                        // Instantiate and draw our chart, passing in some options.
                        var chart = new google.charts.Bar(document.getElementById('avgtimetakenchart'));
                        chart.draw(data, google.charts.Bar.convertOptions(options));
                    }

                    function drawTotalTimeTakenChart() {
                        // Create the data table.
                        var data = google.visualization.arrayToDataTable(#serializeJSON(stStats.time)#);

                        // Set chart options
                        var options = {
                            title:'Total time taken to push',
                            hAxis: {title: 'Seconds',  titleTextStyle: {color: '##333'}},
                            vAxis: {title: 'Cache type'},
                            bars: 'horizontal',
                            width: 750,
                            height: 400
                        };

                        // Instantiate and draw our chart, passing in some options.
                        var chart = new google.charts.Bar(document.getElementById('totaltimetakenchart'));
                        chart.draw(data, google.charts.Bar.convertOptions(options));
                    }

                    <cfif structKeyExists(application, "warmCacheProgress")>
                        setTimeout(function() { window.location.reload(); }, 5000);
                    </cfif>
                </script>
            </cfif>
        </head>
        <body>
            <cfif structKeyExists(application, "warmCacheProgress")>
                <p>
                    Warming in progress (started at #timeFormat(application.warmCacheProgress.start, 'h:mmtt')#, #dateFormat(application.warmCacheProgress.start, 'd mmm yyyy')#)<br>
                    Current cache version: <strong>#application.warmCacheProgress.old_version#</strong>, preparing: <strong>#application.warmCacheProgress.new_version#</strong><br>
                    <ul>
                        <cfloop array="#application.warmCacheProgress.cacheTypes#" index="cacheType">
                            <cfif structKeyExists(application.warmCacheProgress.cacheProgress, cacheType) and application.warmCacheProgress.cacheProgress[cacheType].progress eq application.warmCacheProgress.cacheProgress[cacheType].total>
                                <li>#cacheType# (<strong>DONE</strong>)</li>
                            <cfelseif structKeyExists(application.warmCacheProgress.cacheProgress, cacheType)>
                                <li>#cacheType# (#application.warmCacheProgress.cacheProgress[cacheType].progress# / #application.warmCacheProgress.cacheProgress[cacheType].total#)</li>
                            <cfelse>
                                <li>#cacheType#</li>
                            </cfif>
                        </cfloop>
                    </ul>
                </p>
            <cfelse>
                <p>Current cache version: <strong>#application.fc.lib.objectbroker.getCacheVersion()#</strong></p>
            </cfif>
            <br>
            <div id="pushedchart"></div>
            <div id="totaltimetakenchart"></div>
            <div id="avgtimetakenchart"></div>
        </body>
    </html>
</cfoutput>

<cfsetting enablecfoutputonly="false">