###
Market for crowd requests
###

redis            = require "redis"

exports.version  = "0.2.0"
sys              = require "util"


###
Class for connect to market and manage tokens
###
class MarketClient

  constructor: (client) ->
    @client = client || redis.createClient()


  ###
  Add auto tokens.

  @param {String} service Service name
  @param {Array} tokens Array of tokens. Each token is array from token, secret and
                        count (in that order).
  ###
  addAuto: (service, tokens) ->
    for t in tokens
      @client.rpush "mkt:auto:#{service}", JSON.stringify t
    @client.setnx "mkt:auto:#{service}:lasthour", 1

  ###
  Reset all auto tokens
  ###
  resetAuto:  (service) ->
    @client.del "mkt:auto:#{service}"
    @client.del "mkt:auto:#{service}:lasthour"

  ###
  Auto add tokens if needed
  ###
  _addAuto: (service, hour, fn) ->
    @client.get "mkt:auto:#{service}:lasthour", (err, lasthour) =>
      unless err
        if lasthour isnt null and lasthour isnt "#{hour}"
          @client.lrange "mkt:auto:#{service}", 0, -1, (err, tokens) =>
            for t in tokens
              tok = JSON.parse t
              @addToken service, tok[0], tok[1], tok[2], hour: hour
            @client.set "mkt:auto:#{service}:lasthour", hour
            fn()
        else
          fn()
      else
        fn()

  ###
  Add new token pair, hour is optional, default - current hour
  ###
  addToken:  (service, token, token_secret, requests, opts={}) ->
    splitBy = opts.splitBy || 10
    hour = opts.hour || parseInt Date.now() /(60 * 60000)
    @client.hincrby "mkt:stat:#{service}:#{hour}", "total", requests
    while requests > 0
      if requests > splitBy
        requests -= splitBy
        @client.rpush "mkt:#{service}:#{hour}", JSON.stringify {tok: token, tok_secret: token_secret, count: splitBy}
      else
        @client.rpush "mkt:#{service}:#{hour}", JSON.stringify {tok: token, tok_secret: token_secret, count: requests}
        requests = 0

  ###
  Return unused tokens to market, unlike `addToken`, this method *decrement* =used= counter and
  increase =returned= counter, but not affect to =total= counter.
  ###
  returnToken: (service, token, token_secret, requests, opts={}) ->
    if requests > 0
      hour = opts.hour || parseInt Date.now() /(60 * 60000)
      statKey = "mkt:stat:#{service}:#{hour}"
      @client.hincrby statKey, "used", -requests
      @client.hincrby statKey, "returned", requests
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
    if "function" is typeof hour
      fn = hour
      hour = parseInt Date.now() /(60 * 60000)

    @client.lrange "mkt:auto:#{service}", 0, -1, (err, tokens) =>
      unless err
        @client.hgetall "mkt:stat:#{service}:#{hour}", (err, dict) ->
          unless err
            auto_tokens_total       = 0
            tokens.map (tok) ->
              t = JSON.parse tok
              auto_tokens_total += t[2]
            dict.total              = parseInt(dict.total || 0)
            dict.fetch_requests     = parseInt(dict.fetch_requests || 0)
            dict.used               = parseInt(dict.used || 0)
            dict.overflow           = parseInt(dict.overflow || 0)
            dict.returned           = parseInt(dict.returned || 0)
            dict.auto_tokens_total  = auto_tokens_total
            dict.auto_tokens_keys   = tokens.length
            fn null, dict
          else
            fn {msg: "error getting stat"}
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
    @_addAuto service, hour, =>
      @client.hincrby statKey, "fetch_requests", 1
      @_popNext 0, requests, [], key, statKey, fn


exports.createClient = (client) -> new MarketClient




