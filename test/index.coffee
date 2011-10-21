
mkt = require "../"
should = require "should"
db = require("redis").createClient()
sys = require "sys"

mkt.version.should.match(/^\d+\.\d+\.\d+$/)


client = mkt.createClient()
client.client.flushdb ->

  tokensStore = [ ["a", "a_secret", 10], ["b", "b_secret", 20], ["k", "k_secret", 50]]

  client.fetchTokens "any-srv", 1, 365365, (err, data) ->
    err.msg.should.equal "not enough tokens"

    for t in tokensStore
      client.addToken "any-srv", t[0], t[1], t[2], 365365

    #
    # client.client.llen "mkt:any-srv:365365", (err, result) ->
    #   console.log "len = #{result}"

    client.fetchTokens "any-srv", 10, 365365, (err, data) ->
      should.equal null, err
      data.length.should.eql 1
      data[0].tok.should.eql "a"
      data[0].tok_secret.should.eql "a_secret"
      data[0].count.should.eql 10

      client.fetchTokens "any-srv", 200, 365365, (err, data) ->
        err.msg.should.equal "not enough tokens"

        client.fetchTokens "any-srv", 55, 365365, (err, data) ->
          should.equal null, err


          data.length.should.eql 2
          data[0].tok.should.eql "b"
          data[0].tok_secret.should.eql "b_secret"
          data[0].count.should.eql 20
          data[1].tok.should.eql "k"
          data[1].tok_secret.should.eql "k_secret"
          data[1].count.should.eql 35


          client.getStatByHour "any-srv", 365365, (err, data) ->
            should.equal null, err
            data.fetch_requests.should.eql 4
            data.total.should.eql 80
            data.used.should.eql 65
            data.overflow.should.eql 2

            console.log "All test passes, no errors found."
            process.exit()
          # client.client.zrevrange "mkt:any-srv:365365", 0, 100, "withscores", (err, data) =>
          #   console.log "DB DATA = #{sys.inspect data}" #









