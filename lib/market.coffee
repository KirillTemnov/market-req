###
Market for crowd requests
###

redis = require "redis"

exports.version = "0.1.3"
sys = require "sys"


###
Class for connect to market and manage tokens
###
class MarketClient
  constructor: (client) ->
    @client = client || redis.createClient()

  ###
  Add new token pair, hour is optional, default - current hour
  ###
  addToken:  (service, token, token_secret, requests, hour=null) ->
    # todo split tokens requests to small chunks
    hour ||= parseInt Date.now() /(60 * 60000)
    @client.hincrby "mkt:stat:#{service}:#{hour}", "total", requests
    @client.rpush "mkt:#{service}:#{hour}", JSON.stringify {tok: token, tok_secret: token_secret, count: requests}

  ###
  Get statistics by service and hour

  fn callback assept error as first parameter and stat object as second
  stat object contain fields:
      total                    total token pairs x requests added
      used                     tokens fetched from market
      overflow                 number of overflow requests to market
      fetch_requests           number of fetching requests
  ###
  getStatByHour: (service, hour, fn) ->
    hour ||= parseInt Date.now() /(60 * 60000)
    @client.hgetall "mkt:stat:#{service}:#{hour}", (err, dict) ->
      if !err
        dict.total ||= 0
        dict.fetch_requests ||= 0
        dict.used ||= 0
        dict.overflow ||= 0
        fn null, dict
      else
        fn {msg: "error getting stat"}

  _popNext: (found, requests, result, key, statKey, fn) ->
    @client.lpop key, (err, value) =>
      if err
        return fn {msg: "error getting value"}
      else if !value            # reach end of list
        @client.hincrby statKey, "overflow", 1
        result.map (e) => @client.rpush key, JSON.stringify e
        return fn {msg: "not enough tokens"}
      else
        value = JSON.parse value
        if found + value.count <= requests
          found += value.count
          result.push value
        else
          newCount = requests - found
          rest = value.count - newCount
          value.count = newCount
          result.push value
          found = requests
          @client.rpush key, JSON.stringify {count: rest, tok: value.tok, tok_secret: value.tok_secret}

      if requests == found
        @client.hincrby statKey, "used", requests
        fn null, result
      else
        @_popNext found, requests, result, key, statKey, fn

  ###
  Utilize tokens from redis
  ###
  fetchTokens: (service, requests, hour, fn) ->
    if "function" == typeof hour
      fn = hour
      hour = null
    hour ||= parseInt Date.now() /(60 * 60000)
    key = "mkt:#{service}:#{hour}"
    statKey = "mkt:stat:#{service}:#{hour}"
    @client.hincrby statKey, "fetch_requests", 1

    @_popNext 0, requests, [], key, statKey, fn


exports.createClient = (client) -> new MarketClient




