FILES =
    mapbox:
        js: ['https://api.tiles.mapbox.com/mapbox.js/v2.0.0/mapbox.js'],
        css: ['https://api.tiles.mapbox.com/mapbox.js/v2.0.0/mapbox.css'],
        count: 2
    ,
    markercluster:
        js: ['https://api.tiles.mapbox.com/mapbox.js/plugins/leaflet-markercluster/v0.4.0/leaflet.markercluster.js'],
        css: [
            'https://api.tiles.mapbox.com/mapbox.js/plugins/leaflet-markercluster/v0.4.0/MarkerCluster.css',
            'https://api.tiles.mapbox.com/mapbox.js/plugins/leaflet-markercluster/v0.4.0/MarkerCluster.Default.css'
        ],
        count: 3

deps = new Deps.Dependency
loaded = false
loadCount = 0;

loadedCallback = ()->
    loadCount--
    if loadCount == 0
        loaded = true
        deps.changed()

loadScript = (src)->
    elem = document.createElement 'script'
    elem.type = 'text/javascript'
    elem.src = src
    elem.defer = true

    elem.addEventListener 'load', loadedCallback, false
    head = document.getElementsByTagName('head')[0];
    head.appendChild elem

loadCss = (href)->
    elem = document.createElement 'link'
    elem.rel = 'stylesheet'
    elem.href = href
    elem.addEventListener 'load', loadedCallback, false

    head = document.getElementsByTagName('head')[0]
    head.appendChild elem

loadFiles = (plugins)->
    _.each FILES, (value, key)->
        _.each value.js, (js)->
            loadScript(js)
        _.each value.css, (css)->
            loadCss css


countFiles = (plugins)->
    count = 0
    _.each plugins, (plugin)->
        if FILES[plugin]
            count += FILES[plugin].count
        else
            console.log 'Invalid MapBox plugin: ' + plugin
    return count

Mapbox =
    load: ()->
        plugins = _.values arguments
        plugins.unshift 'mapbox'

        loadCount = countFiles plugins
        loadFiles plugins
    ,
    loaded: ()->
        deps.depend()
        return loaded
