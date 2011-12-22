###
Market for crowd requests
###

redis            = require "redis"

exports.version  = "0.2.4"
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
  @param {Array} tokens Array of auto tokens.
                 Each tokens is a dictionary.
                  `token.id`     : unique id (by default `token.key` will be used)
                  `token.key`    : key string
                  `token.secret` : secret string
                  `token.count`  : quantity of tokens
  ###
  addAuto: (service, tokens) ->
    for t in tokens
      @client.hset "mkt:auto:#{service}", t.id || t.key, JSON.stringify t
    @client.setnx "mkt:auto:#{service}:lasthour", 1

  ###
  Get auto tokens. This method useful for stat and debug.

  @param {String} service Service name
  @param {Function} fn Callback function, accept 1) err, 2) object contains
                       `total` (Number) and `tokens` (Array) fields.
  ###
  getAllAutoTokens: (service, fn) ->
    @client.hgetall "mkt:auto:#{service}", (err, keys) =>
      unless err
        total  = 0
        tokens   = []
        for key, ks of keys
          k = JSON.parse ks
          if k.count > 0
            total += k.count
            tokens.push k
        fn null, total: total, tokens: tokens
      else
        fn err

  ###
  Replace one of auto tokens of add another one.

  @param {String} service Service name
  @param {Object} token New token dictionary.
                  `token.id`     : unique id (by default `token.key` will be used)
                  `token.key`    : key string
                  `token.secret` : secret string
                  `token.count`  : quantity of tokens

  ###
  replaceAutoToken: (service, token) ->
    @client.hset "mkt:auto:#{service}", token.id || token.key, JSON.stringify token

  ###
  Reset all auto tokens.

  @param {String} service Service name
  ###
  resetAuto:  (service) ->
    @client.del "mkt:auto:#{service}"
    @client.del "mkt:auto:#{service}:lasthour"

  ###
  Auto add tokens if needed. Called before fetching tokens and add auto tokens
  if `hour` do not have special tokens.
  ###
  _addAuto: (service, hour, fn) ->
    @client.get "mkt:auto:#{service}:lasthour", (err, lasthour) =>
      unless err
        if parseInt(lasthour) isnt parseInt(hour)
          @client.hgetall "mkt:auto:#{service}", (err, keys) =>
            unless err
              for key, ks of keys
                k = JSON.parse ks
                if k.count > 0
                  @addToken service, k.key, k.secret, k.count, hour: hour
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

    @client.hgetall "mkt:stat:#{service}:#{hour}", (err, dict) =>
      unless err
        @getAllAutoTokens service, (err, tokObj) =>
          unless err
            dict.total              = parseInt(dict.total || 0)
            dict.fetch_requests     = parseInt(dict.fetch_requests || 0)
            dict.used               = parseInt(dict.used || 0)
            dict.overflow           = parseInt(dict.overflow || 0)
            dict.returned           = parseInt(dict.returned || 0)
            dict.auto_tokens_total  = tokObj.total
            dict.auto_tokens_keys   = tokObj.tokens.length
            dict.hour               = hour
            fn null, dict
          else
            fn {msg: "error getting stat: auto-tokens"}
      else
        fn {msg: "error getting stat: hour"}


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
      fn    = hour
      hour  = null
    hour   ||= parseInt Date.now() /(60 * 60000)
    key      = "mkt:#{service}:#{hour}"
    statKey  = "mkt:stat:#{service}:#{hour}"
    @_addAuto service, hour, =>
      @client.hincrby statKey, "fetch_requests", 1
      @_popNext 0, requests, [], key, statKey, fn


exports.createClient = (client) -> new MarketClient




