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
loadCount = 0
map = {}

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
  ,loaded: ()->
    deps.depend()
    return loaded

Queries = new Mongo.Collection "queries"
Venues = new Mongo.Collection "venues"

Session.setDefault 'query_id', null

queriesHandle = Meteor.subscribe 'queries', () ->
  if !Session.get 'query_id'
    list = Queries.findOne {}, sort: name: 1
    if list
      Router.setQuery list._id

venuesHandle = null
Deps.autorun ()->
  query_id = Session.get 'query_id'
  if query_id
    venuesHandle = Meteor.subscribe 'venues', query_id
  else
    venuesHandle = null

Template.queries.loading = ()->
  return !queriesHandle.ready()


Template.queries.queries = ()->
  return Queries.find({});

Template.queries.selected = ()->
  return Session.equals 'query_id', (if @._id then 'selected' else '')


Template.queries.name_class = ()->
  return if @name then '' else 'empty'


Template.query.coolDate = ()->
  return new Date(@.date).toLocaleTimeString()

Template.query.events
  'click .remove': (e)->
    Venues.find(query_id: @._id, sort: name: 1).forEach (venue) ->
      Venues.remove venue._id
    Queries.remove @._id

    e.preventDefault();


Template.venues.loading = ()->
  return venuesHandle && !venuesHandle.ready()


Template.venues.any_query_selected = ()->
  return !Session.equals 'query_id', null


Template.venues.venues = ()->
  query_id = Session.get 'query_id'
  if !query_id
    return []

  sel = query_id: query_id;

  return Venues.find sel, sort: name: 1


QueriesRouter = Backbone.Router.extend
    routes:
      ":query_id": "main"
    main: (query_id) ->
      oldList = Session.get "query_id"
      if oldList != query_id
        Session.set "query_id", query_id
    setQuery: (query_id) ->
      @.navigate query_id, true



Router = new QueriesRouter

Meteor.startup ()->
  Backbone.history.start pushState: true

Mapbox.load 'markercluster'

Deps.autorun ()->
  if Mapbox.loaded()
    L.mapbox.accessToken = 'pk.eyJ1Ijoib25lcnVzc2VsbCIsImEiOiJBVDFSSXZvIn0.7TQDfcOgq402xMeLHs5kcw'
    map = L.mapbox.map 'mapbox', 'onerussell.jle9deni'
    geocoder = L.mapbox.geocoder 'mapbox.places-v1'
    geocoder.query 'Tokio Japan', (error, data)->
      if data.lbounds?
        map.setView data.latlng, 5
      else if data.latlng?
        map.setView [data.latlng[0], data.latlng[1]], 8
      query_id = Session.get 'query_id'
      if query_id?
        sel = query_id: query_id

        Venues.find(sel).forEach (venue) ->
          latlng = L.latLng venue.lat, venue.lng
          marker = L.marker latlng,
            icon: L.mapbox.marker.icon
              'marker-color': '#4183c4',
              'marker-symbol': 'bus',
              'marker-size': 'large'

          marker.bindPopup '<strong><a href="https://foursquare.com/v/' + venue.id + '">' + venue.name + '</a></strong>'
          marker.addTo map

Template.body.events
  'keyup #search': (e)->
      if e.keyCode == 13
        HTTP.get 'https://api.foursquare.com/v2/venues/search',
          params:
              client_id: 'QVFFGLAA2LCWS5254V5SJQMUQPJUYINMHJUG2WBNBR3ODJUJ',
              client_secret: '40313CVVGTFRD5H1XDSSXWHWRNQ42RTBRPGWT1WSF0PE2X5Q',
              v: '20130815',
              ll: map.getCenter().lat+','+ map.getCenter().lng,
              radius: map.getCenter().distanceTo(map.getBounds().getNorthWest()).toFixed(0),
              query: e.target.value

          ,(error, data)->
              id = Queries.insert
                name: e.target.value,
                radius: map.getCenter().distanceTo(map.getBounds().getNorthWest()).toFixed(0),
                date: new Date(),
                lat: map.getCenter().lat,
                lng: map.getCenter().lng
              for item in data.data.response.venues
                do (e)->
                  Venues.insert
                    query_id: id,
                    name: item.name,
                    lat: item.location.lat,
                    lng: item.location.lng,
                    city: item.location.city,
                    country: item.location.country,
                    address: item.location.address

              Router.setQuery id
              e.target.value = ""


