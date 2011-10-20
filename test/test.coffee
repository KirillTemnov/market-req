
mkt = require "../"
should = require "should"
db = require("redis").createClient()
sys = require "sys"

mkt.version.should.match(/^\d+\.\d+\.\d+$/)

client = mkt.createClient()
client.client.flushdb ->

  tokensStore = [ ["a", "a_secret", 10], ["b", "b_secret", 20], ["k", "k_secret", 50]]

  client.fetchTokens "any-srv", 1, 365365, (err, data) ->
    err.msg.should.equal "tokens not found"

    for t in tokensStore
      client.addToken "any-srv", t[0], t[1], t[2], 365365

    client.fetchTokens "any-srv", 10, 365365, (err, data) ->
      should.equal null, err
      data.length.should.eql 1
      data[0].length.should.eql 2
      data[0][0].should.eql ["k", "k_secret"]
      data[0][1].should.eql 10

      client.fetchTokens "any-srv", 200, 365365, (err, data) ->
        err.msg.should.equal "not enough tokens"

        client.fetchTokens "any-srv", 55, 365365, (err, data) ->
          should.equal null, err
          data.length.should.eql 2
          data[0].length.should.eql 2
          data[1].length.should.eql 2
          data[0][0].should.eql ["k", "k_secret"]
          data[0][1].should.eql 40
          data[1][0].should.eql ["b", "b_secret"]
          data[1][1].should.eql 15

          client.getStatByHour "any-srv", 365365, (err, data) ->
            should.equal null, err
            data.fetch_requests.should.eql 4
            data.tokens_over.should.eql 1
            data.total.should.eql 80
            data.used.should.eql 65
            data.overflow.should.eql 1

            console.log "All test passes, no errors found."
            process.exit()
          # client.client.zrevrange "mkt:any-srv:365365", 0, 100, "withscores", (err, data) =>
          #   console.log "DB DATA = #{sys.inspect data}" #









