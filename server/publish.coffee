Queries = new Mongo.Collection "queries"

Meteor.publish 'queries', ()->
  return Queries.find()

Venues = new Mongo.Collection "venues"

Meteor.publish 'venues', (query_id)->
  check query_id, String
  return Venues.find query_id: query_id