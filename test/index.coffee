
mkt = require "../"
should = require "should"
db = require("redis").createClient()
sys = require "util"

mkt.version.should.match(/^\d+\.\d+\.\d+$/)


client = mkt.createClient()
client.client.flushdb ->

  tokensStore = [ ["a", "a_secret", 10], ["b", "b_secret", 20], ["k", "k_secret", 50]]

  client.fetchTokens "any-srv", 1, 365365, (err, data) ->
    err.msg.should.equal "not enough tokens"

    for t in tokensStore
      client.addToken "any-srv", t[0], t[1], t[2], {hour: 365365, splitBy: 20}

    client.fetchTokens "any-srv", 10, 365365, (err, data) ->
      should.equal null, err
      data.length.should.eql 1
      data[0].key.should.eql "a"
      data[0].secret.should.eql "a_secret"
      data[0].count.should.eql 10

      client.fetchTokens "any-srv", 200, 365365, (err, data) ->
        err.msg.should.equal "not enough tokens"

        client.fetchTokens "any-srv", 55, 365365, (err, data) ->
          should.equal null, err
          data.length.should.eql 3
          data[0].key.should.eql "b"
          data[0].secret.should.eql "b_secret"
          data[0].count.should.eql 20
          data[1].key.should.eql "k"
          data[1].secret.should.eql "k_secret"
          data[1].count.should.eql 20
          data[2].key.should.eql "k"
          data[2].secret.should.eql "k_secret"
          data[2].count.should.eql 15


          client.getStatByHour "any-srv", 365365, (err, data) ->
            should.equal null, err
            data.fetch_requests.should.eql 4
            data.total.should.eql 80
            data.used.should.eql 65
            data.overflow.should.eql 2
            data.returned.should.eql 0

            console.log "All test passes, no errors found."
            process.exit()
          # client.client.zrevrange "mkt:any-srv:365365", 0, 100, "withscores", (err, data) =>
          #   console.log "DB DATA = #{sys.inspect data}" #









