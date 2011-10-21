
# Market req

  Market req purposed for store oauth tokens for making more request to oauth services
to overcome rpm/rph limit by using more than one token. Store tokens and usage stat in redis.


## Installation

      $ npm install market-req

## Example (coffee-script)

```coffee-script
   client = require("market-req").createClient()
   # add 10 request tokens for current hour
   client.addToken "srv", "token_key", "token_secret", 10
   ...
   # fetch 3 tokens
   client.fetchTokens "srv", 3, (err, tokens) ->
     if !err
       # utilize tokens array
       token = tokens[0].tok
       token_secret = tokens[0].tok_secret
```

## License 

(The MIT License)

Copyright (c) 2011 Temnov Kirill &lt;allselead@gmail.com&gt;

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
